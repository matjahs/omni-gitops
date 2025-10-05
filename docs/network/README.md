# Network Documentation

Comprehensive documentation for the mxe11.nl network infrastructure.

## 📋 Quick Reference

| Component | Address | Access | Status |
|-----------|---------|--------|--------|
| **UDM-Pro** | 172.16.0.1 | `ssh root@172.16.0.1` | ✅ Active |
| **MikroTik Router** | 172.16.0.2 | `ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2` | ✅ Active |
| **vCenter** | 172.16.30.100 | https://vc01.fs.corp.mxe11.nl | ✅ Active |
| **SDDC Manager** | 172.16.30.50 | https://172.16.30.50 | ✅ Active |
| **Synology NAS** | 172.16.0.189 | iSCSI Target | ✅ Active |
| **DNS Server** | 172.16.0.53 | Main resolver | ✅ Active |

## 📚 Documentation Structure

### Core Documentation

1. **[Network Topology](topology.md)** 📊
   - Physical network diagrams
   - Logical network flow
   - VLAN bridge architecture
   - Traffic flow examples
   - Port connectivity matrix
   - Network metrics

2. **[VLAN Configuration](vlans.md)** 🔀
   - VLAN inventory (UDM-Pro and MikroTik)
   - Network ranges and gateways
   - MTU configuration (jumbo frames)
   - Bridge VLAN filtering
   - VLAN troubleshooting guide

3. **[Routing Configuration](routing.md)** 🛣️
   - Static routes (UDM-Pro → MikroTik)
   - Inter-VLAN routing
   - Default gateway configuration
   - NAT/Masquerade rules
   - Routing flow examples

4. **[Firewall Rules](firewall.md)** 🔒
   - UDM-Pro firewall policies
   - MikroTik filter rules
   - Interface classifications (WAN/LAN)
   - Security policies
   - Port-specific rules

## 🏗️ Network Architecture

### High-Level Overview

```
Internet (77.165.76.73)
    ↓ PPPoE
UniFi Dream Machine Pro (172.16.0.1)
    ├── VLAN 1: Main LAN (172.16.0.0/24)
    ├── VLAN 2: Secondary (10.5.0.0/24)
    └── VLANs 11-13: Additional networks
         ↓ Static routes
MikroTik Router (172.16.0.2)
    ├── VLAN 15: Frontend (172.16.15.0/24)
    ├── VLAN 20: Management (172.16.20.0/24)
    ├── VLAN 25: Workload (172.16.25.0/24)
    ├── VLAN 30: FS Management (172.16.30.0/24) ⭐ vCenter
    ├── VLAN 40: vMotion (172.16.40.0/24) [Jumbo]
    ├── VLAN 50: vSAN (172.16.50.0/24) [Jumbo]
    ├── VLAN 60: NSX TEP (172.16.60.0/24) [Jumbo]
    ├── VLAN 70: Uplink (172.16.70.0/24)
    └── VLAN 77: iSCSI (172.16.77.0/24) [Jumbo]
```

### Key Design Principles

- **Hierarchical routing**: UDM-Pro (edge) → MikroTik (core) → VMware VLANs
- **Security in depth**: Firewall rules on both UDM-Pro and MikroTik
- **Network segmentation**: Isolated VLANs for management, storage, and workload
- **Jumbo frames**: MTU 9000 on high-performance VLANs (vMotion, vSAN, iSCSI, NSX)
- **Centralized NAT**: All internet traffic NAT'd at UDM-Pro

## 🔧 Common Operations

### Accessing Network Devices

#### UDM-Pro
```bash
ssh root@172.16.0.1

# View routing table
ip route show

# Check NAT rules
iptables -t nat -L -n -v
```

#### MikroTik Router
```bash
ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2

# View VLAN interfaces
/interface vlan print detail

# View firewall rules
/ip firewall filter print

# Check routing
/ip route print
```

### Network Troubleshooting

#### Connectivity Issues

**Step 1: Basic connectivity test**
```bash
# From client
ping 172.16.0.1     # UDM-Pro
ping 172.16.0.2     # MikroTik
ping 172.16.30.100  # vCenter
```

**Step 2: Check routing**
```bash
# From client
traceroute 172.16.30.100

# Expected path:
# 1. 172.16.0.1 (UDM-Pro)
# 2. 172.16.0.2 (MikroTik)
# 3. 172.16.30.100 (vCenter)
```

**Step 3: Verify ARP resolution (MikroTik)**
```bash
/ip arp print where interface=vlan30-mgmt

# Look for "reachable" status
# "failed" or "incomplete" indicates Layer 2 issues
```

**Step 4: Check firewall rules**
```bash
# MikroTik
/ip firewall filter print where src-address~"172.16.0" and dst-address~"172.16.30"

# Should show rule #31: Allow main network to VLAN30
```

#### VLAN Issues

**VM cannot reach network**
1. **Check VM port group assignment** in vSphere
   - VM IP must match VLAN port group
   - Example: IP 172.16.30.x → must be on VLAN 30 port group

2. **Verify VLAN interface on MikroTik**
   ```bash
   /interface vlan print where vlan-id=30
   # Ensure interface is enabled and has correct IP
   ```

3. **Check bridge VLAN filtering**
   ```bash
   /interface bridge vlan print where vlan-ids=30
   # Verify correct ports are tagged
   ```

#### Performance Issues

**High latency or packet loss**
1. **Check MTU configuration**
   ```bash
   # Test with large packets (jumbo frames)
   ping -M do -s 8972 172.16.50.1  # vSAN VLAN
   ```

2. **Monitor interface statistics**
   ```bash
   # MikroTik
   /interface monitor-traffic ether1
   ```

