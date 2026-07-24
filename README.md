# Smart Attendance System

Design and Implementation of a Smart Attendance System Using Acoustic and
Bluetooth Low Energy Proximity Verification.

This final-year project combines a Flutter Android application, native Kotlin
signal processing, and a hosted Django REST API. Lecturers open a timed
attendance session and broadcast rotating acoustic and BLE evidence. Students
scan the classroom signals and submit one authenticated proof from their
registered device. A fixed BLE room beacon can also resolve an open session for
larger classrooms.

## Current Architecture

- **Lecturer phone:** creates a session and broadcasts rotating acoustic and BLE
  payloads.
- **Room beacon:** advertises a fixed iBeacon or Eddystone UID assigned to a
  registered classroom.
- **Student phone:** scans acoustic, lecturer BLE, and room-beacon evidence.
- **Django API:** authenticates users, resolves beacon rooms, validates proof
  freshness, enforces device ownership, and prevents duplicate attendance.
- **PostgreSQL:** stores hosted production data; local development falls back to
  SQLite.

BLE is the principal classroom-range mechanism in the present implementation.
The acoustic path works as a short-range co-presence channel and remains
sensitive to noise and phone audio hardware. Wi-Fi/LAN and face verification
were evaluated during prototyping but are not active attendance paths.

## Implemented Features

- Student and lecturer registration and token-authenticated login
- Persistent one-student-to-one-device binding
- Lecturer-owned session creation, room selection, opening, closing, and deletion
- Fifteen-minute attendance windows with automatic server-side expiry
- Android foreground acoustic and BLE broadcast with 45-second signal rotation
- Broadcast continuity during in-app navigation and screen lock
- Concurrent acoustic and BLE scanning on student devices
- CP27-compatible iBeacon and Eddystone UID room-beacon detection
- RSSI-aware selection between lecturer BLE and room-beacon evidence
- Session, freshness, room, identity, proof-integrity, and duplicate checks
- Student attendance history
- Lecturer live-session search, session-specific reports, and CSV export
- Django admin views for sessions, proofs, beacons, users, and device resets
- Friendly mobile error and permission messages

## Repository Layout

```text
backend/                    Django REST API and deployment configuration
mobile/app/                 Flutter application and Android Kotlin integrations
docs/fyp/                   Project report chapters, sources, and report builders
docs/presentation_readiness Seminar, room, beacon, and cost notes
docs/                       Architecture, payload, API, and security notes
```

## Hosted Service

The mobile app defaults to:

```text
https://sa-acoustic-ble.onrender.com
```

Health check:

```text
https://sa-acoustic-ble.onrender.com/api/health/
```

Render free-tier services may need a short cold-start period after inactivity.
The mobile client allows up to 75 seconds for hosted API requests.

## Backend Development

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

Run backend checks and tests:

```powershell
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test attendance
```

For phone testing against a local server, use `0.0.0.0:8000`, allow port 8000
through Windows Firewall, and build the app with the laptop's current LAN
address. Hosted builds do not require this.

## Mobile Development

```powershell
cd mobile\app
flutter pub get
flutter run -d <device-id>
```

To test against a local backend:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<laptop-ip>:8000
```

Run focused mobile tests:

```powershell
flutter test --no-pub
```

## Build the Android APK

Debug APK:

```powershell
cd mobile\app
flutter build apk --debug
```

Release APK:

```powershell
flutter build apk --release
```

Generated files:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

The current release build uses the debug signing configuration for project
testing. A private release keystore is required before public distribution.

## Android Permissions

- **Microphone:** acoustic attendance scanning
- **Nearby Devices / Bluetooth:** BLE scanning and lecturer advertising
- **Location:** reliable BLE discovery on supported Android versions
- **Foreground service:** continued lecturer broadcast while the screen is locked

The application prompts for the required scan or broadcast permissions at the
point of use. Bluetooth must be enabled on the participating phones.

## Attendance Workflow

### Lecturer

1. Sign in with a lecturer account.
2. Create a session using the course and classroom details.
3. Open attendance when students are physically present.
4. Keep the app running; the Android foreground service continues broadcasting
   across app pages and while the screen is locked.
5. Close attendance, review submissions, and export the session CSV.

### Student

1. Sign in on the device registered to the account.
2. Keep Bluetooth, Location, and Microphone permissions enabled.
3. Run one classroom signal scan.
4. Review the identified session and detected proof mode.
5. Submit attendance once and confirm it in History.

## Validation Rules

The API enforces:

- authenticated role and account ownership
- lecturer ownership of session changes
- one open attendance session per registered room
- effective attendance-window expiry
- one attendance record per student per session
- persistent device ownership and cross-account device conflicts
- signal format, session identity, and 60-second acoustic/BLE freshness
- registered beacon identity, room assignment, and minimum RSSI
- proof digest consistency
- student-scoped replay records that still allow every student to use the same
  classroom broadcast nonce

Device ID binding discourages casual account sharing but is not equivalent to
tamper-resistant hardware attestation. Administrative device reset and stronger
institutional identity controls would be required for production deployment.

## Deployment and Documentation

- Render and Supabase setup: `docs/RENDER_SUPABASE_DEPLOYMENT.md`
- Architecture: `docs/ARCHITECTURE.md`
- Anti-fraud rules: `docs/ANTI_FRAUD_DEVICE_RULES.md`
- FYP chapters: `docs/fyp/CHAPTER_ONE.md` through
  `docs/fyp/CHAPTER_FIVE.md`

## Project Scope

The current build is an Android research prototype validated on a limited set of
real devices. iOS would require a macOS/Xcode build environment and separate
native acoustic/BLE implementation and testing. Institutional deployment would
also require a privacy policy, secure release signing, device-reset governance,
broader classroom trials, and independent security review.
