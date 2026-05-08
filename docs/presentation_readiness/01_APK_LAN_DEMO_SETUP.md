# APK and LAN Demo Setup

## Purpose

This document explains how to test and demonstrate the mobile app without connecting phones through USB.

The idea is simple:

1. Build the Flutter app as an APK.
2. Install the APK on one or more Android phones.
3. Run the Django backend on the laptop.
4. Connect the laptop and phones to the same Wi-Fi network.
5. Let the phones communicate with the backend through the laptop IP address.

This is the recommended demonstration approach for the seminar because it is closer to real-world usage than USB debugging.

## Why This Matters

During presentation, the app should not look like it only works because a phone is connected to the laptop with a cable. Installing the APK shows that the mobile application can run independently on Android devices.

The laptop is still needed as the backend server for now, but phones can connect to it over the local network.

## Backend Setup

From the backend folder, run:

```powershell
cd C:\Users\HP\Desktop\SAS\sa-acoustic-ble\backend
python manage.py runserver 0.0.0.0:8000
```

Using `0.0.0.0:8000` allows other devices on the same network to reach the Django server.

## Find the Laptop IP Address

Run:

```powershell
ipconfig
```

Look for the IPv4 address of the active Wi-Fi adapter.

Example:

```text
IPv4 Address: 10.30.191.158
```

The phone should use:

```text
http://10.30.191.158:8000
```

The actual IP address may change when the laptop connects to a different Wi-Fi network.

## Build APK

From the Flutter app folder, run:

```powershell
cd C:\Users\HP\Desktop\SAS\sa-acoustic-ble\mobile\app
flutter build apk --debug --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Example:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.30.191.158:8000
```

The APK should be created at:

```text
mobile\app\build\app\outputs\flutter-apk\app-debug.apk
```

## Install APK on Phone

Send the APK to the phone using any convenient method:

- Nearby Share
- WhatsApp
- Telegram
- Google Drive
- Bluetooth file transfer
- USB once, only for copying the APK

Then install it on the phone.

Android may ask for permission to install unknown apps. Allow it for the app used to open the APK.

## Network Requirements

The phone and laptop must be on the same network.

Checklist:

- Laptop connected to Wi-Fi.
- Phone connected to the same Wi-Fi.
- Django backend running on `0.0.0.0:8000`.
- Windows Firewall allows Python or port `8000`.
- Django `ALLOWED_HOSTS` includes the laptop IP address or allows local development hosts.

## Backend URL Changes

The app now includes a runtime Backend URL setting on the login/register/profile screens.

This means:

- If only the laptop IP address changes, the APK usually does not need to be rebuilt.
- Open the app, update the Backend URL, and save it.
- Example Backend URL: `http://10.73.208.158:8000`

The `--dart-define=API_BASE_URL=...` value is still useful as the default URL when building, but it is no longer the only way to change the backend address.

## What Requires Rebuilding?

Backend-only changes:

- Usually no APK rebuild is needed.
- Restart the Django server if needed.

Flutter UI or app logic changes:

- APK must be rebuilt and reinstalled.

API base URL changes:

- APK does not usually need to be rebuilt if the runtime Backend URL setting is used.
- Rebuild only if you want to change the default URL embedded during build.

## Demo Recommendation

For the seminar:

1. Use two Android phones if available.
2. Install the APK on both phones before the presentation.
3. Test login, lecturer session creation, broadcast, student scan, proof submission, and report display.
4. Grant Microphone, Nearby Devices/Bluetooth, and Location permissions before scan tests.
5. Keep the laptop, phones, and Wi-Fi hotspot ready.
6. If public Wi-Fi is unstable, use a phone hotspot or router dedicated to the demo.

## Important Limitation

This setup works over the same LAN. It is not yet a public cloud deployment. For final deployment, the backend can be hosted on a school server or cloud server so students do not need to be on the same local network as the lecturer laptop.
