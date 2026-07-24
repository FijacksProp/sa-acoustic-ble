# Project Seminar Presentation Draft

Project title: **Design and Implementation of a Smart Attendance System Using Acoustic and Bluetooth Low Energy Proximity Verification**

Presenter: **OLUGBEMI Joshua Iyanuoluwa**

Matric number: **21/52HP071**

Department: **Telecommunication Science, University of Ilorin**

Slide count: **11 slides**

Note: This draft matches the supervisor-approved slide structure and the current implemented project direction.

---

## Slide 1: Title Page

**UNIVERSITY OF ILORIN, ILORIN**

Faculty of Communication and Information Sciences

Department of Telecommunication Science

**Project Presentation**

**Design and Implementation of a Smart Attendance System Using Acoustic and Bluetooth Low Energy Proximity Verification**

Presented by:

**OLUGBEMI Joshua Iyanuoluwa - 21/52HP071**

Project Supervisor: **Dr. IMAM FULANI**

May, 2026

---

## Slide 2: Introduction

**Background of the Study**

Attendance remains operationally difficult because:

- Manual roll call consumes class time and creates avoidable administrative delay.
- Paper registers provide weak tamper-evidence and can be manipulated.
- Static QR codes and PINs can be shared outside the classroom.
- Most basic systems verify user identity, but not physical presence.

**Telecommunication Perspective**

- The lecturer acts as a signal broadcaster for an active attendance session.
- The student device acts as a receiver that captures a short-lived proof signal.
- BLE provides the main practical classroom-range proof.
- Acoustic beaconing provides short-range copresence evidence.
- The backend validates freshness, replay status, duplicate status, and device trust.

---

## Slide 3: Literature Review

| S/N | Source | Area | Work Done | Weakness / Gap |
| --- | --- | --- | --- | --- |
| 1 | Ayop et al. (2018) | QR + GPS | Developed location-aware event attendance using QR code and GPS. | QR can be shared; GPS is less reliable indoors. |
| 2 | Getreuer et al. (2018) | Acoustic | Demonstrated ultrasonic communication using consumer hardware. | Not designed for attendance; range depends on speaker/mic and noise. |
| 3 | Kim et al. (2018) | BLE security | Analyzed BLE beacon attendance and signal imitation attacks. | BLE proof needs freshness and replay protection. |
| 4 | Puckdeevongs et al. (2020) | BLE attendance | Proposed BLE indoor-positioning attendance for smart campus. | RSSI and beacon coverage vary across rooms/devices. |
| 5 | Ramirez et al. (2021) | BLE RSSI | Studied practical BLE RSSI measurement for indoor positioning. | RSSI supports proximity, not exact classroom distance. |

**Summary:** Existing works support automation and proximity verification, but single-channel systems still require freshness, replay protection, and backend validation.

---

## Slide 4: Problem Statement

Attendance in many higher-education settings still relies on manual roll calls, paper sheets, or basic digital tools such as static QR codes and PINs. These methods waste class time, offer little protection against tampering, and make it easy to copy or reuse attendance artifacts outside the classroom.

The core problem is that most systems verify login identity, but not physical presence, signal freshness, or replay resistance. A more secure approach needs time-limited proximity proof and server-side validation.

---

## Slide 5: Aim and Objectives

**Aim**

To design and implement a secure, role-aware smart attendance system that reduces fraud and operational delay by validating signal-based proof of physical presence.

**Objectives**

1. Design a mobile-based smart attendance system for creating and broadcasting session-specific attendance signals.
2. Implement proximity verification using acoustic beaconing and Bluetooth Low Energy, with BLE as the main classroom-range signal and acoustic proof as short-range copresence evidence.
3. Develop backend validation using session identity, signal freshness, duplicate prevention, replay protection, and device-trust checks.
4. Provide student and lecturer interfaces for scanning, proof submission, attendance history, validation reports, and CSV export.
5. Evaluate the system on real Android devices under different signal conditions, distances, permission states, and classroom-like scenarios.

---

## Slide 6: Proposed Methodology: System Architecture

**Client Tier - Flutter Android App**

Lecturer dashboard, student scan screen, profile, reports, backend URL setting.

**Native Android Signal Services**

BLE advertising/scanning, acoustic encoding/decoding, microphone/location/Bluetooth permissions.

**Backend Tier - Django REST API**

Authentication, session control, proof submission, validation, CSV export.

**Data Tier - SQLite/PostgreSQL-ready**

Users, devices, sessions, attendance proofs, replay guard, validation metadata.

**Key point:** Validation is intentionally server-side. The app captures proof, while the backend decides whether the attendance record is valid.

---

## Slide 7: Proposed Methodology: Identity, Payload and Proof Construction

**Identity and Access Control**

- Students authenticate with matric number and password.
- Lecturers authenticate with lecturer credentials.
- API endpoints are protected by token-based authentication.
- Lecturers view only their sessions and validation reports.
- Device ID binding is used to reduce account-sharing abuse.

