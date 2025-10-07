# Implementation Guide: Network Redundancy

## Overview

**Goal**: Eliminate single points of failure in network infrastructure

**Solutions**:
1. **Secondary WAN** - Backup internet connection (Primary implementation)
2. **MikroTik VRRP** - Router high availability (Optional, advanced)

**Duration**: 2-4 hours (depending on scope)

**Risk Level**: Medium to High

---

## Part A: Secondary WAN Implementation

### Prerequisites

- [ ] Choose backup WAN type:
  - ✅ **LTE/5G USB Modem** (Recommended: $50/month, easy setup)
  - ✅ **Secondary ISP** (Best: Different provider, $60-80/month)
  - ✅ **Starlink** (Backup option: $120/month, satellite)

- [ ] Verify UDM-Pro supports dual WAN (it does ✅)
- [ ] Obtain backup WAN credentials/SIM card
- [ ] Plan failover thresholds

---

### Option 1: LTE/5G USB Modem (Easiest)

#### Hardware Required
- LTE/5G USB modem (compatible with UDM-Pro)
  - Recommended: Huawei E3372, ZTE MF833, or Netgear LM1200
- Active SIM card with data plan
- Cost: ~$80 hardware + $50/month data

#### Step 1: Physical Installation

```bash
# 1. Insert SIM card into USB modem
# 2. Connect USB modem to UDM-Pro USB port
# 3. Wait 30 seconds for detection
```

#### Step 2: Configure via UniFi Controller

**Via Web UI**:
```
1. Open UniFi Controller → https://172.16.0.1
2. Navigate to: Settings → Internet → WAN Networks
3. Click "+ Create New Network"

Settings:
- Name: "WAN2-LTE"
- Connection Type: "DHCP" (or PPP for some modems)
- Failover: "Enabled"
- Priority: "2" (lower than primary WAN)
- Load Balancing: "Disabled" (use failover only)
```

**Failover Configuration**:
```
Settings → Internet → Failover & Load Balancing

Primary WAN (pppoe0):
- Priority: 1
- Health Check: Enabled
- Monitor IP: 8.8.8.8, 1.1.1.1
- Ping Interval: 10s
- Failed Pings Before Failover: 3

Secondary WAN (LTE):
- Priority: 2 (backup only)
- Failback: Enabled
- Failback Delay: 120s
```

#### Step 3: Test Failover

```bash
# Method 1: Disconnect primary WAN cable
# Monitor: Settings → Internet → WAN should show failover

# Method 2: Simulate WAN failure via SSH
ssh root@172.16.0.1

# Bring down primary WAN interface temporarily
ip link set pppoe0 down

# Wait 30-60 seconds, verify traffic fails over to LTE

# Check routing table
ip route show
# Should show default via LTE interface

# Restore primary WAN
ip link set pppoe0 up

# Wait 120s (failback delay), verify return to primary
```

**Expected Failover Time**: 30-60 seconds

---

### Option 2: Secondary ISP (Best Reliability)

#### Hardware Required
- Second ISP connection (different provider than primary)
- Additional ONT/modem (provided by ISP)
- Ethernet cable to UDM-Pro WAN2 port
- Cost: ~$60-80/month

#### Step 1: Physical Installation

```bash
# 1. ISP installs second line and modem/ONT
# 2. Connect ISP modem/ONT to UDM-Pro port (eth9 or available port)
# 3. Note connection type from ISP (DHCP, PPPoE, Static)
```

#### Step 2: Configure Secondary WAN

**Via UniFi Controller**:
```
Settings → Internet → WAN Networks → Create New

Name: "WAN2-Backup-ISP"
Port: eth9 (or available port)

Connection Type: [As provided by ISP]
  - DHCP (most common)
  - PPPoE (enter username/password)
  - Static IP (enter IP, subnet, gateway, DNS)

Failover: Enabled
Priority: 2
Load Balancing: Disabled (or Weighted if desired)
```

#### Step 3: Configure Advanced Settings

```bash
# SSH to UDM-Pro
ssh root@172.16.0.1

# View WAN interfaces
ip addr show | grep -E "pppoe|eth"

# Configure policy-based routing (if needed)
# This ensures failover works correctly with multiple WANs
```

**Via UniFi Controller**:
```
Settings → Routing & Firewall → Firewall → Internet

# Ensure NAT/Masquerade enabled for both WANs
# UDM-Pro handles this automatically for failover
```

#### Step 4: Test Dual WAN

