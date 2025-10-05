# Firewall Configuration

## Overview

The network implements a defense-in-depth firewall strategy with rules on both the UDM-Pro and MikroTik router.

## UDM-Pro Firewall (172.16.0.1)

### Default Policy
- **WAN → LAN**: DROP (implicit deny)
- **LAN → WAN**: ACCEPT
- **LAN → LAN**: ACCEPT (inter-VLAN routing allowed)

### NAT Rules
```
# Masquerade all LAN traffic to WAN
-A POSTROUTING -o pppoe0 -j MASQUERADE

# Masquerade for each LAN subnet
-A POSTROUTING -s 172.16.0.0/24 -o pppoe0 -j MASQUERADE
-A POSTROUTING -s 10.5.0.0/24 -o pppoe0 -j MASQUERADE
-A POSTROUTING -s 172.16.251.0/24 -o pppoe0 -j MASQUERADE
-A POSTROUTING -s 192.168.30.0/24 -o pppoe0 -j MASQUERADE
-A POSTROUTING -s 172.16.13.0/24 -o pppoe0 -j MASQUERADE
```

### Stateful Firewall
- **Connection Tracking**: Enabled
  - Current: 2,925 connections
  - Capacity: 65,536 connections
  - Utilization: 4.5%
- **Established/Related**: Automatically allowed
- **Invalid State**: Dropped

### Security Features
- **DPI (Deep Packet Inspection)**: Enabled
- **IDS/IPS**: UniFi Threat Management
- **Connection Rate Limiting**: Configured per WAN
- **Port Forwarding**: Managed via UniFi Controller

## MikroTik Firewall (172.16.0.2)

### Interface Classification

#### Interface Lists

**WAN Interfaces**:
- `ether1` (172.16.0.2) - Connected to UDM-Pro main LAN

**LAN Interfaces**:
- `vlan15-frontend` (172.16.15.1)
- `vlan20-mgmt` (172.16.20.1)
- `vlan25-workload` (172.16.25.1)
- `vlan30-mgmt` (172.16.30.1)
- `vlan40-vmotion` (172.16.40.1)
- `vlan50-vsan` (172.16.50.1)
- `vlan60-tep` (172.16.60.1)
- `vlan70-uplink` (172.16.70.1)
- `vlan77-iscsi` (172.16.77.1)

**Note**: ether1 is classified as WAN because it faces the UDM-Pro, but all VLANs are classified as LAN for VMware infrastructure protection.

### Filter Rules (Chain: forward)

#### Rule #0-29: Base Protection Rules
```bash
# Accept established/related connections
action=accept connection-state=established,related

# Drop invalid connections
action=drop connection-state=invalid

# Accept LAN to WAN traffic
action=accept in-interface-list=LAN out-interface-list=WAN

# Drop WAN to LAN by default (unless explicitly allowed)
action=drop in-interface-list=WAN out-interface-list=LAN
```

#### Rule #31: Main Network to VLAN 30 Access (Added)
```bash
# Allow main network access to vCenter/FS Management
chain=forward
action=accept
src-address=172.16.0.0/24
dst-address=172.16.30.0/24
comment="Allow main network to VLAN30"
```

**Purpose**: This rule was added to allow clients on the main network (172.16.0.0/24) to access vCenter and SDDC Manager on VLAN 30. Without this rule, traffic from 172.16.0.0/24 was treated as WAN→LAN and blocked.

#### Inter-VLAN Rules

