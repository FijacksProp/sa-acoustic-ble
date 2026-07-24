# Chapter Four: Implementation, Testing, Results and Discussion

## 4.1 System Implementation

The completed prototype consists of a Flutter Android application, native Kotlin signal modules, a Django REST API, and a relational database. The API is deployed at `https://sa-acoustic-ble.onrender.com`, allowing installed applications to authenticate and submit records without using a local computer address.

The Flutter application presents separate lecturer and student portals after authentication. The lecturer can create a course session, select a room, open attendance, maintain a live broadcast, review session-specific records, search, and export CSV. The student can scan, review the captured mode, submit once, view history, and inspect the registered installation information.

The native Android layer provides the operations that could not be implemented reliably as browser-only functions. Kotlin classes perform acoustic PCM generation, microphone decoding, BLE advertising, and foreground-service management. The lecturer broadcast service maintains a persistent notification, acquires a partial wake lock, and rotates the acoustic and BLE values every 45 seconds. The service is separate from the selected Flutter page, so navigating from Session to Live, Reports, or Profile does not intentionally stop transmission.

The backend performs the authoritative attendance decision. It applies authentication, role, session-owner, room, time, signal, device, digest, duplicate, and replay rules before storing a proof. The Django administration interface exposes operational records while keeping accepted proof and replay data read-only.

## 4.2 Implemented User Workflows

### 4.2.1 Lecturer Workflow

The lecturer signs in, creates or selects a session, chooses the classroom, and opens attendance. The API prevents another session from opening in the same room and starts a 15-minute attendance window. The app then requests the required Bluetooth state and permissions before starting the Android foreground service.

The session page presents the course, room, and broadcast state without requiring the lecturer to manage token values. The Live page provides searchable sessions and compact rows, while the Reports page displays students for the selected session and exports the same data in CSV form.

![Lecturer session interface](assets/report/screenshots/lecturer_session.png)

*Figure 4.1. Lecturer session creation and attendance broadcast interface.*

### 4.2.2 Student Workflow

The student signs in with a matric-number account. The installation identifier is loaded from local storage and preserved across logout. A scan starts acoustic capture and BLE discovery concurrently. When lecturer BLE or room-beacon evidence is found, the app records the source, RSSI, and session. An acoustic decode supplies the compact acoustic token directly.

Submission is disabled unless the scan contains a valid current path. After server acceptance, a confirmation is displayed and the session is added to the local submitted set. This local check improves feedback, while the server and database remain the final duplicate controls.

![Student scan interface](assets/report/screenshots/student_scan.png)

*Figure 4.2. Student scan and proof-review interface.*

### 4.2.3 Reporting Workflow

The lecturer selects a session before retrieving its report. Student entries are shown as one-line rows to avoid allocating a large card to every member of a class. Tapping a row reveals the matric number, course, room, device, and captured signal mode. Search applies to session, course, room, student name, matric number, and device values.

![Lecturer attendance report](assets/report/screenshots/lecturer_report.png)

*Figure 4.3. Session-specific lecturer attendance report.*

## 4.3 Evaluation Design

Evaluation was divided into automated software verification and small-scale physical-device testing. The two sets of results answer different questions. Automated tests verify deterministic rules in the software. Physical tests show whether signal capture and user workflows operated on the available phones under the observed conditions.

The physical tests were repeated over more than one week with one principal lecturer device and three student devices. Distances were estimated by the tester rather than measured with laboratory instrumentation. Acoustic observations used very close, best-case quiet, and noisy conditions. BLE observations were grouped into short, medium, and longer ranges and included common indoor obstructions. Consequently, the field results are reported as successful observations and practical ranges, not as statistical detection probabilities.

**Table 4.1: Android Devices Used in Physical Testing**

| Device | Role | Use during evaluation |
| --- | --- | --- |
| Redmi 13C | Principal lecturer | Session creation, acoustic transmission, lecturer BLE advertising |
| POCO C71 | Student | Acoustic/BLE scan and attendance submission |
| Samsung A05 | Student | Acoustic/BLE scan and attendance submission |
| Vivo Y33 | Student | Acoustic/BLE scan and attendance submission |

