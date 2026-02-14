# API Examples

Base URL (local): `http://127.0.0.1:8000`

## 1) Create Session
```bash
curl -X POST http://127.0.0.1:8000/api/sessions/ \
  -H "Content-Type: application/json" \
  -d '{
    "course_code": "TEL401",
    "course_title": "Telecommunication Systems",
    "lecturer_name": "Dr. Adebayo",
    "room": "Hall A",
    "starts_at": "2026-02-14T08:00:00Z",
    "token_version": "v1"
  }'
```

## 2) Submit Attendance Proof
```bash
curl -X POST http://127.0.0.1:8000/api/attendance/ \
  -H "Content-Type: application/json" \
  -d '{
    "session": 1,
    "student_id": "21/52HP071",
    "device_id": "android-7f4c2c45-8d4d-4a8c-bbb9-0f1f06f79c0f",
    "acoustic_token": "ac_2026_02_14_0800_7ff1",
    "ble_nonce": "ble_2026_02_14_0800_a91d",
    "rssi": -63,
    "observed_at": "2026-02-14T08:01:14Z",
    "signature": "base64orhexsignaturevalue"
  }'
```

## 3) List Sessions
```bash
curl http://127.0.0.1:8000/api/sessions/
```

## 4) Retrieve One Session
```bash
curl http://127.0.0.1:8000/api/sessions/1/
```
