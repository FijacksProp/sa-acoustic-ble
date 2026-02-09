# Architecture Diagram

```mermaid
flowchart LR
  subgraph Lecturer App (Flutter)
    L1[Start Session]
    L2[Broadcast Ultrasonic Beacon]
    L3[Advertise BLE Nonce]
  end

  subgraph Student App (Flutter)
    S1[Listen + Decode Acoustic Token]
    S2[Scan BLE + Capture RSSI]
    S3[Validate Time Window + Thresholds]
    S4[Generate Proof + Sign]
    S5[Store Offline]
    S6[Sync When Online]
  end

  subgraph Backend (Django + Postgres)
    B1[Verify Signature + Freshness]
    B2[Store Attendance]
    B3[Anomaly Checks]
  end

  subgraph Lecturer Dashboard
    D1[Live Attendance]
    D2[Session Reports]
    D3[Export CSV]
  end

  L1 --> L2 --> L3
  L2 --> S1
  L3 --> S2
  S1 --> S3
  S2 --> S3
  S3 --> S4 --> S5 --> S6 --> B1 --> B2 --> B3 --> D1 --> D2 --> D3
```
