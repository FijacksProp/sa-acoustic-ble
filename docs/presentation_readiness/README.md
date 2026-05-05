# Presentation Readiness Notes

This folder contains practical notes for strengthening the project before the first seminar and final demonstration.

These documents are separate from the formal FYP chapters. They are meant to help us reason clearly, prepare for questions, and later decide what should be included in Chapter Three, Chapter Four, Chapter Five, or the presentation slides.

## Files

- `01_APK_LAN_DEMO_SETUP.md`: how to test the app without USB using APK installation and a backend server on the same network.
- `02_ROOM_SIZE_AND_OPERATING_CONDITIONS.md`: realistic room-size expectations and environmental conditions for Acoustic and BLE.
- `03_WIFI_VERIFICATION_OPTION.md`: how Wi-Fi could be used as an additional attendance verification layer.
- `04_COST_IMPLICATION.md`: basic cost considerations if a school wants to adopt the system.

## Important Position

The system should be presented honestly:

- Acoustic is innovative and useful as a short-range proximity signal, but it is sensitive to noise, distance, speaker quality, and microphone quality.
- BLE is more practical for classroom proximity, but it still depends on permissions, hardware, interference, and phone behavior.
- Wi-Fi can support wider coverage, but it proves network presence more than exact physical proximity.
- Device ID binding is important for fraud reduction and should be implemented as an anti-fraud layer.
- Larger rooms may need additional infrastructure such as fixed BLE beacons or classroom Wi-Fi verification.