The lecturer workflow was also tried on another available phone to confirm that session broadcasting was not restricted to the Redmi 13C. The Redmi remained the controlled lecturer reference for the observations presented here.

## 4.4 Automated Verification Results

The final code audit used focused tests instead of relying on a long-running static analyser. The backend suite created an isolated test database and exercised API behaviour. Flutter widget and unit tests rendered the principal role layouts and checked storage behaviour. The Android Gradle task compiled the Kotlin implementation offline.

**Table 4.2: Automated Software Verification**

| Verification | Scope | Result |
| --- | --- | --- |
| Django API tests | 15 tests covering authorisation, sessions, proof validation, duplicate/replay logic, beacon rules, device uniqueness, privacy, and logout | 15 passed |
| Django system check | Model, URL, application, and configuration checks | No issues reported |
| Migration consistency | Compare models with committed migrations | No pending migration changes |
| Python byte-code compilation | `attendance` and `config` packages | Completed without syntax error |
| Flutter tests | Authentication screen, student mobile layout, lecturer mobile layout, device-ID persistence | 4 passed |
| Android Kotlin compilation | Foreground service, audio components, BLE advertiser, plugin integration | Build successful |

The backend tests included a case in which two different students submitted the same classroom BLE nonce. Both submissions were accepted because the signal was valid for both authenticated students. A repeat by the same student was rejected. This result verifies that replay uniqueness is correctly student-scoped rather than globally blocking every classmate after the first submission.

Other tests confirmed that a student could not update a lecturer session, a non-owner could not manage another lecturer's session, a changed proof digest was rejected, a submitted identity had to match the signed-in student, unsupported proof was rejected, a compact acoustic token was accepted, a beacon had to match the room and RSSI rule, one installation identifier could not be assigned to two student profiles, private legacy fields were not returned in profile responses, and a logout token could no longer access the API.

## 4.5 Acoustic Results

Acoustic transmission and decoding worked on the four-device test set, establishing that the implemented frame could be exchanged between ordinary phone speakers and microphones. Reception was strongly dependent on separation, noise, loudness, and placement.

**Table 4.3: Observed Acoustic Performance**

| Condition | Observed separation | Finding |
| --- | --- | --- |
| Normal close test | Approximately 1-30 cm | Decodes were obtained, with success affected by noise and device placement |
| Quiet room, maximum lecturer volume | Approximately 50 cm or slightly more | Furthest successful observation reported during the test period |
| Increased noise or less favourable placement | Beyond the reliable close range | Decode became inconsistent or failed |

No success percentage is reported because the number of attempts per distance and noise condition was not fixed or logged. The result supports feasibility but does not support a claim of classroom-wide acoustic coverage.

The observed range is lower than that reported by Getreuer et al. (2018). This difference is technically plausible because their system used direct-sequence spread spectrum and a protocol designed for robust consumer-hardware communication, whereas the project uses a compact binary frequency-shift-keyed frame and relatively simple tone decisions. The difference also shows why a result from another protocol cannot be adopted as the expected range of this implementation.

The acoustic path remains useful as independent very-short-range copresence evidence. It is not the principal mechanism for a medium or large room. Increasing output alone is not an adequate solution because greater amplitude may increase audible artefacts without overcoming microphone response or noise. Further improvement would require controlled work on coding gain, synchronisation, filtering, error correction, repeated capture, and device calibration.

## 4.6 Lecturer-Device BLE Results

Lecturer-device BLE was the strongest practical signal path in the evaluation. Each of the three student phones detected the lecturer advertisement in the short, medium, and longer distance groups used by the tester.

**Table 4.4: Observed Lecturer BLE Performance**

| Distance group | Estimated range | Result on POCO C71, Samsung A05, and Vivo Y33 |
| --- | --- | --- |
| Short | 1-5 m | Lecturer BLE detected |
| Medium | 5-10 m | Lecturer BLE detected |
| Longer | Above 10 m | Lecturer BLE detected under the tested conditions |

