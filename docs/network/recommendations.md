# Network Improvement Recommendations

## Executive Summary

Based on comprehensive analysis of the network infrastructure, this document provides prioritized recommendations for improving reliability, security, performance, and manageability.

## 🔴 Critical Priority

### 1. Fix MikroTik Interface Classification

**Current Issue**: ether1 (172.16.0.2) is classified as WAN, causing firewall complexity

**Problem**:
```bash
# ether1 facing UDM-Pro is in WAN list
# This treats main network traffic as "external"
# Requires workaround rules like #31
```

**Recommendation**: Reclassify ether1 as LAN
```bash
# Remove from WAN list
/interface list member remove [find interface=ether1 and list=WAN]

# Add to LAN list
/interface list member add interface=ether1 list=LAN
```

**Benefits**:
- Simplifies firewall rules (remove workaround rule #31)
- More logical security model
- Reduces rule complexity
- Easier troubleshooting

**Impact**: Low (firewall rules need review after change)

### 2. Implement Network Redundancy

**Current Risk**: Single points of failure
- Single UDM-Pro (edge router failure = complete outage)
- Single MikroTik (core router failure = VMware infrastructure down)
- Single ISP connection

**Recommendation A: Add Secondary WAN**
```bash
# Options:
1. Secondary ISP (different provider)
2. LTE/5G failover (Cellular backup)
3. Starlink as backup WAN

# UDM-Pro supports dual WAN with failover
```

**Recommendation B: Add MikroTik Redundancy (VRRP)**
```bash
# Add second MikroTik router
# Configure VRRP for high availability
/interface vrrp add name=vrrp1 interface=bridge vrid=1 priority=200

# Both routers share virtual IP 172.16.0.2
# Automatic failover on primary failure
```

**Benefits**:
- Eliminates single point of failure
- Automatic failover (30-60 seconds)
- Planned maintenance without downtime

**Cost**: Medium (hardware + configuration)

### 3. Separate iSCSI Network Physically

**Current Issue**: iSCSI traffic shares network with other traffic
- Synology at 172.16.0.189 (main LAN)
- VLAN 77 requires routing through main network
- Potential performance impact

**Recommendation**: Dedicated iSCSI network
```
Option 1: Move Synology to VLAN 77 network
- Assign Synology interface to 172.16.77.x
- Direct connection to sfp-sfpplus2 (dedicated iSCSI port)
- No routing required

Option 2: Additional Synology NIC
- Add second NIC to Synology
- Dedicate to VLAN 77 (172.16.77.189)
- Keep management on 172.16.0.189
```

**Benefits**:
- Better iSCSI performance (no routing overhead)
- Reduced latency for storage traffic
- Network isolation for storage
- Full MTU 9000 path (currently limited by routing)

**Impact**: Medium (requires Synology reconfiguration)

## 🟠 High Priority

### 4. Enable FastTrack for Performance

**Current State**: All traffic processed by firewall rules
- High CPU usage for established connections
- Throughput limited by CPU processing

**Recommendation**: Enable FastTrack
```bash
# MikroTik - Add before existing rules
/ip firewall filter add chain=forward action=fasttrack-connection \
  connection-state=established,related \
  comment="FastTrack established connections"

/ip firewall filter add chain=forward action=accept \
  connection-state=established,related \
  comment="Accept FastTracked"
```

**Benefits**:
- 5-10x throughput improvement
- Reduced CPU usage (50-70% reduction)
- Better performance for vMotion, vSAN, file transfers

**Impact**: Low (add rules, test thoroughly)

### 5. Implement Centralized Logging (Syslog)

**Current State**: Logs stored locally only
- UDM-Pro: 7 days retention
- MikroTik: 1000 entries (circular buffer)
- No correlation between devices

**Recommendation**: Deploy syslog server
```bash
# Option 1: Dedicated VM (rsyslog/syslog-ng)
# Option 2: Container (Graylog/ELK stack)
# Option 3: Cloud service (Papertrail, Datadog)

# MikroTik configuration
/system logging action add name=remote target=remote remote=172.16.0.100 remote-port=514
/system logging add topics=firewall,error,warning,info action=remote

# UDM-Pro configuration (UniFi Controller)
# Settings → System → Logging → Remote Syslog
```

**Benefits**:
- Long-term log retention
- Correlation across devices
- Security incident investigation
- Compliance and auditing

**Cost**: Low (free tools available)

### 6. Add Network Monitoring (Prometheus + Grafana)

**Current State**: Limited visibility into network metrics
- No historical performance data
- Reactive troubleshooting only

**Recommendation**: Deploy monitoring stack
```yaml
# Components:
1. Prometheus - Metrics collection
2. Grafana - Visualization
3. SNMP Exporter - For UDM-Pro and MikroTik
4. Alertmanager - Notifications

# Key metrics to track:
- Interface bandwidth utilization
- CPU/Memory usage
- Connection tracking usage
- Firewall rule hits
- Error/drop counters
```

**Benefits**:
- Proactive issue detection
- Capacity planning
- Performance baselines
- SLA monitoring

**Impact**: Medium (deployment + configuration)

### 7. Document and Automate Backup Procedures

**Current State**: Manual backups (if any)

**Recommendation**: Automated configuration backups
```bash
# MikroTik - Automated backup script
/system scheduler add name=daily-backup interval=1d \
  on-event="/system backup save name=auto-backup-\$(date)"

/system scheduler add name=config-export interval=1d \
  on-event="/export file=auto-config-\$(date)"

# UDM-Pro - Automated backup via API
curl -X POST https://172.16.0.1/api/s/default/cmd/backup \
  -H "Content-Type: application/json" \
  -d '{"cmd":"backup"}'

# Store backups off-device:
- Git repository (this repo?)
- S3/Object storage
- Network share
```

**Benefits**:
- Disaster recovery capability
- Configuration versioning
- Quick rollback capability
- Change tracking

**Cost**: Low (automation scripts)

## 🟡 Medium Priority

### 8. Implement VLAN Best Practices

**Current Issues**:
- VLAN naming inconsistency
- No VLAN description standards
- Manual IP assignment tracking

**Recommendation A: Standardize VLAN naming**
```bash
# Current: vlan30-mgmt, vlan40-vmotion (inconsistent)
# Proposed: vlan-NNN-purpose format

# MikroTik example:
/interface vlan set [find vlan-id=30] name=vlan-030-fs-mgmt
/interface vlan set [find vlan-id=40] name=vlan-040-vmotion
```

**Recommendation B: Document VLAN registry**
```yaml
# Create vlan-registry.yaml
vlans:
  30:
    name: "FS Management"
    network: "172.16.30.0/24"
    gateway: "172.16.30.1"
    dhcp: false
    purpose: "vCenter and SDDC Manager"
    contacts: ["vmware-team@mxe11.nl"]
```

**Recommendation C: Implement IPAM**
- Tool: NetBox, phpIPAM, or simple spreadsheet
- Track: IP assignments, MAC addresses, hostnames
- Prevent IP conflicts

### 9. Enable Jumbo Frames End-to-End

**Current State**: Partial jumbo frame implementation
- VLANs 40, 50, 60, 77: MTU 9000 ✅
- Physical ports: MTU 9216 ✅
- VMs: Unknown (needs verification)

**Recommendation**: Verify end-to-end MTU
```bash
# Test from ESXi host to storage
vmkping -d -s 8972 172.16.50.1  # vSAN
vmkping -d -s 8972 172.16.77.1  # iSCSI

# If fails, check VM MTU configuration
# ESXi: vSwitch MTU should be 9000
# VM: Guest OS network adapter MTU 9000
```

**Benefits**:
- 10-15% performance improvement for large transfers
- Reduced CPU overhead
- Better storage performance

### 10. Implement Rate Limiting

**Current State**: No connection rate limiting
- Vulnerable to SYN floods
- No protection against scan attempts

**Recommendation**: Add rate limiting rules
```bash
# MikroTik - Limit new connections per source
/ip firewall filter add chain=forward action=drop \
  connection-state=new connection-rate=50,1m:100,1m \
  comment="Drop excessive new connections"

# SSH brute force protection
/ip firewall filter add chain=input action=add-src-to-address-list \
  protocol=tcp dst-port=22 connection-state=new \
  src-address-list=ssh_stage3 address-list=ssh_blacklist \
  address-list-timeout=1d

/ip firewall filter add chain=input action=drop \
  src-address-list=ssh_blacklist protocol=tcp dst-port=22
```

**Benefits**:
- Protection against DoS attacks
- Reduced brute force effectiveness
- Better resource utilization

### 11. Add DNS Redundancy

**Current State**: Single DNS server (172.16.0.53)

**Recommendation**: Secondary DNS server
```bash
# Option 1: Add secondary DNS on MikroTik
/ip dns set servers=172.16.0.53,172.16.0.2
/ip dns set allow-remote-requests=yes

# Option 2: Public DNS as fallback
/ip dns set servers=172.16.0.53,1.1.1.1,8.8.8.8

# Update DHCP to advertise both
```

**Benefits**:
- DNS redundancy
- Faster fallback on primary failure
- Better reliability

### 12. Segment Management Network Further

**Current Issue**: Management VLAN 30 accessible from main network
- Potential security risk
- No MFA requirement

**Recommendation**: Stricter access control
```bash
# Option 1: Jump host / Bastion
- Deploy jump host on VLAN 30
- Require SSH from jump host only
- Enable MFA on jump host

# Option 2: VPN access only
- Configure VPN on UDM-Pro
- Require VPN connection for VLAN 30 access
- Remove direct access from main network

# Option 3: Time-based access
/ip firewall filter add chain=forward \
  src-address=172.16.0.0/24 dst-address=172.16.30.0/24 \
  time=8h-18h,mon,tue,wed,thu,fri \
  action=accept comment="Business hours only"
```

## 🟢 Low Priority (Nice to Have)

### 13. IPv6 Implementation

**Current State**: IPv4 only

**Recommendation**: Enable IPv6
- Better security (IPSec native)
- Future-proofing
- Direct end-to-end connectivity

### 14. BGP for Multi-WAN

**If implementing dual WAN**:
```bash
# Run BGP for intelligent path selection
# Better than simple failover
# Can do load balancing
```

### 15. Network Documentation Automation

**Current**: Manual documentation (this repo)

**Recommendation**: Auto-generate from configs
```bash
# Tools:
- Ansible network fact gathering
- Oxidized (config backup + diff)
- NetBox API integration
```

### 16. QoS Implementation

**For prioritizing traffic**:
```bash
# Prioritize:
1. vMotion (VLAN 40) - High priority
2. Management (VLAN 20, 30) - Medium priority
3. vSAN (VLAN 50) - High priority
4. General traffic - Normal priority
```

### 17. Implement MAC Authentication

**For port security**:
```bash
# 802.1X authentication
# MAC-based VLAN assignment
# Rogue device detection
```

## Implementation Roadmap

### Phase 1 (Immediate - Month 1)
1. ✅ Fix MikroTik interface classification
2. ✅ Implement automated backups
3. ✅ Enable FastTrack
4. ✅ Add centralized logging

### Phase 2 (Short-term - Month 2-3)
5. ✅ Deploy monitoring (Prometheus/Grafana)
6. ✅ Implement rate limiting
7. ✅ Verify/enable jumbo frames end-to-end
8. ✅ Add DNS redundancy

### Phase 3 (Medium-term - Month 4-6)
9. ✅ Implement network redundancy (secondary WAN)
10. ✅ Separate iSCSI network physically
11. ✅ Improve management network security
12. ✅ Create VLAN registry/IPAM

### Phase 4 (Long-term - Month 6+)
13. ✅ Consider IPv6 implementation
14. ✅ Evaluate BGP for multi-WAN
15. ✅ QoS implementation
16. ✅ MAC authentication

## Cost Estimates

| Item | Cost | Notes |
|------|------|-------|
| Secondary MikroTik Router | $200-400 | For VRRP/HA |
| Secondary WAN (LTE) | $50/month | Backup internet |
| Monitoring VM (resources) | Free | Use existing infrastructure |
| Syslog VM (resources) | Free | Use existing infrastructure |
| IPAM tool (NetBox) | Free | Open source |
| Additional Synology NIC | $50-100 | For dedicated iSCSI |
| Total one-time | ~$300-500 | |
| Total monthly | ~$50 | Backup WAN only |

## Success Metrics

Track these metrics to measure improvement success:

1. **Availability**: Target 99.9% uptime
2. **MTTR** (Mean Time To Repair): < 30 minutes
3. **Backup Success Rate**: 100%
4. **Connection Tracking Usage**: < 50%
5. **Firewall Rule Efficiency**: Reduce total rules by 20%
6. **Network Throughput**: 10% improvement with FastTrack

## References

- [MikroTik Best Practices](https://wiki.mikrotik.com/wiki/Manual:Securing_Your_Router)
- [VMware vSphere Network Design](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-networking/GUID-35B40B0B-0C13-43B2-BC85-18C9C91BE2D4.html)
- [UniFi Best Practices](https://help.ui.com/hc/en-us/articles/219654087-UniFi-Best-Practices-for-Networks)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-06
**Next Review**: 2025-11-06
