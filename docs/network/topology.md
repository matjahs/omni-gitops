# Network Topology

## Physical Network Diagram

```mermaid
graph TB
    Internet((Internet<br/>ISP)) -->|PPPoE<br/>77.165.76.73| WAN[UDM-Pro WAN<br/>eth8]

    WAN --> UDM[UniFi Dream Machine Pro<br/>172.16.0.1]

    UDM -->|VLAN 1<br/>Main LAN| LAN[br0: 172.16.0.1/24]
    UDM -->|VLAN 2| VLAN2[br2: 10.5.0.1/24]
    UDM -->|VLAN 11| VLAN11[br11: 172.16.251.1/24]
    UDM -->|VLAN 12| VLAN12[br12: 192.168.30.1/24]
    UDM -->|VLAN 13| VLAN13[br13: 172.16.13.1/24]

    LAN -->|Connected to<br/>172.16.0.2| MIKROTIK[MikroTik RouterOS<br/>router.lab.mxe11.nl]

    MIKROTIK -->|VLAN 15| VLAN15[172.16.15.0/24<br/>Frontend]
    MIKROTIK -->|VLAN 20| VLAN20[172.16.20.0/24<br/>Management]
    MIKROTIK -->|VLAN 25| VLAN25[172.16.25.0/24<br/>Workload]
    MIKROTIK -->|VLAN 30| VLAN30[172.16.30.0/24<br/>FS Management]
    MIKROTIK -->|VLAN 40| VLAN40[172.16.40.0/24<br/>vMotion]
    MIKROTIK -->|VLAN 50| VLAN50[172.16.50.0/24<br/>vSAN]
    MIKROTIK -->|VLAN 60| VLAN60[172.16.60.0/24<br/>TEP/NSX]
    MIKROTIK -->|VLAN 70| VLAN70[172.16.70.0/24<br/>Uplink]
    MIKROTIK -->|VLAN 77| VLAN77[172.16.77.0/24<br/>iSCSI]

    VLAN20 --> VMWARE[VMware Infrastructure]
    VLAN30 --> VCENTER[vCenter<br/>vc01.fs.corp.mxe11.nl<br/>172.16.30.100]
    VLAN50 --> VSAN[vSAN Cluster]
    VLAN77 --> ISCSI[Synology NAS<br/>172.16.0.189]

    UDM -->|Honeypot| HONEY[10.5.0.4<br/>Security Monitoring]

    style Internet fill:#e1f5fe
    style UDM fill:#c8e6c9
    style MIKROTIK fill:#fff9c4
    style VMWARE fill:#f3e5f5
    style VCENTER fill:#ffe0b2
    style HONEY fill:#ffccbc
```

## Logical Network Flow

```mermaid
flowchart LR
    A[Client<br/>172.16.0.0/24] -->|Route via<br/>172.16.0.2| B{MikroTik<br/>Router}
    B -->|VLAN 20| C[VMware Mgmt<br/>172.16.20.0/24]
    B -->|VLAN 30| D[vCenter/FS<br/>172.16.30.0/24]
    B -->|VLAN 40| E[vMotion<br/>172.16.40.0/24]
    B -->|VLAN 50| F[vSAN<br/>172.16.50.0/24]
    B -->|VLAN 77| G[iSCSI<br/>172.16.77.0/24]

    C <-->|VM Mgmt| D
    E <-->|Migration| C
    F <-->|Storage| C
    G <-->|Block Storage| C

    style A fill:#e3f2fd
    style B fill:#fff9c4
    style C fill:#f3e5f5
    style D fill:#ffe0b2
    style E fill:#e1f5fe
    style F fill:#f1f8e9
    style G fill:#fce4ec
```

## VLAN Bridge Architecture (MikroTik)