BLE also remained detectable during tests involving curtains or fabric, wooden objects, other room contents, and walls. These observations do not define a guaranteed maximum range. They show that the lecturer phone provided useful coverage beyond the current acoustic path and tolerated several non-line-of-sight conditions.

The result agrees with the literature in treating BLE as practical classroom technology (Azmi et al., 2018; Hayati & Nugraha, 2023; Noguchi et al., 2015; Puckdeevongs et al., 2020). It also reinforces the limitation described by Ramirez et al. (2021): detection and RSSI are affected by hardware and environment. A BLE signal observed through a wall is useful for coverage but creates adjacent-room ambiguity. The server's room, open-session, freshness, and RSSI checks are therefore necessary.

## 4.7 DX-CP27 Room-Beacon Results

The DX-CP27 Mini was configured and detected through its BLE frames. The project supports both iBeacon and Eddystone UID parsing, and the configured frame can be stored as a `RegisteredBeacon` assigned to a room. This verified that a commercial beacon could participate in the implemented scan and backend workflow without pairing with every student phone.

The lecturer-device advertisement was selected more often than the CP27 during combined tests, even when the beacon was physically close in some trials. The source-selection logic was subsequently revised to compare the strongest lecturer and beacon observations. If one exceeds the other by at least 10 dB, the stronger source is selected; if the readings are within 10 dB, both are retained.

**Table 4.5: Room-Beacon Evaluation**

| Area | Result |
| --- | --- |
| CP27 frame visibility | Detected during BLE scanning |
| iBeacon/Eddystone parsing | Supported by the student scanner |
| Backend registration | Beacon identity, room, RSSI, and configuration stored |
| Session resolution | Open session resolved from the beacon's registered room |
| Combined source selection | 10 dB comparison implemented; lecturer source had dominated earlier observations |
| Large-room and adjacent-room reliability | Not established by the completed small-scale tests |

The fixed beacon is not a Bluetooth amplifier. It is an additional transmitter whose known identity can provide coverage at another point in the room. Its signal is static and does not satisfy the 60-second lecturer freshness rule. Instead, the backend requires a currently open session in the registered room and applies the beacon's minimum RSSI. This avoids accepting attendance simply because the beacon was powered before class.

![Registered CP27 beacon record](assets/report/screenshots/beacon_admin.png)

*Figure 4.4. Registered room-beacon configuration in the administrative interface.*

## 4.8 Permission, Bluetooth State, and Hosting Results

Android permission state had a direct effect on BLE. Before the required location-related access was enabled on one test configuration, BLE appeared to have poor range. After permission was granted, detections extended to the distance groups reported in Table 4.4. This observation is consistent with the Android permission requirements for BLE scanning and advertising (Android Developers, n.d.).

The application now checks Bluetooth state before BLE scanning and returns a direct instruction when the adapter is off. Microphone, nearby-device, Bluetooth, and location permissions are requested at the point of use. The updated Bluetooth-off and background-broadcast behaviours were compiled successfully; they should remain part of the repeat physical regression checklist for each release APK.

The hosted backend removed the principal LAN limitation of earlier builds. Both test phones could communicate with the same stable URL without USB or a changing desktop IP. When the free Render instance had slept, its initial response took approximately one to two minutes. Subsequent requests were normal for the small-scale workflow. This delay is acceptable for a demonstration if the service is opened in advance, but it is not suitable evidence of production availability.

## 4.9 Functional and User-Experience Results

Registration, login, role routing, session creation, scan, submission, history, report retrieval, and CSV export operated during development tests. User-facing errors were revised so that connection failures, disabled Bluetooth, denied permissions, expired signals, duplicates, room mismatch, and server cold starts produce concise recovery guidance instead of socket traces or serializer dumps.

The lecturer Live and Reports layouts were restructured for class-size growth. Search is available across the relevant session and student fields. Student records are compact and expand on demand. Flutter viewport tests did not report layout overflow for the student or lecturer portal at 390 x 844 logical pixels.

