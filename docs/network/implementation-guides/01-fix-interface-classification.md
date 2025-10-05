# Implementation Guide: Fix MikroTik Interface Classification

## Overview

**Issue**: ether1 (172.16.0.2) facing UDM-Pro is classified as WAN, treating trusted main network traffic as "external"

**Fix**: Reclassify ether1 as LAN interface

**Duration**: 15-20 minutes

**Risk Level**: Medium (requires firewall rule adjustments)

---

## Pre-Implementation Checklist

- [ ] Backup MikroTik configuration
- [ ] Verify SSH access: `ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2`
- [ ] Identify current interface list assignments
- [ ] Document current firewall rules
- [ ] Schedule maintenance window (brief connectivity interruption possible)
- [ ] Have console access ready (fallback if SSH fails)

---

## Step 1: Backup Current Configuration

```bash
# Connect to MikroTik
ssh -i ~/.ssh/id_ed25519 admin@172.16.0.2

# Create backup with timestamp
/export file=backup-pre-interface-fix-$(date +%Y%m%d-%H%M)

# Verify backup created
/file print where name~"backup-pre-interface"

# Optional: Download backup to local machine
# Exit SSH, then run:
# scp -i ~/.ssh/id_ed25519 admin@172.16.0.2:backup-pre-interface-*.rsc ./backups/
```

**Expected Output**:
```
# Backup file created: backup-pre-interface-fix-20251006-1430.rsc
```

---

## Step 2: Review Current Interface Lists

```bash
# View all interface list assignments
/interface list member print

# Should show something like:
# 0  WAN     ether1
# 1  LAN     vlan15-frontend
# 2  LAN     vlan20-mgmt
# ... (other VLANs)
```

**Note the ID number** of ether1's WAN assignment (likely `0`)

---

## Step 3: Review Current Firewall Rules

```bash
# View forward chain rules that reference interface lists
/ip firewall filter print where (in-interface-list~"WAN" or out-interface-list~"WAN")

# Key rules to note:
# - Rule accepting LAN → WAN
# - Rule dropping WAN → LAN
# - Rule #31 (our workaround for main network → VLAN30)
```

**Important**: Document any custom rules using WAN interface list

---

## Step 4: Remove ether1 from WAN List

```bash
# Find the specific member ID
/interface list member print where interface=ether1 and list=WAN

# Remove ether1 from WAN list (adjust ID if different)
/interface list member remove [find interface=ether1 and list=WAN]

# Verify removal
/interface list member print where interface=ether1
# Should show NO WAN assignment now
```

**Expected Output**:
```
# ether1 no longer in WAN list
```

---

## Step 5: Add ether1 to LAN List

```bash
# Add ether1 to LAN interface list
/interface list member add interface=ether1 list=LAN

# Verify addition
/interface list member print where interface=ether1
# Should show: ether1 → LAN
```

**Expected Output**:
```
# ether1 now in LAN list
```

---

## Step 6: Remove Workaround Firewall Rule #31

```bash
# Find rule #31 (the workaround we added)
/ip firewall filter print where comment~"Allow main network to VLAN30"

# View the rule details
/ip firewall filter print detail where comment~"Allow main network to VLAN30"

# Remove rule #31 (it's no longer needed)
/ip firewall filter remove [find comment~"Allow main network to VLAN30"]

# Verify removal
/ip firewall filter print | grep "main network"
# Should return nothing
```

**Rationale**: With ether1 now in LAN list, traffic from 172.16.0.0/24 → 172.16.30.0/24 is LAN→LAN, not WAN→LAN, so it's automatically allowed.

---

## Step 7: Verify Firewall Rule Logic

```bash
# Review forward chain rules
/ip firewall filter print chain=forward

# Key rules should now work correctly:
# - Accept established/related (rule 0)
# - Accept LAN → LAN (now includes ether1 → VLANs)
# - Drop WAN → LAN (no longer affects ether1)
```

**Expected Behavior**:
- Traffic from 172.16.0.0/24 → all VLANs: ✅ Allowed (LAN→LAN)
- Traffic from VLANs → 172.16.0.0/24: ✅ Allowed (LAN→LAN)
- No special workaround rules needed

---

## Step 8: Test Connectivity

### Test 1: Main Network to vCenter
```bash
# From your workstation (172.16.0.x)
ping -c 3 172.16.30.100

# Expected: 0% packet loss, <5ms latency
```