**VMware Infrastructure Communication**:
```bash
# VLAN 20 (Management) → VLAN 30 (vCenter)
action=accept src-address=172.16.20.0/24 dst-address=172.16.30.0/24

# VLAN 40 (vMotion) ↔ VLAN 20 (Management)
action=accept src-address=172.16.40.0/24 dst-address=172.16.20.0/24
action=accept src-address=172.16.20.0/24 dst-address=172.16.40.0/24

# VLAN 50 (vSAN) ↔ VLAN 20 (Management)
action=accept src-address=172.16.50.0/24 dst-address=172.16.20.0/24
action=accept src-address=172.16.20.0/24 dst-address=172.16.50.0/24

# VLAN 60 (NSX TEP) ↔ VLAN 20 (Management)
action=accept src-address=172.16.60.0/24 dst-address=172.16.20.0/24
action=accept src-address=172.16.20.0/24 dst-address=172.16.60.0/24

# VLAN 77 (iSCSI) → 172.16.0.0/24 (Synology)
action=accept src-address=172.16.77.0/24 dst-address=172.16.0.0/24 protocol=tcp dst-port=3260
```

### Input Rules (Chain: input)

```bash
# Accept established/related
action=accept connection-state=established,related

# Drop invalid
action=drop connection-state=invalid

# Accept ICMP (ping, traceroute)
action=accept protocol=icmp

# Accept from LAN
action=accept in-interface-list=LAN

# Accept SSH from specific source (management)
action=accept protocol=tcp dst-port=22 src-address=172.16.0.0/24

# Drop everything else
action=drop
```

### NAT Rules (Chain: srcnat)

```bash
# Masquerade all LAN traffic going to WAN
action=masquerade chain=srcnat out-interface-list=WAN
```

## Firewall Rule Ordering

### MikroTik Rule Priority (Forward Chain)

The order is critical - rules are processed top-to-bottom:

1. **Accept established/related** (Rule #0)
2. **Drop invalid** (Rule #1)
3. **Accept LAN → WAN** (Rule #2)
4. **Accept specific inter-VLAN traffic** (Rules #3-30)
5. **Accept 172.16.0.0/24 → 172.16.30.0/24** (Rule #31) ⭐
6. **Drop WAN → LAN** (implicit at end)

**Rule #31 Placement**: Placed before the implicit WAN→LAN drop to allow main network access to VLAN 30.

## Port-Specific Rules

### Management Ports

| Port | Protocol | Source | Destination | Action | Purpose |
|------|----------|--------|-------------|--------|---------|
| 22 | TCP | 172.16.0.0/24 | MikroTik | ACCEPT | SSH access to router |
| 443 | TCP | 172.16.0.0/24 | 172.16.30.0/24 | ACCEPT | vCenter HTTPS |
| 9443 | TCP | 172.16.0.0/24 | 172.16.30.0/24 | ACCEPT | SDDC Manager |

### Storage Ports

| Port | Protocol | Source | Destination | Action | Purpose |
|------|----------|--------|-------------|--------|---------|
| 3260 | TCP | 172.16.77.0/24 | 172.16.0.189 | ACCEPT | iSCSI to Synology |
| 2049 | TCP | VLAN 20,50 | 172.16.0.189 | ACCEPT | NFS (if used) |

### VMware Ports

| Port | Protocol | Source | Destination | Action | Purpose |
|------|----------|--------|-------------|--------|---------|
| 8000 | TCP | VLAN 40 | VLAN 20 | ACCEPT | vMotion |
| 2233 | TCP | VLAN 50 | VLAN 50 | ACCEPT | vSAN clustering |

## Security Policies

### Default Deny Strategy
- **Default policy**: Deny all traffic not explicitly allowed
- **Explicit allows**: Only necessary services permitted
- **Logging**: Enabled for dropped packets (security monitoring)

### Network Segmentation
- **Management isolation**: VLAN 30 accessible only from authorized networks
- **Storage isolation**: iSCSI traffic confined to VLAN 77
- **vMotion isolation**: VLAN 40 traffic restricted to VMware hosts only

### Attack Prevention

#### SYN Flood Protection
```bash
# Rate limit new connections
action=drop protocol=tcp tcp-flags=syn connection-limit=50,32 \
  comment="Drop SYN flood"
```

#### Port Scan Detection
```bash
# Detect port scanning
action=add-src-to-address-list address-list=port_scanners \
  protocol=tcp psd=21,3s,3,1 \
  comment="Detect port scan"

# Block port scanners
action=drop src-address-list=port_scanners \
  comment="Block port scanners"
```

#### Brute Force Protection (SSH)
```bash
# Limit SSH connection attempts
action=add-src-to-address-list address-list=ssh_blacklist \
  protocol=tcp dst-port=22 connection-state=new \
  src-address-list=ssh_stage3

# Drop blacklisted IPs
action=drop src-address-list=ssh_blacklist protocol=tcp dst-port=22
```

## Firewall Logging

### MikroTik Logging

**Logged Events**:
- Dropped packets (rule violations)
- Connection state errors
- Port scan attempts
- Authentication failures

**Log Storage**:
- Local: 1000 entries
- Remote: Optional syslog to central server

### UDM-Pro Logging

**Logged Events**:
- DPI detections
- IDS/IPS alerts
- Connection tracking stats
- Threat management events

**Retention**: 7 days (configurable)

## Verification Commands

### MikroTik Commands

```bash
# View all firewall rules
/ip firewall filter print

# View specific chain
/ip firewall filter print chain=forward

# View rule statistics (packet/byte counters)
/ip firewall filter print stats

# View connection tracking
/ip firewall connection print

# View address lists (blocklists)
/ip firewall address-list print

# Test rule matching
/ip firewall filter add chain=forward action=log src-address=172.16.0.0/24 \
  dst-address=172.16.30.0/24 log-prefix="TEST: "
```

### UDM-Pro Commands

```bash
# View iptables rules
iptables -L -n -v

# View NAT rules
iptables -t nat -L -n -v

# View connection tracking
conntrack -L

# View mangle rules (QoS)
iptables -t mangle -L -n -v
```

## Common Firewall Issues

### Issue 1: WAN→LAN Classification Error

**Problem**: Traffic from 172.16.0.0/24 to 172.16.30.0/24 blocked
**Cause**: ether1 interface classified as WAN, blocking "WAN→LAN" traffic
**Solution**: Add explicit allow rule (Rule #31) before WAN→LAN drop

```bash
/ip firewall filter add chain=forward action=accept \
  src-address=172.16.0.0/24 dst-address=172.16.30.0/24 \
  place-before=2 comment="Allow main network to VLAN30"
```

### Issue 2: Inter-VLAN Traffic Blocked

**Problem**: VMs on different VLANs cannot communicate
**Cause**: Missing inter-VLAN firewall rules
**Solution**: Add bidirectional rules for required VLAN pairs

### Issue 3: Connection Tracking Table Full

**Problem**: New connections fail when connection tracking table is full
**Cause**: High connection count or connection timeout too long
**Solution**:
```bash
# Increase connection tracking size (UDM-Pro)
sysctl -w net.netfilter.nf_conntrack_max=131072

# Reduce timeout values
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600
```

## Security Recommendations

1. **Regular rule review**: Audit firewall rules quarterly
2. **Least privilege**: Only open required ports/protocols
3. **Enable logging**: Log all dropped packets for security analysis
4. **Rate limiting**: Implement connection rate limits per source
5. **Geo-blocking**: Consider blocking traffic from unused countries (WAN)
6. **VLAN ACLs**: Add Layer 2 ACLs on switch for additional security
7. **IDS/IPS**: Enable UniFi Threat Management on UDM-Pro

## Emergency Access

### Temporary Rule Disable

**MikroTik**:
```bash
# Disable specific rule by number
/ip firewall filter disable 31

# Re-enable
/ip firewall filter enable 31
```

**UDM-Pro**:
- Use UniFi Controller to temporarily disable firewall
- SSH access via console cable if locked out

### Firewall Reset

**MikroTik** (⚠️ Use with caution):
```bash
# Backup current rules
/ip firewall filter export file=firewall-backup

# Remove all rules
/ip firewall filter remove [find]

# Restore from backup
/import firewall-backup.rsc
```
