# Smart Attendance System Using Acoustic and BLE Proximity Verification

Design and Implementation of a Smart Attendance System Using Acoustic and Bluetooth Low Energy Proximity Verification.

This project is a final-year project prototype for classroom attendance verification. It combines a Flutter Android mobile app, a Django REST backend, native Android acoustic signal processing, BLE advertising/scanning, device binding, validation reporting, CSV export, and a minimal Wi-Fi/LAN fallback proof path.

## Project Direction

The system is designed around layered attendance proof:

- BLE is the main practical classroom-range proximity signal.
- Acoustic beaconing is a short-range copresence signal using the lecturer phone speaker and student phone microphone.
- Wi-Fi/LAN proof is a secondary fallback for controlled local-network situations, not the main proximity technology.
- Device ID binding reduces account-sharing fraud by linking one student account to one trusted device.
- The backend performs final validation so the mobile app is not trusted alone.

## Current Status

Implemented:

- Student and lecturer registration/login.
- Lecturer session creation, live session management, and session deletion.
- Acoustic broadcast and microphone scan on Android.
- BLE advertising and BLE scan on Android.
- Runtime permission prompts for microphone, location, and nearby devices/Bluetooth.
- Wi-Fi/LAN fallback proof for same-network testing.
- Attendance proof submission with duplicate prevention.
- Device ID binding and device-trust validation.
- Lecturer validation report filtered by selected/current session.
- CSV export for attendance records.
- Runtime backend URL setting inside the app.
- FYP documentation drafts for Chapters 1-3.

Known limitations:

- Acoustic decoding is currently short-range and affected by noise, speaker quality, microphone quality, and phone orientation.
- BLE range depends on permissions, Bluetooth hardware, obstacles, and room conditions.
- Wi-Fi/LAN fallback proves local network presence, not exact classroom distance.
- iOS is not supported yet because the native acoustic and BLE implementation is currently Android/Kotlin-based.

## Repository Structure

```text
sa-acoustic-ble/
  backend/                    Django REST API and SQLite database
  mobile/app/                 Flutter app with Android native integrations
  docs/fyp/                   Formal FYP chapters, references, and source notes
  docs/presentation_readiness Practical seminar/demo notes
  docs/                       Setup and handoff documentation
```

## Technology Stack

| Layer | Technology |
| --- | --- |
| Mobile app | Flutter / Dart |
| Android native layer | Kotlin |
| BLE scan/advertise | Android Bluetooth APIs and flutter_blue_plus |
| Acoustic signal | Android native speaker/microphone processing |
| Backend | Django and Django REST Framework |
| Authentication | DRF token authentication |
| Database | SQLite locally, PostgreSQL/Supabase for hosted deployment |
| Version control | Git and GitHub |

## Backend Setup

From the project root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Use `0.0.0.0:8000` when testing with real phones on the same Wi-Fi/hotspot.

For local browser testing on the same PC:

```powershell
python manage.py runserver 127.0.0.1:8000
```

For the hosted Render + Supabase setup, see:

```text
docs/RENDER_SUPABASE_DEPLOYMENT.md
```

## Mobile App Setup

From the Flutter app folder:

```powershell
cd mobile\app
flutter pub get
```

Run on Chrome or Edge for UI-level testing:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Run on a connected Android phone:

```powershell
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Example:

```powershell
flutter run -d 23106RN0DA --dart-define=API_BASE_URL=http://10.73.208.158:8000
```

## Build APK for Wireless Testing

Start the backend first:

```powershell
cd backend
python manage.py runserver 0.0.0.0:8000
```

Find the laptop IP:

```powershell
ipconfig
```

Build the APK:

```powershell
cd mobile\app
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

The APK is generated at:

```text
mobile\app\build\app\outputs\flutter-apk\app-debug.apk
```

Install the APK on Android phones, connect the phones and laptop to the same network, then update the backend URL inside the app if the laptop IP changes.

## Android Permissions

For best results, allow these permissions when prompted:

- Microphone: required for acoustic scanning.
- Nearby Devices / Bluetooth: required for BLE scan and advertising.
- Location: required by Android for reliable BLE scanning on many devices.
- Camera: currently not part of the main attendance proof path, but may be used by optional face-enrollment code.

If BLE range seems poor, confirm that Location and Nearby Devices permissions are enabled in Android app settings.

## Attendance Workflow

Lecturer:

1. Log in as lecturer.
2. Create a session with course, lecturer, room, and token version details.
3. Start broadcast.
4. Keep Bluetooth enabled and permissions granted.
5. View validation reports and export CSV after students submit.

Student:

1. Log in as student.
2. Open the scan page.
3. Use Acoustic/BLE scan as the preferred proof path.
4. Use Wi-Fi/LAN fallback only when needed and allowed.
5. Submit proof once.
6. View attendance history.

## Validation Rules

The backend checks:

- Authenticated student identity.
- Active session.
- Student ID matches the logged-in student.
- Registered device ID and device ownership.
- At least one valid proof path: BLE, acoustic, or Wi-Fi/LAN fallback.
- Proof freshness.
- Replay protection for acoustic/BLE proof.
- One attendance submission per student per session.

## Documentation

Formal FYP drafts:

- `docs/fyp/CHAPTER_ONE.md`
- `docs/fyp/CHAPTER_TWO.md`
- `docs/fyp/CHAPTER_THREE.md`
- `docs/fyp/REFERENCES.md`
- `docs/fyp/SOURCES_TO_CONFIRM.md`

Presentation readiness notes:

- `docs/presentation_readiness/01_APK_LAN_DEMO_SETUP.md`
- `docs/presentation_readiness/02_ROOM_SIZE_AND_OPERATING_CONDITIONS.md`
- `docs/presentation_readiness/03_WIFI_VERIFICATION_OPTION.md`
- `docs/presentation_readiness/04_COST_IMPLICATION.md`

## Academic Position

This project should be presented honestly:

- BLE is currently the stronger classroom proximity signal.
- Acoustic beaconing demonstrates an innovative telecommunication concept but is short-range in the current prototype.
- Wi-Fi/LAN is a fallback channel for controlled network scenarios.
- Fixed BLE beacons can extend coverage for medium and large classrooms.
- The system is a proximity-verification prototype, not a perfect indoor positioning system.

## Useful Commands

Check backend:

```powershell
cd backend
python manage.py check
python manage.py makemigrations --check --dry-run
```

Apply migrations:

```powershell
cd backend
python manage.py migrate
```

Run backend for phone testing:

```powershell
cd backend
python manage.py runserver 0.0.0.0:8000
```

Build Android APK:

```powershell
cd mobile\app
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

## License and Use

This project is being developed as an academic final-year project prototype. Production deployment would require additional security review, privacy policy, server hardening, broader device testing, and institutional approval.
