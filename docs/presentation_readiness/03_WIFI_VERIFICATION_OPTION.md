# Wi-Fi Verification Option

## Purpose

This document explains how Wi-Fi/LAN can be used as a fallback attendance verification layer.

Wi-Fi was suggested because it can cover a larger area than acoustic signals and may be more reliable in some classroom environments. In this project, however, it is kept as fallback/support evidence because it proves network presence rather than exact proximity.

## Main Position

Wi-Fi can be useful, but it should not replace Acoustic and BLE in the main project argument.

Best position:

> Wi-Fi/LAN should be treated as a fallback or supporting verification layer. BLE remains the main practical classroom-range proximity signal, while acoustic remains a short-range copresence signal.

Current implementation note:

> The project now includes a Wi-Fi/LAN proof path for APK demos and fallback classroom-network verification. It accepts attendance when the student is authenticated, the session is active, the device passes device-trust rules, no duplicate proof exists, and the phone reaches the backend from a private/local network.

## Why Wi-Fi Is Attractive

Wi-Fi may be useful as fallback support because:

- It has wider coverage than acoustic.
- It is already available in many schools.
- It can support many devices at once.
- Students can connect without being very close to the lecturer phone.
- It can help confirm that the student device is within the school or classroom network, although not the exact distance from the lecturer.

## Can the Lecturer Create an Open Wi-Fi?

Yes, it is technically possible for the lecturer to create a Wi-Fi hotspot or router network that does not require students to enter a password.

This can be done through:

- Phone hotspot with no password, if the phone allows it.
- Portable MiFi/router configured as an open network.
- Classroom router/access point configured with an open SSID.

However, an open Wi-Fi network is not recommended for real deployment because anyone nearby can connect. It can also expose the demo network to unnecessary traffic.

Better options:

1. Use a simple shared password displayed in class.
2. Use a dedicated classroom Wi-Fi with a known SSID and password.
3. Use an open network only for demo, but still require app login and attendance signal validation.
4. Use app-level verification so being connected to Wi-Fi alone is not enough to mark attendance.

Recommended position:

> Open Wi-Fi can be used for quick demonstration, but real deployment should use a secured classroom network plus app-level attendance validation.

## Can Wi-Fi Handle Many Students?

Yes, but capacity depends on the type of hotspot or router.

| Wi-Fi Source | Typical Practical Capacity | Suitability |
| --- | --- | --- |
| Lecturer phone hotspot | About 5-10 students | Demo or very small group only |
| Portable MiFi | About 10 students for many common models | Demo or small tutorial group |
| Consumer 4G router | About 30-60 students depending on model and traffic | Small to medium classroom |
| Dedicated classroom access point | About 50-150+ students depending on AP quality | Medium to large classroom |

Attendance submission is light traffic because students are only sending small proof data. This means Wi-Fi capacity is easier to handle than video streaming or file downloads. However, many students connecting at the same time can still overload a weak phone hotspot or MiFi.

For a real classroom, a dedicated router or access point is better than a lecturer phone hotspot.

## Wi-Fi Verification Methods

### 1. Same LAN Verification

The student app checks whether it can reach the backend server on the local network.

Example:

- Laptop backend runs on `http://192.168.x.x:8000`.
- Student phones must be on the same Wi-Fi network to submit attendance.

Strength:

- Simple to demonstrate.
- Works with the current APK/LAN setup.

Limitation:

- It proves the phone is on the same network, not necessarily inside the exact classroom.

Recommended use:

- Good for the current APK/LAN demonstration.
- Not enough as the only proof for final deployment.

### 2. Wi-Fi SSID Verification

The app checks the Wi-Fi network name.

Example:

```text
UNILORIN_CLASSROOM_WIFI
```

Strength:

- Simple idea.
- Can help restrict attendance to a known network.

Limitation:

- SSID names can be duplicated.
- Android may require location permission to read Wi-Fi details.
- Being connected to the same SSID does not prove exact room presence.

### 3. Wi-Fi BSSID Verification

The app checks the access point BSSID, which is usually the MAC address of the Wi-Fi access point.

Strength:

- More specific than SSID.
- Can help identify a particular classroom router/access point.

Limitation:

- Android permission restrictions may apply.
- Access point roaming may change the BSSID.
- Privacy restrictions may affect availability on newer Android versions.

### 4. Classroom Router or Local Server Verification

A classroom router or local backend can be used. Attendance works only when the student phone can reach the classroom server.

Strength:

- Useful for controlled classroom deployment.
- Can support larger rooms.

Limitation:

- Requires network setup in each classroom.
- Still does not fully prove the exact student identity.

### 5. Wi-Fi RTT

Wi-Fi RTT can estimate distance to access points using round-trip time measurements.

Strength:

- More advanced indoor positioning possibility.

Limitation:

- Not supported by all phones or routers.
- More complex to implement.
- Not recommended for the current project phase.

## Recommended Use in This Project

For now, Wi-Fi is treated as a fallback verification channel:

```text
Attendance proof may be accepted through:
- BLE signal, or
- Acoustic signal, or
- Wi-Fi/LAN fallback verification
```

However, Wi-Fi should be added carefully because it proves network presence, not direct lecturer proximity.

## Recommended Wi-Fi Policy

The system should not mark attendance just because a student is connected to Wi-Fi.

Better policy:

```text
Wi-Fi proof = supporting evidence
Acoustic/BLE proof = proximity evidence
Device ID = identity/device trust evidence
Backend validation = final decision
```

Possible final rule:

```text
Accept if:
- Student is authenticated, and
- Session is active, and
- No duplicate attendance exists, and
- At least one valid proof exists:
  - BLE, or
  - Acoustic, or
  - Approved classroom Wi-Fi plus device-trust check
```

## Suggested Validation Logic

The backend currently treats Wi-Fi/LAN proof like this:

- Student app generates a short proof for the latest active session.
- Student submits the proof to the backend immediately.
- Backend checks that the request came through a private/local network address.
- Backend still enforces authentication, active session, duplicate prevention, and device binding.
- The validation report records the proof as `wifi_lan`.

If a stricter Wi-Fi policy is added later, the backend can score it like this:

- Student connected to approved classroom network: positive signal.
- Student not on approved network: no Wi-Fi proof.
- Wi-Fi proof plus BLE proof: stronger confidence.
- Wi-Fi proof only: accepted only if policy allows it.

## Recommended Presentation Wording

Use:

> Wi-Fi/LAN is included as a fallback support layer. It can help when a classroom network is available, but it provides network-level presence rather than exact physical proximity. BLE remains the main practical classroom proximity channel, acoustic remains short-range copresence evidence, and backend validation still enforces freshness, duplicate prevention, and device trust.

Avoid:

> Wi-Fi will fully solve the range problem.

## Practical Recommendation

For the current seminar and near-term build:

1. Keep Acoustic and BLE as the implemented proximity channels.
2. Use APK + LAN for realistic demonstration without USB.
3. Use Wi-Fi/LAN verification only as a fallback proof path where acoustic/BLE range is weak or unavailable.
4. Continue treating Wi-Fi as classroom-network evidence, not exact distance measurement.

## Current Recommendation

Wi-Fi should be discussed as an implemented supporting enhancement, not as a replacement for BLE and Acoustic.

For the current build:

- Use Wi-Fi/LAN to connect the APK to the backend.
- Use BLE/Acoustic to verify short-range proximity where available.
- Use Wi-Fi/LAN proof as a minimal classroom-network fallback, especially for APK demonstration and controlled exception handling.
