# Routing Configuration

## Overview

The network uses a hierarchical routing design with the UDM-Pro as the primary gateway and the MikroTik router handling VMware infrastructure routing.

```
Internet → UDM-Pro (172.16.0.1) → MikroTik (172.16.0.2) → VMware VLANs
```

## UDM-Pro Routing (172.16.0.1)

### WAN Interface
- **Type**: PPPoE
- **Interface**: eth8
- **Public IP**: 77.165.76.73
- **Status**: Connected (23+ days uptime)
- **Default Gateway**: Provided by ISP via PPPoE

### LAN Interfaces

| Interface | VLAN | Network | Gateway | Description |
|-----------|------|---------|---------|-------------|
| br0 | 1 | 172.16.0.0/24 | 172.16.0.1 | Main LAN |
| br2 | 2 | 10.5.0.0/24 | 10.5.0.1 | Secondary Network |
| br11 | 11 | 172.16.251.0/24 | 172.16.251.1 | Network 11 |
| br12 | 12 | 192.168.30.0/24 | 192.168.30.1 | Network 12 |
| br13 | 13 | 172.16.13.0/24 | 172.16.13.1 | Network 13 |

### Static Routes

#### Route to MikroTik Managed Networks
The UDM-Pro has static routes configured to reach all MikroTik-managed VLANs via 172.16.0.2:

```
172.16.15.0/24 via 172.16.0.2
172.16.20.0/24 via 172.16.0.2
172.16.25.0/24 via 172.16.0.2
172.16.30.0/24 via 172.16.0.2
172.16.40.0/24 via 172.16.0.2
172.16.50.0/24 via 172.16.0.2
172.16.60.0/24 via 172.16.0.2
172.16.70.0/24 via 172.16.0.2
172.16.77.0/24 via 172.16.0.2
```

**Purpose**: Forward all VMware infrastructure traffic to the MikroTik router for inter-VLAN routing.

### NAT Configuration
- **Type**: Source NAT (SNAT) / Masquerade
- **Scope**: All LAN networks to WAN
- **Public IP**: 77.165.76.73
- **Connection Tracking**: 2,925 / 65,536 connections (4.5% utilization)
- **Active TCP Connections**: 124 established

## MikroTik Routing (172.16.0.2)

### Connected Routes

The MikroTik router has directly connected routes for all its VLAN interfaces:

| Network | Interface | Gateway | Status |
|---------|-----------|---------|--------|
| 172.16.0.0/24 | bridge | 172.16.0.2 | Active (LAN connectivity) |
| 172.16.15.0/24 | vlan15-frontend | 172.16.15.1 | Active |
| 172.16.20.0/24 | vlan20-mgmt | 172.16.20.1 | Active |
| 172.16.25.0/24 | vlan25-workload | 172.16.25.1 | Active |
| 172.16.30.0/24 | vlan30-mgmt | 172.16.30.1 | Active |
| 172.16.40.0/24 | vlan40-vmotion | 172.16.40.1 | Active |
| 172.16.50.0/24 | vlan50-vsan | 172.16.50.1 | Active |
| 172.16.60.0/24 | vlan60-tep | 172.16.60.1 | Active |
| 172.16.70.0/24 | vlan70-uplink | 172.16.70.1 | Active |
| 172.16.77.0/24 | vlan77-iscsi | 172.16.77.1 | Active |

### Default Gateway
```
0.0.0.0/0 via 172.16.0.1 (UDM-Pro)
```

All internet-bound traffic from MikroTik VLANs is routed to the UDM-Pro for NAT and WAN access.

### Inter-VLAN Routing

The MikroTik router provides Layer 3 routing between all its VLANs. By default:
- All VLANs can communicate with each other
- Firewall rules control access between specific VLANs
- See [firewall.md](firewall.md) for access control policies

## Routing Flow Examples

### Client to vCenter (172.16.0.199 → 172.16.30.100)

```
1. Client (172.16.0.199) sends packet to 172.16.30.100
2. UDM-Pro (172.16.0.1) receives packet
3. UDM-Pro checks routing table:
   - Destination: 172.16.30.0/24
   - Next-hop: 172.16.0.2 (MikroTik)
4. UDM-Pro forwards to MikroTik (172.16.0.2)
5. MikroTik checks firewall rules (allow 172.16.0.0/24 → 172.16.30.0/24)
6. MikroTik routes to vlan30-mgmt interface
7. Packet delivered to 172.16.30.100 (vCenter)
```

### VMware vMotion (VLAN 40 to VLAN 20)

