# TODO - Smart Attendance System (Acoustic + BLE)

## Scope
- Cross-platform app (Android first, iOS later)
- Two-signal presence verification: Acoustic + BLE
- Offline-first attendance proof
- Backend validation + lecturer dashboard

## Success Metrics
- Acoustic decode success rate >= 90% within 20m
- BLE detection success rate >= 95% within 10m
- Combined acceptance rate >= 85% in real classroom
- Attendance per student <= 10 seconds

## Phase 0 - Proposal (Feb 10-28, 2026)
- [ ] Finalize project title and scope
- [ ] Write problem statement and objectives
- [x] Create system architecture diagram
- [ ] Define evaluation metrics and data collection plan
- [ ] Submit proposal

## Phase 1 - Foundations (Weeks 1-2)
- [x] Initialize monorepo structure
- [x] Create Flutter app shell (lecturer + student roles)
- [x] Create Django backend skeleton
- [x] Define database schema (users, sessions, attendance)
- [x] Define proof format JSON
- [x] Create API endpoints: POST /sessions, POST /attendance, GET /sessions/:id
- [x] Create basic login flow (registration + login with role)

## Integration Progress (Current)
- [x] Lecturer Live page loads sessions from backend API
- [x] Student History page loads attendance proofs from backend API
- [x] Loading, empty, and error states added to Live and History pages
- [x] Backend `/api/attendance/` supports list + create with filters (`session`, `student_id`)
- [x] Added acoustic platform channel skeleton (Flutter to Android, mock response)
- [x] Added scan result domain model for sensor output contract
- [x] Added BLE scan service (real scan + fallback)
- [x] Student scan flow now fills BLE nonce/RSSI from scan (manual BLE fields removed)
- [x] Added role-based registration/login using matric number and auth token
- [x] Removed manual student_id input; student identity now uses authenticated session
- [x] Added automatic persistent device ID for proof submission
- [x] Added automatic proof signature generation (sha256 payload hash)
- [x] Defined signal payload spec (`docs/signal_payload.md`) with 60s expiry
- [x] Added lecturer Start Broadcast flow with rotating mock acoustic/BLE payloads
- [x] Student scan now decodes payload and auto-fills session_id, acoustic_token, ble_nonce, rssi
- [x] Added scan result card with decoded session, signal age, and pass/fail checks
- [x] Hardened backend proof validation for payload format, expiry, and session consistency

## Phase 2 - Acoustic Beacon (Weeks 3-4)
- [ ] Implement Android beacon transmitter (FSK ultrasonic)
- [ ] Implement Android beacon decoder
- [ ] Add bandpass filter for 18-20 kHz
- [ ] Decode rotating token and timestamp
- [ ] Basic UI: start session, show token
- [ ] Field test with Bluetooth speaker
- [ ] Log decode success vs distance

## Phase 3 - BLE Proximity (Weeks 5-6)
- [ ] Implement BLE advertiser in lecturer app
- [ ] Implement BLE scanner in student app
- [ ] Capture RSSI and nonce data
- [ ] Set initial RSSI threshold
- [ ] Validate time window (nonce rotation)
- [ ] Field test BLE detection and RSSI distribution

## Phase 4 - Proof + Offline Sync (Week 7)
- [ ] Generate proof hash (session_id, token, nonce, timestamp, device_id)
- [ ] Sign proof locally
- [ ] Store proofs offline
- [ ] Sync when online

## Phase 5 - Backend Validation (Week 8)
- [ ] Verify timestamps and token freshness
- [ ] Verify signature
- [ ] Store attendance record
- [ ] Prevent duplicate attendance per session

## Phase 6 - Lecturer Dashboard (Week 9)
- [ ] Live attendance count
- [ ] Attendance list with timestamps
- [ ] Export CSV

## Phase 7 - Evaluation + Tuning (Weeks 10-11)
- [ ] Pilot test in 1-2 classrooms
- [ ] Capture metrics: decode rate, BLE success, time per student
- [ ] Tune frequency band and RSSI thresholds
- [ ] Update report with results

## Phase 8 - Finalization (Week 12)
- [ ] Final report (architecture, methods, results)
- [ ] Presentation slides
- [ ] Demo video
- [ ] Code cleanup and release

## Stretch Goals (If Time)
- [ ] iOS acoustic beacon prototype
- [ ] BLE clustering anomaly detection
- [ ] Simple motion biometric challenge