```bash
# Test 1: Verify both WANs online
# UniFi Controller → Dashboard
# Should show two WAN connections UP

# Test 2: Failover test
# Unplug primary WAN cable
# Wait 30-60s
# Test internet: curl -I https://google.com
# Should work via WAN2

# Test 3: Failback test
# Reconnect primary WAN
# Wait 2 minutes (failback delay)
# Verify traffic returns to primary WAN
```

---

### Option 3: Starlink (Satellite Backup)

#### Hardware Required
- Starlink kit ($599 hardware + $120/month)
- Power outlet
- Clear sky view for dish

#### Configuration

```
1. Set up Starlink per manufacturer instructions
2. Connect Starlink router's output to UDM-Pro WAN2 port
   (or set Starlink to bypass mode and connect directly)
3. Configure in UDM-Pro as DHCP WAN
4. Same failover config as Option 1/2
```

**Pros**: Works during ISP outages, independent infrastructure
**Cons**: Higher latency (20-40ms vs 10ms), expensive, requires installation

---

## Part B: MikroTik VRRP (Router High Availability)

**⚠️ Advanced Configuration** - Only implement after WAN redundancy

### Prerequisites

- [ ] Second MikroTik router (same model recommended)
- [ ] Direct connection between routers (dedicated VRRP sync)
- [ ] Understanding of VRRP (Virtual Router Redundancy Protocol)
- [ ] Planned maintenance window (2-3 hours)

---

### Architecture Overview

```
Current:
UDM-Pro (172.16.0.1) → MikroTik (172.16.0.2) → VLANs

New:
                    ┌─ MikroTik-1 (172.16.0.10) [Master, Priority 200]
UDM-Pro (172.16.0.1)─┤
                    └─ MikroTik-2 (172.16.0.11) [Backup, Priority 100]
                         ↓
                    VRRP VIP: 172.16.0.2 (virtual IP)
                         ↓
                       VLANs
```

**Key Concept**: Two routers, one virtual IP (172.16.0.2). Master handles traffic, backup takes over on failure.

---

### Step 1: Plan IP Addressing

```yaml
# Router 1 (Current/Master):
Physical IP: 172.16.0.10
VRRP Virtual IP: 172.16.0.2
VRRP Priority: 200 (master)

# Router 2 (New/Backup):
Physical IP: 172.16.0.11
VRRP Virtual IP: 172.16.0.2 (same)
VRRP Priority: 100 (backup)

# VRRP Configuration:
VRID: 1
Authentication: Strong password
Preemption: Enabled (master reclaims on recovery)
```

---

### Step 2: Prepare Second Router

**Physical Setup**:
```
1. Unbox second MikroTik router
2. Connect to management port
3. Default IP: 192.168.88.1
4. Access via browser or Winbox
```

**Initial Configuration**:
```bash
# Reset to defaults
/system reset-configuration no-defaults=yes

# Basic setup
/user add name=admin password="$ADMIN_PASSWORD" group=full
/ip service disable telnet,ftp,www
/ip service set ssh port=22

# Update RouterOS to match Router 1
/system package update check-for-updates
/system package update download
/system routerboard upgrade
/system reboot
```

---

### Step 3: Configure Router Physical IPs

**Router 1 (Current - become Master)**:
```bash
ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2

# Change bridge IP from 172.16.0.2 → 172.16.0.10
/ip address set [find address~"172.16.0.2"] address=172.16.0.10/24

# Verify
/ip address print where interface=bridge
# Should show: 172.16.0.10/24

# Update DNS, DHCP, etc. to reflect new IP
```

**Router 2 (New - become Backup)**:
```bash
ssh admin@192.168.88.1  # Initial connection

# Configure bridge with IP
/interface bridge add name=bridge
/ip address add address=172.16.0.11/24 interface=bridge network=172.16.0.0

# Set gateway
/ip route add gateway=172.16.0.1

# Verify connectivity
ping 172.16.0.1 count=3
```

---

### Step 4: Mirror Configuration to Router 2

**Export config from Router 1**:
```bash
# On Router 1
/export file=router1-config

# Download to local machine
# scp -i ~/.ssh/id_ed25519 admin@172.16.0.10:router1-config.rsc ./
```

**Adapt and import to Router 2**:
```bash
# Edit router1-config.rsc locally:
# - Change IP 172.16.0.10 → 172.16.0.11
# - Remove identity name (set unique)
# - Adjust any hardware-specific settings

# Upload to Router 2
# scp -i ~/.ssh/id_ed25519 router1-config-adapted.rsc admin@172.16.0.11:/

# Import on Router 2
ssh admin@172.16.0.11
/import file=router1-config-adapted.rsc
```

