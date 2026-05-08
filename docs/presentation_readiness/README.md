# Presentation Readiness Notes

This folder contains practical notes for strengthening the project before the first seminar and final demonstration.

These documents are separate from the formal FYP chapters. They are meant to help us reason clearly, prepare for questions, and later decide what should be included in Chapter Three, Chapter Four, Chapter Five, or the presentation slides.

## Files

- `01_APK_LAN_DEMO_SETUP.md`: how to test the app without USB using APK installation and a backend server on the same network.
- `02_ROOM_SIZE_AND_OPERATING_CONDITIONS.md`: realistic room-size expectations and environmental conditions for Acoustic and BLE.
- `03_WIFI_VERIFICATION_OPTION.md`: how Wi-Fi/LAN is used as a minimal fallback attendance verification layer.
- `04_COST_IMPLICATION.md`: basic cost considerations if a school wants to adopt the system.

## Important Position

The system should be presented honestly:

- Acoustic is innovative and useful as a short-range proximity signal, but it is sensitive to noise, distance, speaker quality, and microphone quality.
- BLE is currently the more practical classroom-range signal, especially when Location and Nearby Devices permissions are granted.
- Fixed BLE beacons are the most relevant extension for larger classrooms.
- Wi-Fi/LAN can support fallback verification, but it proves network presence more than exact physical proximity.
- Device ID binding is implemented as an anti-fraud layer to reduce account-sharing and duplicate-device misuse.
- Larger rooms may need additional infrastructure such as fixed BLE beacons, while Wi-Fi/LAN remains a support/fallback option.