3. **Check connection tracking**
   ```bash
   # UDM-Pro
   cat /proc/net/nf_conntrack | wc -l
   # Should be < 65536 (max capacity)
   ```

## 🚨 Known Issues & Solutions

### Issue 1: Main Network Cannot Access VLAN 30

**Problem**: Clients on 172.16.0.0/24 cannot reach 172.16.30.0/24

**Root Cause**: MikroTik classifies ether1 as WAN, blocking WAN→LAN traffic

**Solution**: Firewall rule #31 added to explicitly allow this traffic
```bash
/ip firewall filter print where comment~"Allow main network to VLAN30"
# Rule should be present and enabled
```

### Issue 2: VM Has IP But Unreachable

**Problem**: VM has correct IP but cannot be reached

**Root Cause**: IP-VLAN mismatch (VM connected to wrong port group)

**Solution**:
1. Check VM IP address: `172.16.30.x`
2. Verify port group in vSphere: Should be `dvs-pg-vlan30` (not vlan20 or others)
3. Reconfigure VM network adapter to correct port group

### Issue 3: iSCSI Connectivity Fails

**Problem**: ESXi hosts cannot connect to Synology iSCSI target

**Root Cause**: iSCSI VLAN 77 cannot reach 172.16.0.189

**Solution**: Verify routing from VLAN 77 → Main LAN
```bash
# MikroTik
/ip firewall filter print where src-address~"172.16.77" and dst-address~"172.16.0"
# Should allow TCP port 3260
```

## 📊 Network Statistics

### Current Utilization (as of last check)

**UDM-Pro**:
- Uptime: 23+ days
- WAN Traffic: 1.0 TiB RX / 253.8 GiB TX
- Connection Tracking: 2,925 / 65,536 (4.5%)
- Active TCP: 124 established connections

**MikroTik**:
- VLAN 30 Traffic: 487 MB RX / 112 GB TX
- Bridge VLAN Filtering: Enabled
- Hardware Offload: Active on all ports

### Performance Baselines

| Metric | Expected | Threshold |
|--------|----------|-----------|
| Ping to UDM-Pro | < 1ms | < 5ms |
| Ping to MikroTik | < 1ms | < 5ms |
| Ping to vCenter | < 2ms | < 10ms |
| Connection tracking | < 10% | < 80% |
| CPU (UDM-Pro) | < 20% | < 70% |
| CPU (MikroTik) | < 10% | < 60% |

## 🔐 Security Considerations

### Firewall Strategy
- **Default deny**: All traffic denied unless explicitly allowed
- **Stateful inspection**: Connection tracking on both devices
- **Rate limiting**: Configured for SSH and management ports
- **Logging**: Enabled for dropped packets

### Access Control
- **Management access**: Restricted to 172.16.0.0/24
- **SSH keys**: Required for MikroTik access
- **VLAN isolation**: Storage and management networks separated

### Monitoring
- **UDM-Pro**: DPI and IDS/IPS enabled
- **Honeypot**: 10.5.0.4 for security monitoring
- **Logging**: Centralized logging recommended (syslog)

## 📝 Maintenance Tasks

### Weekly
- [ ] Check connection tracking utilization
- [ ] Review firewall logs for anomalies
- [ ] Verify all critical services are reachable

### Monthly
- [ ] Review and audit firewall rules
- [ ] Check for firmware updates (UDM-Pro and MikroTik)
- [ ] Validate backup configurations exist
- [ ] Review network performance metrics

### Quarterly
- [ ] Update network documentation
- [ ] Test disaster recovery procedures
- [ ] Review VLAN assignments
- [ ] Audit user access and permissions

## 🛠️ Emergency Procedures

### Network Down

1. **Check UDM-Pro status**:
   ```bash
   ssh root@172.16.0.1
   systemctl status unifi
   ```

2. **Check MikroTik status**:
   ```bash
   ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2
   /system resource print
   ```

3. **Verify WAN connectivity**:
   ```bash
   ping 8.8.8.8  # From UDM-Pro
   ```

### Firewall Lockout

**MikroTik**:
- Connect via console cable (serial)
- Login with admin credentials
- Disable problematic rule:
  ```bash
  /ip firewall filter disable [find comment="problem rule"]
  ```

**UDM-Pro**:
- Access via UniFi Cloud Console
- Temporarily disable firewall
- SSH access via console if needed

### Configuration Rollback

**MikroTik backup**:
```bash
# Export current config
/export file=backup-$(date +%Y%m%d)

# Restore previous config
/import file=backup-20231215.rsc
```

## 📞 Support Contacts

- **Network Documentation**: This repository
- **UDM-Pro Support**: UniFi community forums
- **MikroTik Support**: MikroTik wiki and forums
- **VMware Support**: VMware documentation

## 🔗 External Resources

### UDM-Pro
- [UniFi Dream Machine Pro Documentation](https://help.ui.com/hc/en-us/categories/200320654-UniFi-Routing-Switching)
- [UniFi OS CLI Commands](https://help.ui.com/hc/en-us/articles/204909374-UniFi-Device-CLI-Commands)

### MikroTik
- [MikroTik Wiki](https://wiki.mikrotik.com/)
- [RouterOS Manual](https://help.mikrotik.com/docs/display/ROS/RouterOS)
- [VLAN Configuration Guide](https://wiki.mikrotik.com/wiki/Manual:Interface/VLAN)

### VMware
- [vSphere Networking Guide](https://docs.vmware.com/en/VMware-vSphere/)
- [vSAN Network Design](https://core.vmware.com/resource/vsan-network-design-guide)

---

**Last Updated**: 2025-10-06
**Documentation Version**: 1.0
**Maintainer**: Network Infrastructure Team
