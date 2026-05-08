# Room Size and Operating Conditions

## Purpose

This document defines realistic operating conditions for the current version of the smart attendance system.

It helps us answer questions such as:

- What size of room can the system support?
- Why does acoustic detection have short range?
- What should be done in larger classrooms?
- How should the system be presented honestly?

## Main Position

The system should not be presented as a perfect large-lecture-hall solution yet.

The current system is best described as:

> A mobile-based smart attendance system designed for classroom proximity verification using BLE and Acoustic signals, with stronger suitability for small to medium controlled classroom environments and possible extension to larger rooms through fixed BLE beacons, while Wi-Fi/LAN remains a fallback support layer.

Updated implementation position:

> BLE is currently the stronger practical classroom signal. Acoustic verification works, but it is best presented as a very short-range copresence signal in the present prototype. Wi-Fi/LAN is available as a fallback proof path, not as the main proximity technology.

## Acoustic Operating Conditions

Acoustic beaconing uses the lecturer phone speaker to broadcast an encoded attendance signal. The student phone microphone listens and decodes the signal.

Acoustic performance depends on:

- Speaker loudness.
- Speaker frequency response.
- Student phone microphone sensitivity.
- Distance between phones.
- Background noise.
- Room echo.
- Phone orientation.
- Ultrasonic or near-ultrasonic attenuation.
- Whether an external speaker can reproduce the selected frequency.

## Acoustic Strengths

- Uses phone speaker and microphone.
- Does not require pairing.
- Demonstrates telecommunication signal encoding and decoding.
- Useful as a short-range proximity/copresence signal.
- Can support small-room or close-range verification.

## Acoustic Limitations

- Short range on many phones.
- Noise can reduce decoding success.
- Some speakers, especially Bluetooth speakers, may not reproduce high-frequency tones properly.
- Large rooms are difficult unless audio hardware and signal design are improved.
- Phone orientation can affect decoding.

## BLE Operating Conditions

BLE uses Bluetooth Low Energy advertising and scanning. The lecturer device advertises a session-specific signal, while the student device scans for it.

BLE performance depends on:

- Bluetooth being enabled.
- Required Android Bluetooth permissions.
- Phone BLE hardware.
- Distance.
- Obstacles.
- Radio interference.
- Device orientation.
- Android background scanning behavior.

## BLE Strengths

- More practical than acoustic for classroom proximity.
- Does not require audible sound.
- Can work while students are not extremely close to the lecturer phone, especially when Location and Nearby Devices permissions are granted.
- Suitable for short-range wireless attendance proof.
- Can be extended with fixed BLE beacons in larger rooms.

## BLE Limitations

- Range can vary by phone model.
- Bluetooth, Nearby Devices, and Location permissions must be granted.
- BLE RSSI is not stable enough for exact distance measurement.
- BLE can be affected by interference and device differences.
- BLE signal alone should still be protected with freshness and backend validation.

## Recommended Room Classification

The values below are planning estimates for discussion and demonstration preparation. Final values should be confirmed through Chapter Four field testing.

| Room Type | Approximate Size | Typical Class Size | Current Suitability | Recommended Signal Strategy |
| --- | --- | --- | --- | --- |
| Small tutorial room | Up to about 7 m x 7 m | 10-30 students | Good for demo and controlled use | BLE primary, acoustic close-range secondary |
| Laboratory or seminar room | About 7 m x 10 m | 20-50 students | Good to moderate | BLE primary, acoustic secondary |
| Medium classroom | About 8 m x 12 m | 40-80 students | Moderate without extra infrastructure | BLE primary, fixed BLE beacon support if available, Wi-Fi/LAN fallback |
| Large lecture hall | Above 12 m x 12 m | 80+ students | Limited without infrastructure | Fixed BLE beacons recommended, managed Wi-Fi/LAN fallback optional |

## Expected Signal Range for Current Prototype

These values should be presented as conservative operating expectations, not final performance claims.

| Signal Type | Conservative Practical Range | Best Use |
| --- | --- | --- |
| Acoustic phone-to-phone | About 0.3 m to 1.0 m in noisy conditions | Very close-range proof, small demo, secondary copresence evidence |
| Acoustic in quiet room | May reach above 1 m depending on device hardware | Controlled demo and future optimization tests |
| BLE phone-to-phone | About 5 m to 10 m after Bluetooth/Location permissions are granted, depending on phone hardware and room conditions | Primary classroom proximity signal for current prototype |
| BLE with fixed beacons | About 5 m to 20 m per beacon depending on beacon power and room conditions | Medium and large classroom extension |
| Wi-Fi classroom network | Room/building-level coverage depending on router/AP | Minimal fallback network-presence verification, not exact proximity |

## Recommended Classroom Deployment Targets

| Deployment Stage | Recommended Target |
| --- | --- |
| Current seminar demo | 2-5 phones, small room or controlled corner of a room |
| Near-term pilot | Small classroom, about 10-30 students, BLE primary |
| Medium-class pilot | BLE primary, fixed beacon support if available |
| Large-class deployment | Fixed BLE beacons primary, managed classroom Wi-Fi/LAN fallback optional |

## Larger Room Strategy

For larger classrooms, the system should not depend only on the lecturer phone speaker or BLE radio.

Possible extensions:

1. Fixed BLE beacons placed around the room.
2. Classroom Wi-Fi verification as fallback/support.
3. Lecturer laptop or dedicated device broadcasting stronger BLE signals.
4. External audio hardware only if it can reproduce the required acoustic frequency.

## Suggested Infrastructure by Room Size

| Room Type | Suggested Infrastructure |
| --- | --- |
| Small room | Lecturer phone only may be enough for demo; BLE is preferred for real use |
| Medium room | 2-4 BLE beacons if needed; optional router/AP for backend access and Wi-Fi/LAN fallback |
| Large lecture hall | About 4-8 BLE beacons depending on layout; optional managed Wi-Fi/AP support |

## Bluetooth Beacon Clarification

A Bluetooth beacon does not work as a "Bluetooth amplifier" for the lecturer phone.

Instead, it acts as a separate BLE broadcaster.

In a large classroom, several fixed BLE beacons can be placed at strategic points. These beacons can broadcast classroom/session-related signals that student phones scan. The backend then validates whether the detected beacon belongs to the active classroom session.

Better wording for presentation:

> For larger classrooms, the system can be extended with fixed BLE beacons placed at strategic points in the room. These beacons would not amplify the lecturer phone signal, but would act as additional proximity broadcasters linked to the active attendance session.

## Recommended Presentation Claim

Use careful wording:

> The current implementation demonstrates Acoustic and BLE-based classroom proximity verification on Android devices. Acoustic verification currently works best as very short-range copresence proof, while BLE is more practical for wider classroom coverage. For larger rooms, the system can be extended using fixed BLE beacons, while Wi-Fi/LAN can serve as a fallback network-presence layer.

Avoid saying:

> The system works perfectly in all classroom sizes.

## Testing Plan for Chapter Four

Later, Chapter Four should include tests such as:

- Acoustic success rate vs distance.
- BLE success rate vs distance.
- Quiet room vs noisy room.
- Different phone models.
- Different room sizes.
- Time taken to scan and submit attendance.

These results will help define the final recommended operating range.