### Test 2: Main Network to All VLANs
```bash
# Test each VLAN gateway
ping -c 2 172.16.15.1  # Frontend
ping -c 2 172.16.20.1  # Management
ping -c 2 172.16.25.1  # Workload
ping -c 2 172.16.30.1  # FS Management
ping -c 2 172.16.40.1  # vMotion
ping -c 2 172.16.50.1  # vSAN
ping -c 2 172.16.60.1  # NSX TEP
ping -c 2 172.16.70.1  # Uplink
ping -c 2 172.16.77.1  # iSCSI

# All should respond successfully
```

### Test 3: vCenter Web Access
```bash
# From browser
https://vc01.fs.corp.mxe11.nl
https://172.16.30.100

# Should load without issues
```

### Test 4: Check MikroTik Firewall Logs
```bash
# On MikroTik
/log print where topics~"firewall"

# Should NOT show any drops for 172.16.0.0/24 → 172.16.30.0/24
```

---

## Step 9: Monitor for 24 Hours

After implementation, monitor these metrics:

```bash
# Connection tracking
/ip firewall connection print count-only

# Firewall statistics (check drop counters)
/ip firewall filter print stats

# Interface traffic
/interface monitor-traffic ether1 once
/interface monitor-traffic vlan30-mgmt once
```

**What to Look For**:
- No unexpected drops in firewall statistics
- Normal traffic patterns on ether1 and VLANs
- Connection tracking remains stable

---

## Rollback Procedure

**If issues occur, rollback immediately:**

```bash
# Method 1: Restore from backup
/import file=backup-pre-interface-fix-20251006-1430.rsc

# Method 2: Manual rollback
# Remove ether1 from LAN
/interface list member remove [find interface=ether1 and list=LAN]

# Re-add to WAN
/interface list member add interface=ether1 list=WAN

# Re-add rule #31
/ip firewall filter add chain=forward action=accept \
  src-address=172.16.0.0/24 dst-address=172.16.30.0/24 \
  place-before=2 comment="Allow main network to VLAN30"
```

**Verify rollback**:
```bash
/interface list member print where interface=ether1
# Should show: ether1 → WAN

/ip firewall filter print where comment~"Allow main network"
# Should show rule #31 restored
```

---

## Post-Implementation Tasks

- [ ] Update network documentation (firewall.md, topology.md)
- [ ] Remove old rule #31 references from docs
- [ ] Document new interface classification
- [ ] Archive backup file
- [ ] Notify team of changes

---

## Benefits Achieved

✅ **Simplified Security Model**
- ether1 now correctly represents trusted internal connection
- No mental model mismatch between physical reality and firewall logic

✅ **Reduced Rule Complexity**
- Eliminated workaround rule #31
- Natural LAN→LAN traffic flow
- Easier to understand and maintain

✅ **Better Troubleshooting**
- Clear interface classifications
- Firewall logs make more sense
- Faster problem diagnosis

---

## Verification Checklist

- [ ] ether1 in LAN interface list
- [ ] ether1 NOT in WAN interface list
- [ ] Rule #31 removed
- [ ] Connectivity to 172.16.30.0/24 working
- [ ] Connectivity to all other VLANs working
- [ ] No firewall drops for legitimate traffic
- [ ] vCenter accessible via browser
- [ ] SSH access to MikroTik still works
- [ ] Documentation updated

---

## Expected Timeline

| Task | Duration |
|------|----------|
| Backup configuration | 2 min |
| Review current setup | 3 min |
| Change interface lists | 2 min |
| Remove rule #31 | 1 min |
| Test connectivity | 5 min |
| Monitor | 2 min |
| **Total** | **15 min** |

---

## Troubleshooting

### Issue: Cannot ping VLANs after change

**Diagnosis**:
```bash
/ip firewall filter print stats
# Check for high drop counters
```

**Fix**: Verify LAN→LAN accept rule exists
```bash
/ip firewall filter print where action=accept and in-interface-list=LAN
```

### Issue: SSH to MikroTik fails after change

**Fix**: Use console access
1. Connect serial cable to MikroTik
2. Login via console
3. Run rollback procedure

### Issue: Firewall logs show drops

**Fix**: Add temporary rule at top
```bash
/ip firewall filter add chain=forward action=accept \
  in-interface=ether1 place-before=0 comment="TEMP: Debug ether1"
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-06
**Tested On**: MikroTik RouterOS 7.x
