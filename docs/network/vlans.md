# VLAN Configuration

## Overview

The network uses a two-tier VLAN architecture:
- **UDM-Pro**: Manages VLANs 1, 2, 11-13 for general network services
- **MikroTik Router**: Manages VLANs 15-77 for VMware infrastructure and specialized services

## VLAN Inventory

### UDM-Pro VLANs (172.16.0.1)

| VLAN ID | Bridge | Network | Gateway | Purpose | Status |
|---------|--------|---------|---------|---------|--------|
| 1 | br0 | 172.16.0.0/24 | 172.16.0.1 | Main LAN | Active |
| 2 | br2 | 10.5.0.0/24 | 10.5.0.1 | Secondary Network | Active |
| 11 | br11 | 172.16.251.0/24 | 172.16.251.1 | Network 11 | Active |
| 12 | br12 | 192.168.30.0/24 | 192.168.30.1 | Network 12 | Active |
| 13 | br13 | 172.16.13.0/24 | 172.16.13.1 | Network 13 | Active |

### MikroTik VLANs (172.16.0.2)

| VLAN ID | Interface | Network | Gateway | Purpose | MTU | Classification |
|---------|-----------|---------|---------|---------|-----|----------------|
| 15 | vlan15-frontend | 172.16.15.0/24 | 172.16.15.1 | Frontend Network | 1500 | LAN |
| 20 | vlan20-mgmt | 172.16.20.0/24 | 172.16.20.1 | VMware Management | 1500 | LAN |
| 25 | vlan25-workload | 172.16.25.0/24 | 172.16.25.1 | Workload Network | 1500 | LAN |
| 30 | vlan30-mgmt | 172.16.30.0/24 | 172.16.30.1 | FS Management / vCenter | 1500 | LAN |
| 40 | vlan40-vmotion | 172.16.40.0/24 | 172.16.40.1 | vMotion Traffic | 9000 | LAN |
| 50 | vlan50-vsan | 172.16.50.0/24 | 172.16.50.1 | vSAN Storage | 9000 | LAN |
| 60 | vlan60-tep | 172.16.60.0/24 | 172.16.60.1 | NSX-T TEP (Tunnel Endpoints) | 9000 | LAN |
| 70 | vlan70-uplink | 172.16.70.0/24 | 172.16.70.1 | Uplink Network | 1500 | LAN |
| 77 | vlan77-iscsi | 172.16.77.0/24 | 172.16.77.1 | iSCSI Storage | 9000 | LAN |

## VLAN Purposes

### Infrastructure VLANs

#### VLAN 1 - Main LAN (172.16.0.0/24)
- **Primary corporate network**
- Client workstations and devices
- DNS server: 172.16.0.53
- Gateway: 172.16.0.1 (UDM-Pro)
- Static route to 172.16.0.2 for accessing MikroTik managed networks

#### VLAN 2 - Secondary Network (10.5.0.0/24)
- Security monitoring
- Honeypot: 10.5.0.4

#### VLAN 11-13 - Additional Networks
- Purpose: General network segments
- Managed by UDM-Pro

### VMware Infrastructure VLANs (MikroTik)

#### VLAN 15 - Frontend (172.16.15.0/24)
- Frontend application network
- Standard MTU: 1500

#### VLAN 20 - Management (172.16.20.0/24)
- VMware ESXi host management
- vSphere client access
- Standard MTU: 1500

#### VLAN 25 - Workload (172.16.25.0/24)
- VM workload network
- General purpose VM traffic
- Standard MTU: 1500

#### VLAN 30 - FS Management (172.16.30.0/24)
- vCenter Server: vc01.fs.corp.mxe11.nl (172.16.30.100)
- SDDC Manager: 172.16.30.50
- **Important**: Ensure VMs have correct port group assignment
- Standard MTU: 1500

#### VLAN 40 - vMotion (172.16.40.0/24)
- Live migration traffic between ESXi hosts
- High-performance network
- Jumbo frames enabled: MTU 9000
- Port: 8000

