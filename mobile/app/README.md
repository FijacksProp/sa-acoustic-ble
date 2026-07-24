# Smart Attendance Mobile App

Flutter client for the Smart Attendance System. The Android application lets
lecturers create and open attendance sessions, broadcasts rotating acoustic and
Bluetooth Low Energy (BLE) signals, scans those signals on student devices, and
submits authenticated attendance proofs to the Django API.

## Main Workflows

- Student and lecturer registration and login
- Device-bound student accounts
- Lecturer session creation and room selection
- Foreground acoustic and BLE broadcasting on Android
- Student acoustic, lecturer BLE, and registered room-beacon scanning
- Duplicate-safe attendance submission
- Student history, lecturer live-session views, reports, and CSV export

## Run

From this directory:

```powershell
flutter pub get
flutter run -d <device-id> --dart-define=API_BASE_URL=https://sa-acoustic-ble.onrender.com
```

The hosted API URL is the default in the app. The `--dart-define` is only
required when testing a different backend.

## Build an Android APK

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://sa-acoustic-ble.onrender.com
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