The report is session-specific. Changing the selected session changes the displayed records, course, lecturer, and room context. The CSV export is generated from the same selected session to avoid combining unrelated classes.

## 4.10 Attendance-Control Results

The small-scale evaluation and automated suite produced evidence for the following controls:

1. a student identity must match the authenticated profile;
2. the installation identifier survives logout;
3. one non-empty installation identifier cannot belong to two student profiles;
4. one student cannot create more than one attendance proof for a session;
5. two classmates can legitimately use the same broadcast nonce;
6. the same student cannot replay the same acoustic challenge or BLE nonce in the session;
7. a changed proof digest is rejected;
8. a registered beacon must match the selected session room and RSSI policy;
9. only the owning lecturer may manage or report on a session; and
10. logout revokes the server authentication token.

These results should not be interpreted as complete fraud prevention. Device binding does not detect who is physically carrying the registered phone, and SHA-256 without a protected secret does not make a modified client trustworthy. Real-time relay, rooted-device manipulation, collusion, and institutional device-recovery policy remain outside the completed evaluation.

## 4.11 Discussion

The results support a BLE-centred attendance design. Lecturer-device BLE provided useful detection on all three student phones at estimated ranges above 10 m, while the acoustic path was normally limited to 1-30 cm. Requiring both signals for every student would therefore cause unnecessary rejection. Treating acoustic, lecturer BLE, and registered room beacon as alternative valid paths is consistent with the observed performance.

The CP27 provides a practical infrastructure option rather than a replacement for the lecturer session. A fixed beacon can improve spatial coverage, but its static frame creates the same class of security concern identified by Kim et al. (2018). The project's response is contextual validation: a beacon must be registered to the room, an owned session must be open, the RSSI must be acceptable, and the student/device/duplicate checks must pass.

The four-device result is encouraging but not statistically generalisable. Hayati and Nugraha (2023) reported a device that failed to perceive a beacon in their evaluation, demonstrating that handset variation remains possible even when the present four devices behaved similarly. Larger tests should therefore retain device model and Android version in the test record.

The automated results strengthen the implementation claims that cannot be inferred from a visual demonstration. A successful scan animation does not prove that another student cannot reuse the nonce or that a non-owner cannot edit a session. Those claims are supported by server tests and database constraints. Conversely, automated tests cannot establish radio range or classroom usability; those claims are limited to the physical observations.

## 4.12 Limitations of the Evaluation

The evaluation has the following limitations:

1. only four Android devices were included;
2. the physical tests were repeated informally rather than with a fixed number of trials per condition;
3. distances were estimated rather than instrumented;
4. no calibrated sound-pressure, ambient-noise, or spectrum measurement was taken;
5. RSSI values were not logged systematically for every distance and phone orientation;
6. a complete class did not submit concurrently;
7. several adjacent rooms with simultaneous sessions and beacons were not field-tested;
8. lecturer foreground broadcasting requires repeat physical verification on the final installed APK across navigation, screen lock, and manufacturer battery settings;
9. the free hosted service was not load- or availability-tested; and
10. the evaluation did not include iOS, accessibility participants, formal penetration testing, or long-term operation.

These limitations constrain the conclusions but do not invalidate the verified functionality. They define the boundary between a working final-year prototype and an institution-ready attendance service.

## 4.13 Summary

The system was implemented and verified across mobile, native Android, backend, database, and hosted-deployment components. Fifteen backend tests and four Flutter tests passed, Django reported no system or migration issue, and the Kotlin implementation compiled successfully.

Physical observations showed that the acoustic path worked at very close range, normally about 1-30 cm and at slightly above 50 cm in the best reported quiet condition. Lecturer-device BLE was detected by the three student phones at estimated short, medium, and above-10-metre ranges and through several ordinary indoor obstacles. The CP27 was detected and integrated as a registered room beacon, but its placement and multi-room performance require more formal evaluation.

The evidence supports BLE as the principal proximity mechanism, acoustic proof as supplementary close-range evidence, and the fixed beacon as optional room infrastructure governed by server-side context. Chapter Five presents the conclusions and recommendations that follow from these findings.