```
1. ESXi host on VLAN 40 initiates vMotion to host on VLAN 20
2. Packet arrives at MikroTik vlan40-vmotion interface (172.16.40.1)
3. MikroTik performs inter-VLAN routing to vlan20-mgmt
4. Firewall rule allows VLAN 40 → VLAN 20 traffic
5. Packet delivered to destination ESXi on VLAN 20
```

### iSCSI Storage Access (VLAN 77 to Main LAN)

```
1. ESXi iSCSI initiator on VLAN 77 connects to 172.16.0.189 (Synology)
2. Packet arrives at MikroTik vlan77-iscsi interface (172.16.77.1)
3. MikroTik routes to bridge interface (172.16.0.2)
4. Firewall rule allows VLAN 77 → 172.16.0.0/24
5. Packet forwarded to UDM-Pro → Synology at 172.16.0.189
```

### Internet Access from VLAN 30

```
1. vCenter (172.16.30.100) sends packet to internet destination
2. MikroTik (vlan30-mgmt) receives packet
3. MikroTik checks routing table:
   - Default route: 0.0.0.0/0 via 172.16.0.1
4. Packet forwarded to UDM-Pro (172.16.0.1)
5. UDM-Pro performs NAT (172.16.30.100 → 77.165.76.73)
6. Packet sent to internet via PPPoE WAN
```

## Asymmetric Routing Prevention

### Current Design
The network is designed to prevent asymmetric routing:
- **Single default gateway per VLAN**: Each VLAN has only one gateway (MikroTik)
- **Centralized NAT**: All internet traffic flows through UDM-Pro
- **No route leaking**: UDM-Pro does not advertise internet routes to MikroTik VLANs

### Routing Symmetry
- **Outbound**: VLAN → MikroTik → UDM-Pro → Internet
- **Inbound**: Internet → UDM-Pro → MikroTik → VLAN

## DNS Configuration

### UDM-Pro DNS
- **Primary DNS**: 172.16.0.53 (likely running on UDM-Pro or internal server)
- **Domain**: mxe11.nl
- **DNS Forwarding**: Enabled for all LAN clients

### MikroTik DNS
- MikroTik forwards DNS queries to UDM-Pro (172.16.0.1)
- No local DNS caching configured

### Client DNS Resolution
```
Client → UDM-Pro (172.16.0.53) → External DNS servers
```

## Routing Verification

### UDM-Pro Commands
```bash
# View routing table
ip route show

# View NAT rules
iptables -t nat -L -n -v

# Test connectivity
ping -c 3 172.16.0.2
traceroute 172.16.30.100
```

### MikroTik Commands
```bash
# View all routes
/ip route print

# View connected routes only
/ip route print where type=connected

# View static routes only
/ip route print where type=static

# Check default gateway
/ip route print where dst-address=0.0.0.0/0

# Trace route to destination
/tool traceroute 8.8.8.8
```

## Performance Metrics

### UDM-Pro Traffic Statistics
- **WAN RX**: 1.0 TiB (23+ days)
- **WAN TX**: 253.8 GiB (23+ days)
- **Throughput**: ~500 Mbps peak
- **Connection Tracking**: 4.5% utilization

### MikroTik VLAN Statistics
- **VLAN 30 (Management)**:
  - RX: 487 MB
  - TX: 112 GB
  - Primary traffic: vCenter/vSphere management

## Routing Troubleshooting

### No Connectivity to MikroTik VLANs

1. **Check static routes on UDM-Pro**:
   ```bash
   ip route show | grep 172.16.0.2
   ```
   Expected: Routes for 172.16.15.0/24 through 172.16.77.0/24

2. **Verify MikroTik reachability**:
   ```bash
   ping 172.16.0.2
   ```

3. **Check firewall rules** (both UDM-Pro and MikroTik)

### Asymmetric Routing Issues

1. **Verify default route on MikroTik**:
   ```bash
   /ip route print where dst-address=0.0.0.0/0
   ```

2. **Check NAT on UDM-Pro** for proper source translation

3. **Verify no duplicate gateways** are configured on VLAN interfaces

### MTU Issues

1. **Path MTU Discovery**:
   ```bash
   # From client
   ping -M do -s 8972 172.16.50.1  # Test jumbo frames (9000 MTU)
   ```

2. **Check interface MTU**:
   ```bash
   # MikroTik
   /interface print without-paging
   ```

## Route Optimization

### Current Optimization
- **Hardware offload enabled** on all MikroTik bridge ports
- **FastTrack** not configured (consider for high-throughput scenarios)
- **Route caching** enabled by default

### Recommendations
1. Enable FastTrack for established connections to improve throughput
2. Consider ECMP (Equal-Cost Multi-Path) for redundant links
3. Monitor routing table size as network grows