```mermaid
graph TB
    subgraph MikroTik["MikroTik Router (172.16.0.2)"]
        BRIDGE[Bridge<br/>172.16.0.2/24]

        BRIDGE -->|Tagged| ETH1[ether1<br/>Uplink]
        BRIDGE -->|Tagged| ETH3[ether3<br/>Red]
        BRIDGE -->|Tagged| ETH4[ether4<br/>Black]
        BRIDGE -->|Tagged| ETH5[ether5<br/>Port 5]
        BRIDGE -->|Tagged| ETH8[ether8<br/>Yellow]

        VLAN15[VLAN 15<br/>Frontend] -.-> BRIDGE
        VLAN20[VLAN 20<br/>Management] -.-> BRIDGE
        VLAN25[VLAN 25<br/>Workload] -.-> BRIDGE
        VLAN30[VLAN 30<br/>FS Mgmt] -.-> BRIDGE
        VLAN40[VLAN 40<br/>vMotion] -.-> BRIDGE
        VLAN50[VLAN 50<br/>vSAN] -.-> BRIDGE
        VLAN60[VLAN 60<br/>TEP] -.-> BRIDGE
        VLAN70[VLAN 70<br/>Uplink] -.-> BRIDGE
        VLAN77[VLAN 77<br/>iSCSI] -.-> BRIDGE
    end

    style BRIDGE fill:#fff9c4
    style ETH1 fill:#c8e6c9
    style VLAN20 fill:#f3e5f5
    style VLAN30 fill:#ffe0b2
```

## Traffic Flow Examples

### 1. Client to vCenter Access

```mermaid
sequenceDiagram
    participant Client as Client<br/>172.16.0.199
    participant UDM as UDM-Pro<br/>172.16.0.1
    participant MikroTik as MikroTik<br/>172.16.0.2
    participant vCenter as vCenter<br/>172.16.30.100

    Client->>UDM: Request to 172.16.30.100
    UDM->>UDM: Check route table
    UDM->>MikroTik: Forward to 172.16.0.2
    MikroTik->>MikroTik: Check firewall rules
    MikroTik->>vCenter: Route to VLAN 30
    vCenter->>MikroTik: Response
    MikroTik->>UDM: Forward response
    UDM->>Client: Deliver response
```

### 2. VMware vMotion Traffic

```mermaid
sequenceDiagram
    participant ESXi1 as ESXi Host 1<br/>VLAN 40
    participant MikroTik as MikroTik Router
    participant ESXi2 as ESXi Host 2<br/>VLAN 40

    ESXi1->>MikroTik: vMotion traffic<br/>Port 8000
    MikroTik->>MikroTik: Check firewall<br/>(Allow VLAN40→VLAN20)
    MikroTik->>ESXi2: Forward vMotion
    ESXi2->>MikroTik: ACK
    MikroTik->>ESXi1: Response
```

### 3. iSCSI Storage Access

```mermaid
sequenceDiagram
    participant ESXi as ESXi Host<br/>VLAN 77
    participant MikroTik as MikroTik Router
    participant Synology as Synology NAS<br/>172.16.0.189

    ESXi->>MikroTik: iSCSI request<br/>Port 3260
    MikroTik->>MikroTik: Firewall rule:<br/>VLAN77→172.16.0.0/24
    MikroTik->>Synology: Forward to target
    Synology->>MikroTik: iSCSI response
    MikroTik->>ESXi: Deliver data
```

## Port Connectivity Matrix

| Port | Interface | Link Status | Speed | VLANs Tagged | Purpose |
|------|-----------|-------------|-------|--------------|---------|
| eth1 | ether1 | UP | 9216 MTU | 15,20,25,30,40,50,60,70,77 | Uplink |
| eth3 | ether3 | UP | 9216 MTU | 15,20,25,30,40,50,60,70,77 | Red |
| eth4 | ether4 | UP | 9216 MTU | 15,20,25,30,40,50,60,70,77 | Black |
| eth5 | ether5 | UP | 9216 MTU | 15,20,25,30,40,50,60,70,77 | Port 5 |
| eth8 | ether8 | UP | 9216 MTU | 15,20,25,30,40,50,60,70,77 | Yellow |
| SFP+ 1 | sfp-sfpplus1 | UP | 9216 MTU | Tagged only | Fiber uplink |
| SFP+ 2 | sfp-sfpplus2 | UP | 9216 MTU | VLAN 77 (PVID) | iSCSI dedicated |

## Network Metrics

### UDM-Pro Statistics
- **Uptime**: 23+ days
- **WAN Traffic**: 1.0 TiB RX / 253.8 GiB TX
- **Connection Tracking**: 2,925 / 65,536 (4.5%)
- **Active TCP**: 124 established connections
- **ARP Entries**: 667 total, 28 reachable

### MikroTik Statistics
- **VLAN 30 Traffic**: 487 MB RX / 112 GB TX
- **Bridge VLAN Filtering**: Enabled
- **Hardware Offload**: Active on all ports