---

### Step 5: Configure VRRP on Both Routers

**Router 1 (Master)**:
```bash
ssh -i ~/.ssh/id_ed25519 admin@172.16.0.10

# Create VRRP interface
/interface vrrp add name=vrrp1 \
  interface=bridge \
  vrid=1 \
  priority=200 \
  interval=1 \
  authentication=ah auth-password="$AUTH_PASSWORD" \
  preemption-mode=yes \
  comment="VRRP Master"

# Assign virtual IP to VRRP interface
/ip address add address=172.16.0.2/24 interface=vrrp1 network=172.16.0.0

# Verify VRRP status
/interface vrrp print detail
# Should show: running=yes, master=yes
```

**Router 2 (Backup)**:
```bash
ssh -i ~/.ssh/id_ed25519 admin@172.16.0.11

# Create VRRP interface (same VRID, lower priority)
/interface vrrp add name=vrrp1 \
  interface=bridge \
  vrid=1 \
  priority=100 \
  interval=1 \
  authentication=ah auth-password="$AUTH_PASSWORD" \
  preemption-mode=yes \
  comment="VRRP Backup"

# Assign same virtual IP
/ip address add address=172.16.0.2/24 interface=vrrp1 network=172.16.0.0

# Verify VRRP status
/interface vrrp print detail
# Should show: running=yes, master=no (backup mode)
```

---

### Step 6: Configure VLAN Interfaces on Router 2

**Mirror VLAN configuration**:
```bash
# On Router 2
# Add bridge ports (match Router 1)
/interface bridge port add bridge=bridge interface=ether1 hw=yes
/interface bridge port add bridge=bridge interface=ether3 hw=yes
# ... (all physical ports)

# Create VLAN interfaces (match Router 1)
/interface vlan add name=vlan15-frontend vlan-id=15 interface=bridge
/interface vlan add name=vlan20-mgmt vlan-id=20 interface=bridge
/interface vlan add name=vlan25-workload vlan-id=25 interface=bridge
/interface vlan add name=vlan30-mgmt vlan-id=30 interface=bridge
/interface vlan add name=vlan40-vmotion vlan-id=40 interface=bridge mtu=9000
/interface vlan add name=vlan50-vsan vlan-id=50 interface=bridge mtu=9000
/interface vlan add name=vlan60-tep vlan-id=60 interface=bridge mtu=9000
/interface vlan add name=vlan70-uplink vlan-id=70 interface=bridge
/interface vlan add name=vlan77-iscsi vlan-id=77 interface=bridge mtu=9000

# Assign VLAN IPs (same as Router 1)
/ip address add address=172.16.15.1/24 interface=vlan15-frontend
/ip address add address=172.16.20.1/24 interface=vlan20-mgmt
/ip address add address=172.16.25.1/24 interface=vlan25-workload
/ip address add address=172.16.30.1/24 interface=vlan30-mgmt
/ip address add address=172.16.40.1/24 interface=vlan40-vmotion
/ip address add address=172.16.50.1/24 interface=vlan50-vsan
/ip address add address=172.16.60.1/24 interface=vlan60-tep
/ip address add address=172.16.70.1/24 interface=vlan70-uplink
/ip address add address=172.16.77.1/24 interface=vlan77-iscsi
```

---

### Step 7: Synchronize Firewall Rules

**Option A: Manual export/import** (shown above)

**Option B: Automatic config sync** (advanced):
```bash
# Use scheduler to periodically sync from master
/system scheduler add name=sync-from-master interval=1h \
  on-event="/tool fetch url=http://172.16.0.10/config.rsc; /import file=config.rsc"
```

---

### Step 8: Test VRRP Failover

**Test 1: Verify VRRP Status**
```bash
# Router 1
/interface vrrp print detail
# master=yes, priority=200

# Router 2
/interface vrrp print detail
# master=no, priority=100
```

**Test 2: Ping Virtual IP**
```bash
# From client (172.16.0.x)
ping 172.16.0.2 -t

# Should respond continuously (from Router 1)
```

**Test 3: Failover Test**
```bash
# On Router 1 - disable VRRP to simulate failure
/interface vrrp disable vrrp1

# Observe:
# - Router 2 VRRP becomes master within 3 seconds
# - Ping to 172.16.0.2 continues (1-2 lost packets)
# - Traffic flows through Router 2

# Verify on Router 2
/interface vrrp print detail
# master=yes (now master)
```

