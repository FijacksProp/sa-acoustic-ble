# Proof Payload Contract

## Endpoint
- `POST /api/attendance/`

## Required Fields
- `session`: integer, existing session ID.
- `student_id`: string, non-empty, trimmed.
- `device_id`: string, non-empty, trimmed.
- `acoustic_token`: string, non-empty, trimmed.
- `ble_nonce`: string, non-empty, trimmed.
- `rssi`: integer, expected BLE signal strength (typically negative dBm).
- `observed_at`: ISO-8601 datetime in UTC or timezone-aware format.
- `signature`: string, non-empty, trimmed.

## Validation Rules
- `observed_at` freshness window:
- Must be within `120` seconds in the past from server time.
- Can be at most `10` seconds in the future to tolerate small clock skew.
- Duplicate policy:
- One attendance proof per `session + student_id`.
- Empty strings rejected for:
- `student_id`, `device_id`, `acoustic_token`, `ble_nonce`, `signature`.

## JSON Example
```json
{
  "session": 1,
  "student_id": "21/52HP071",
  "device_id": "android-7f4c2c45-8d4d-4a8c-bbb9-0f1f06f79c0f",
  "acoustic_token": "ac_2026_02_14_0800_7ff1",
  "ble_nonce": "ble_2026_02_14_0800_a91d",
  "rssi": -63,
  "observed_at": "2026-02-14T08:01:14Z",
  "signature": "base64orhexsignaturevalue"
}
```