#### VLAN 50 - vSAN (172.16.50.0/24)
- vSAN cluster storage traffic
- Storage synchronization
- Jumbo frames enabled: MTU 9000

#### VLAN 60 - TEP/NSX (172.16.60.0/24)
- NSX-T Tunnel Endpoint Network
- Overlay network encapsulation
- Jumbo frames enabled: MTU 9000

#### VLAN 70 - Uplink (172.16.70.0/24)
- External uplink network
- Standard MTU: 1500

#### VLAN 77 - iSCSI (172.16.77.0/24)
- Dedicated iSCSI storage network
- Synology NAS: 172.16.0.189 (accessible via routing)
- Jumbo frames enabled: MTU 9000
- Port: 3260
- **SFP+ 2 (sfp-sfpplus2)**: Dedicated iSCSI port with PVID 77

## MikroTik Bridge VLAN Configuration

### Bridge Interface
- **Name**: bridge
- **IP**: 172.16.0.2/24
- **VLAN Filtering**: Enabled
- **Hardware Offload**: Active

### Tagged Ports (All VLANs)

All VLANs 15, 20, 25, 30, 40, 50, 60, 70, 77 are tagged on:
- **ether1** (Uplink) - MTU 9216
- **ether3** (Red) - MTU 9216
- **ether4** (Black) - MTU 9216
- **ether5** (Port 5) - MTU 9216
- **ether8** (Yellow) - MTU 9216
- **sfp-sfpplus1** (Fiber uplink) - MTU 9216

### Special Port Configuration

#### sfp-sfpplus2 (iSCSI Dedicated)
- **PVID**: 77 (iSCSI VLAN)
- **Purpose**: Dedicated iSCSI storage link
- **MTU**: 9216
- **Tagged**: VLAN 77 only

## VLAN Access Control

### Firewall Rules Applied
- **Main LAN → VLAN 30**: Explicitly allowed (Rule #31)
  ```
  action=accept src-address=172.16.0.0/24 dst-address=172.16.30.0/24
  ```
- All MikroTik VLANs classified as **LAN** for firewall purposes
- Bridge port ether1 (172.16.0.2) provides interconnection with UDM-Pro

## Jumbo Frame Configuration

### Jumbo Frames Enabled (MTU 9000)
- VLAN 40 (vMotion)
- VLAN 50 (vSAN)
- VLAN 60 (NSX TEP)
- VLAN 77 (iSCSI)

### Physical Ports (MTU 9216)
All MikroTik physical interfaces configured with MTU 9216 to support jumbo frame VLANs plus overhead.

## VLAN Troubleshooting

### Common Issues

#### IP-VLAN Mismatch
- **Symptom**: VM unreachable despite correct IP configuration
- **Cause**: VM connected to wrong vSphere port group
- **Resolution**: Verify VM network adapter is connected to correct VLAN port group
  - Example: VM with IP 172.16.30.x must be on VLAN 30 port group, not VLAN 20

#### ARP Resolution Failures
- **Symptom**: ARP entries show "failed" or "incomplete" status
- **Check**:
  1. VLAN interface configuration
  2. Bridge VLAN filtering rules
  3. Physical port VLAN tagging
  4. VM port group assignment

#### MTU Mismatch
- **Symptom**: Connectivity works but performance is degraded or fragmentation occurs
- **Check**: Ensure all devices in path support configured MTU
  - Jumbo frame VLANs require MTU 9000 on both VMs and physical infrastructure

## VLAN Verification Commands

### MikroTik
```bash
# View VLAN interfaces
/interface vlan print detail

# Check bridge VLAN filtering
/interface bridge vlan print

# Verify bridge ports
/interface bridge port print

# Check ARP table per VLAN
/ip arp print where interface=vlan30-mgmt
```

### UDM-Pro
```bash
# View VLAN configuration
brctl show

# Check interface status
ip addr show

# View routing table
ip route show
```