**Test 4: Failback Test**
```bash
# On Router 1 - re-enable VRRP
/interface vrrp enable vrrp1

# With preemption=yes:
# - Router 1 reclaims master role (higher priority)
# - Router 2 returns to backup
# - 1-2 lost pings during transition

# Verify on Router 1
/interface vrrp print detail
# master=yes (reclaimed)
```

---

### Step 9: Physical Cabling

**Recommended Setup**:
```
UDM-Pro eth1 → Router 1 ether1 (trunk)
UDM-Pro eth2 → Router 2 ether1 (trunk)

Router 1 ether3 → Switch Port 1 (trunk, VLANs)
Router 2 ether3 → Switch Port 2 (trunk, VLANs)

Router 1 ether10 ←→ Router 2 ether10 (direct link for VRRP sync)
```

---

## Monitoring and Maintenance

### UDM-Pro WAN Monitoring

```bash
# Check WAN status
ssh root@172.16.0.1

# View WAN interfaces
ip addr show | grep -E "pppoe|eth9"

# Monitor failover events
tail -f /var/log/messages | grep -i failover

# Check current default route
ip route show default
```

### MikroTik VRRP Monitoring

```bash
# Monitor VRRP state changes
/log print where topics~"vrrp"

# Watch VRRP status live
/interface vrrp monitor vrrp1

# Check which router is master
/interface vrrp print detail where master=yes
```

### Set Up Alerts

**UDM-Pro**:
```
Settings → Alerts → Configure

Enable:
- WAN Down
- WAN Failover
- Connection Tracking Full
```

**MikroTik**:
```bash
# Email on VRRP state change
/tool e-mail set server=smtp.gmail.com \
  from=mikrotik@mxe11.nl user=alert@mxe11.nl \
  password="$APP_PASSWORD"

/system script add name=vrrp-alert source={
  :local state [/interface vrrp get vrrp1 master]
  :if ($state=true) do={
    /tool e-mail send to=admin@mxe11.nl \
      subject="VRRP: Router became MASTER" \
      body="This router is now MASTER"
  }
}

/interface vrrp set vrrp1 on-backup="/system script run vrrp-alert"
/interface vrrp set vrrp1 on-master="/system script run vrrp-alert"
```

---

## Cost Summary

### Secondary WAN Options

| Option | Hardware Cost | Monthly Cost | Pros | Cons |
|--------|--------------|--------------|------|------|
| LTE/5G USB | $80 | $50 | Easy setup, mobile | Higher latency, data caps |
| Secondary ISP | $0-100 | $60-80 | Best reliability | Installation time, contract |
| Starlink | $599 | $120 | Independent infrastructure | Expensive, latency, installation |

### MikroTik VRRP

| Item | Cost |
|------|------|
| Second MikroTik router | $200-400 |
| Additional cables/transceivers | $50-100 |
| **Total** | **$250-500** |

---

## Rollback Procedures

### Revert WAN Configuration

```bash
# UDM-Pro
Settings → Internet → WAN2 → Delete

# Or via SSH
ssh root@172.16.0.1
ip link set [wan2-interface] down
```

### Revert VRRP Configuration

```bash
# Router 1 - Restore original IP
/interface vrrp disable vrrp1
/ip address set [find address~"172.16.0.10"] address=172.16.0.2/24
/interface vrrp remove vrrp1

# Router 2 - Power off or remove from network
```

---

## Success Criteria

### Secondary WAN
- [ ] Both WANs show "Connected" in UniFi Controller
- [ ] Failover occurs within 60 seconds of WAN1 failure
- [ ] Internet connectivity maintained during failover
- [ ] Failback to primary WAN occurs after restoration
- [ ] No user intervention required

### VRRP
- [ ] Virtual IP 172.16.0.2 responds continuously
- [ ] Failover completes within 3 seconds
- [ ] Maximum 1-2 lost pings during failover
- [ ] Master router automatically reclaims role (preemption)
- [ ] Both routers maintain synchronized configuration

---

## Next Steps

1. **Start with Secondary WAN** (easier, immediate value)
2. **Monitor for 2 weeks** (validate failover works)
3. **Then consider VRRP** (if router redundancy needed)
4. **Update documentation** after each phase

---

**Document Version**: 1.0
**Last Updated**: 2025-10-06
**Tested On**: UDM-Pro (3.x firmware), MikroTik RouterOS 7.x