**Signal Payload Model**

- BLE proof contains a session-specific short-lived nonce.
- Acoustic proof contains a short session token broadcast through sound.
- Wi-Fi/LAN proof is retained only as a controlled fallback.
- Signals are checked against active session identity and freshness.
- BLE is treated as the main practical classroom signal.

**Proof Construction**

- Student ID comes from the authenticated session.
- Device ID comes from the student's registered device profile.
- Scan mode is recorded as BLE, acoustic, or Wi-Fi/LAN fallback.
- Submitted proof is validated before an attendance record is stored.
- Duplicate and replay attempts are rejected or flagged.

---

## Slide 8: Workflow

**Attendance Verification Workflow**

1. Lecturer creates an active attendance session.
2. Lecturer starts BLE and acoustic broadcast.
3. Student logs in on a registered/trusted device.
4. Student scans BLE or acoustic proof in the classroom.
5. Wi-Fi/LAN fallback may be used only under controlled conditions.
6. App submits proof to the backend API.
7. Backend validates session, freshness, duplicates, replay status, and device trust.
8. Attendance is accepted, rejected, or flagged.

**Key point:** Validation rules turn raw signal detection into attendance decisions.

---

## Slide 9: Proposed Methodology: Backend Validation and Security Controls

**Sequential checks before a proof is recorded**

1. **Signal freshness:** Reject stale BLE/acoustic/Wi-Fi proof outside the allowed session window.
2. **Format correctness:** Reject malformed, truncated, or unsupported proof values before recording.
3. **Session consistency:** Decoded session identity must match the active session being submitted.
4. **Session state:** Only active lecturer-owned sessions can accept attendance.
5. **Duplicate prevention:** One accepted attendance record per student per session.
6. **Replay protection:** Previously used proof values are rejected to prevent token reuse.
7. **Device trust:** Registered device ID is checked to reduce account-sharing fraud.

**Security principle:** Physical signal capture alone is not enough; the backend must validate identity, time, session, duplicate status, replay status, and device trust.

---

## Slide 10: Conclusion

**Conclusion**

- The project demonstrates mobile attendance using BLE and acoustic proximity verification.
- BLE is currently the strongest practical signal for classroom-range attendance proof.
- Acoustic proof adds short-range copresence evidence.
- Backend validation improves trust through freshness, duplicate prevention, replay protection, and device checks.
- Lecturer reports and CSV export support practical academic use.

**Future Work**

- Test fixed BLE beacons for medium and large classrooms.
- Improve acoustic signal robustness and distance.
- Conduct structured field testing across room size, noise, and phone models.
- Refine device-trust and exception scoring rules.
- Prepare hosted-backend deployment for easier demonstrations.

---

## Slide 11: References

Android Developers. (n.d.). *Bluetooth permissions*. https://developer.android.com/develop/connectivity/bluetooth/bt-permissions

Ayop, Z., Lin, C. Y., Anawar, S., Hamid, E., & Azhar, M. S. (2018). Location-aware event attendance system using QR code and GPS technology. *International Journal of Advanced Computer Science and Applications, 9*(9), 466-473. https://doi.org/10.14569/IJACSA.2018.090959

Getreuer, P., Gnegy, C., Lyon, R. F., & Saurous, R. A. (2018). Ultrasonic communication using consumer hardware. *IEEE Transactions on Multimedia, 20*(6), 1277-1290. https://doi.org/10.1109/TMM.2017.2766049

Jia, N., Shu, H., Wang, X., Xu, B., Xi, Y., Xue, C., Liu, Y., & Wang, Z. (2022). Smartphone-based social distance detection technology with near-ultrasonic signal. *Sensors, 22*(19), Article 7345. https://doi.org/10.3390/s22197345

Kim, M., Lee, J., & Paek, J. (2018). Neutralizing BLE beacon-based electronic attendance system using signal imitation attack. *IEEE Access, 6*, 77921-77930. https://doi.org/10.1109/ACCESS.2018.2884488

Nwabuwe, A., Sanghera, B., Alade, T., & Olajide, F. (2023). Fraud mitigation in attendance monitoring systems using dynamic QR code, geofencing and IMEI technologies. *International Journal of Advanced Computer Science and Applications, 14*(4), 938-945. https://doi.org/10.14569/IJACSA.2023.01404104

Puckdeevongs, A., Tripathi, N. K., Witayangkurn, A., & Saengudomlert, P. (2020). Classroom attendance systems based on Bluetooth Low Energy indoor positioning technology for smart campus. *Information, 11*(6), Article 329. https://doi.org/10.3390/info11060329

Ramirez, R., Huang, C.-Y., Liao, C.-A., Lin, P.-T., Lin, H.-W., & Liang, S.-H. (2021). A practice of BLE RSSI measurement for indoor positioning. *Sensors, 21*(15), Article 5181. https://doi.org/10.3390/s21155181
