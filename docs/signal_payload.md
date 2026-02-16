# Signal Payload Specification

This document defines the mock signal payload format used between lecturer broadcast and student scan.

## Expiry Window
- Payload validity window: `60 seconds`.
- Student app should reject payloads older than this window.

## Acoustic Payload
Fields:
- `session_id`: integer
- `token_version`: string
- `challenge_token`: string
- `issued_at`: ISO-8601 UTC timestamp

Example:
```json
{
  "session_id": 12,
  "token_version": "v1",
  "challenge_token": "ac_n2g9b1xk0w4f",
  "issued_at": "2026-02-16T10:30:00Z"
}
```

## BLE Payload
Fields:
- `session_id`: integer
- `ble_nonce`: string
- `issued_at`: ISO-8601 UTC timestamp

Example:
```json
{
  "session_id": 12,
  "ble_nonce": "ble_c9m2q0v8r7k1",
  "issued_at": "2026-02-16T10:30:00Z"
}
```

## Rotation Behavior
- Lecturer rotates `challenge_token` and `ble_nonce` every `60 seconds`.
- `issued_at` is refreshed on each rotation.
- `session_id` remains fixed for the active session.
