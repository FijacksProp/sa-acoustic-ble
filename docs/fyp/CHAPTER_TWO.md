# Chapter Two: Literature Review

## 2.1 Attendance Management in Higher Education

Attendance management covers the capture, validation, storage, retrieval, and reporting of participation in a scheduled activity. Within a university, the record may be used for course administration, student support, accreditation evidence, or compliance with departmental policy. The value of the record depends not only on whether a name appears on a list, but also on whether the record can be attributed to the correct student, class, place, and time.

Traditional attendance methods include roll call, signatures, and paper registers. Their main advantage is low technical complexity. They can be used without a network, smartphone, or specialist equipment. Their limitations become more visible as class size increases: roll call interrupts instruction, a register must circulate through the room, paper records require later compilation, and an absent student may be represented by a colleague. The administrative problem is therefore both operational and evidential. A faster process is useful only if the resulting record remains trustworthy.

Smart attendance systems introduce electronic identification, sensing, mobile applications, or networked databases into this process. Rashid (2024) identifies RFID, NFC, BLE, and related technologies as common foundations for smart-campus attendance. Automation can reduce transcription, support timestamps, and simplify report generation. It can also create new weaknesses. A system that accepts a static identifier without checking its context may digitise proxy attendance rather than prevent it.

## 2.2 Mobile Attendance Systems

A mobile attendance system uses a smartphone as the principal user terminal. Students may scan a visual code, detect a wireless beacon, provide a biometric sample, or submit location evidence. Lecturers may create sessions, release a temporary credential, monitor responses, and retrieve reports. A remote server can perform authentication and preserve a consistent record across devices.

Smartphones reduce the requirement for a dedicated reader because they already contain wireless radios, cameras, microphones, speakers, clocks, and network interfaces. This advantage is important in settings where the cost of installing and maintaining fixed equipment in every room would be difficult to justify. Lodha et al. (2015) used Bluetooth Smart to reduce the time and human error associated with manual attendance, illustrating the operational value of a wireless attendance workflow.

Mobile deployment also introduces device diversity. Android phones differ in audio frequency response, Bluetooth chipset, antenna arrangement, operating-system version, battery restrictions, and permission behaviour. A design that works on one phone may not produce the same signal level or scan result on another. Mobile software must therefore detect unavailable hardware and disabled services, request permissions at the point of need, present understandable recovery guidance, and avoid deciding attendance exclusively on the client.

The distinction between capture and validation is central to the present study. The phone captures acoustic or BLE evidence, but the server determines whether that evidence is acceptable for the authenticated student and open session. A modified client should not be able to declare itself present merely by displaying a successful scan message.

## 2.3 Identity, Presence, and Proximity

Identity verification answers the question, "Which account is making the request?" Proximity verification asks whether the device observed evidence associated with the classroom. The two questions are related but not interchangeable. Correct credentials do not establish that their owner is present, and a detectable signal does not establish who is holding the receiving phone.

Time also forms part of attendance evidence. A static classroom identifier can be recorded and reused unless the server checks whether a relevant class is open. A rotating signal reduces this risk by including a short-lived timestamp or random value. Duplicate rules prevent a student from creating several records for one session, while replay rules prevent the same captured evidence from being reused improperly.

Nwabuwe et al. (2023) addressed this wider problem by combining dynamic QR codes, geofencing, and IMEI checking. Their work is relevant because it treats attendance fraud as a combination of code sharing, location, and device identity rather than a single-interface problem. The use of IMEI in that study is not directly transferable to a modern third-party Android application, where hardware identifiers are restricted. The present project instead uses an application installation identifier registered to the student account. This identifier is less authoritative than hardware attestation, but it can prevent casual switching between accounts on the same installation.

## 2.4 Existing Attendance Technologies

### 2.4.1 RFID and NFC

RFID uses a reader to detect a radio-frequency tag. NFC is a related short-range technology commonly available in cards and some smartphones. These approaches can make attendance faster than roll call because a tag or card is presented electronically. Miao et al. (2020) went beyond simple tag detection by analysing passive RFID phase characteristics to distinguish targets and address attendance cheating.

RFID and NFC still require an issued credential, a compatible phone, or a reader at the attendance point. A student may forget or exchange a card, equipment must be installed and maintained, and a congested reader may slow a large class. Their suitability depends on whether the institution already operates an appropriate card infrastructure.

### 2.4.2 QR Code and Geofencing

QR codes are inexpensive to generate and easy to scan. Ayop et al. (2018) combined QR codes with GPS and event information to create a location-aware attendance process. A dynamic QR code can expire quickly and is safer than a permanent printed code. It can nevertheless be photographed or transmitted electronically, while GPS accuracy may not separate adjacent indoor rooms.

Nwabuwe et al. (2023) reduced these weaknesses by encoding venue boundaries, changing the QR code, and checking the device identity. The study demonstrates that a visual token becomes more credible when it is combined with context. It also shows the implementation cost of relying on several separate checks and the continuing need to handle legitimate device changes.

### 2.4.3 Biometrics

Biometric attendance associates a record with a physical trait such as a fingerprint or face. Its strength is identity verification rather than proximity signalling. In a controlled installation, biometrics can make credential sharing more difficult. The trade-offs include collection of sensitive personal data, consent and retention policy, camera or sensor quality, environmental lighting, throughput, false rejection, accessibility, and the cost of matching infrastructure.

Face capture was explored during an earlier development iteration of this project but was removed from the active design. Reliable facial comparison would require a validated recognition model, liveness detection, secure biometric-template management, and testing across lighting, camera, pose, and demographic conditions. A basic mobile face detector identifies a face-like region; it does not by itself establish identity. Retaining that experimental feature would have overstated the security of the system and increased privacy risk.

### 2.4.4 GPS and Network Presence

GPS is effective for many outdoor location services, but satellite reception and accuracy are limited indoors. A geofence around a campus building may show that a device is near the venue without proving that it is in a particular classroom. Wi-Fi association can similarly show that a device is connected to a network whose signal reaches the user. Neither observation necessarily establishes exact room presence, especially where an access point serves several rooms.

For these reasons, the implemented project does not accept GPS or Wi-Fi as an attendance proof. They remain useful comparison technologies in the literature, but the active design is limited to acoustic and BLE evidence that is tied to an open session.

### 2.4.5 Bluetooth Attendance

Bluetooth attendance has been studied in both tag-based and smartphone-based forms. Lodha et al. (2015) used Bluetooth Smart electronic tags, while Noguchi et al. (2015) developed a student attendance system using BLE beacons and Android devices. Azmi et al. (2018) proposed the UNITEN Smart Attendance System using BLE beacons and compared it with paper and RFID processes. These studies support the feasibility of BLE for attendance and show that beacons can reduce manual interaction.

Bluetooth avoids the optical line-of-sight requirement of QR scanning and is less affected by audible classroom noise than an acoustic signal. It does not provide a precise room boundary. BLE transmissions may travel through doors or walls, and an identifier may be copied. The technology therefore supports proximity evidence, not automatic proof of presence without additional controls.

## 2.5 Acoustic Communication for Copresence

Acoustic data communication encodes information into a waveform played by a speaker and captured by a microphone. Near-ultrasonic systems operate close to the upper limit of human hearing, typically above the dominant range of speech and music. Their attraction for copresence applications is that ordinary phones already provide the transmitter and receiver.

Getreuer et al. (2018) implemented a near-ultrasonic protocol between consumer devices in the 18.5-20 kHz region. Their design used direct-sequence spread spectrum and short token exchange, and their experiments demonstrated reliable communication at distances that exceeded those obtained by the prototype in this study. This difference is important. The published protocol used a more sophisticated modulation and synchronisation method than the dual-frequency frame used in the project. Its performance cannot be transferred directly to the present implementation.

Jia et al. (2022) combined near-ultrasonic chirps and signal-processing methods for smartphone-based social-distance measurement. The study reinforces the feasibility of acoustic ranging and also illustrates the effort required to handle multipath, non-line-of-sight conditions, channel access, and device timing. An attendance token decoder does not need the same ranging accuracy, but it faces related propagation and hardware constraints.

Near-ultrasonic signalling is not guaranteed to be inaudible on every device. A phone speaker may generate lower-frequency artefacts, and younger users may hear frequencies that others do not. Increasing amplitude may improve reception but can also increase audible distortion and user discomfort. The signal must consequently be tuned within safe device output and tested with the intended hardware.

The acoustic frame in the present system contains a compact session identifier, generation time, and random challenge. It is encoded into a sequence of tones with start and stop guards. On the receiving phone, the microphone samples are filtered and evaluated in windows to distinguish the expected tone pair. A checksum or digest at proof level prevents a changed payload from being accepted as authentic evidence. Physical tests show that the implementation works, but only at very short range under the conditions recorded in Chapter Four.

## 2.6 Bluetooth Low Energy Advertising

BLE is designed for low-energy wireless operation in the 2.4 GHz industrial, scientific, and medical band. An advertiser periodically transmits packets on designated advertising channels, and a scanner listens for nearby advertisements. Attendance discovery does not require a conventional paired connection. This reduces interaction time and makes it possible for several student phones to observe the same lecturer broadcast.

The Android permission model affects practical BLE operation. Applications targeting Android 12 or later require runtime permission for scanning, advertising, or connecting, depending on the operation (Android Developers, n.d.). Older Android versions may also associate BLE scanning with location permission. A missing permission can therefore resemble a radio-range problem. This was observed during project development: BLE reception improved when the required permission was enabled.

The lecturer-device path in the present system advertises a session-specific nonce. The nonce rotates during an open attendance period and carries a generation timestamp. A student submission is accepted only if the nonce belongs to the selected session, remains within the configured freshness window, and has not been improperly reused for that student.

The fixed-beacon path works differently. Commercial room beacons typically broadcast a configured iBeacon or Eddystone identifier repeatedly. They cannot generate a new server nonce for every lecture unless they are reconfigured or connected to an additional controller. The static identifier therefore proves only that a registered beacon was observed. The server supplies the missing context by checking room assignment, current session status, and RSSI policy.

## 2.7 RSSI and Room Beacons

RSSI is a receiver-side estimate of the power of a detected radio signal. A less negative value generally indicates a stronger observation; for example, -50 dBm is stronger than -80 dBm. The relationship between RSSI and distance is not stable enough to infer an exact classroom position without calibration. Ramirez et al. (2021) showed that orientation, three-dimensional arrangement, and environmental complexity affected BLE measurement and positioning accuracy.

Puckdeevongs et al. (2020) used several BLE stations and fingerprinting methods to estimate student positions in real classrooms. Their system demonstrates that useful indoor positioning is possible, but it required fixed stations, measurements, and computational models. The present project adopts a simpler proximity policy: the app records the strongest acceptable evidence, and the backend rejects a registered beacon below its configured RSSI threshold. This reduces obvious weak-signal acceptance without claiming coordinates.

More than one BLE source may be visible. If the room beacon is substantially stronger than the lecturer phone, selecting the beacon better reflects the local observation. If the lecturer signal is stronger, its short-lived nonce offers better freshness. The app therefore compares valid candidates: it selects one source when that source is at least 10 dB stronger and retains both sources when their RSSI values are within the 10 dB margin. This rule is an engineering heuristic derived from project testing, not a universal conversion from RSSI to distance.

Room assignment is equally important. A beacon is stored with its UUID or service identifier, major/minor or namespace/instance values, room, active state, and minimum RSSI. When a student submits beacon evidence, the server resolves the detected identity to one active beacon and one open session for that room. It rejects an unregistered beacon, a room mismatch, a weak observation, or an ambiguous room state.

## 2.8 Attendance Fraud and Security Controls

BLE attendance is vulnerable when a stable beacon message is accepted without additional evidence. Kim et al. (2018) analysed a deployed BLE beacon attendance system and demonstrated signal imitation and forwarding attacks. Their findings show that physical beacons should not be treated as secrets: an advertisement is intentionally observable by nearby devices and may be copied.

The present design uses several controls in response:

1. lecturer acoustic and BLE payloads are short-lived and tied to a session;
2. proof data includes a SHA-256 digest that the backend recomputes;
3. only an authenticated student can submit for the student identity associated with the token;
4. each student may create at most one proof for a session;
5. replay records are scoped to the session and student, allowing classmates to use the same broadcast while preventing improper reuse by one student;
6. a room beacon must be registered, active, assigned to the session room, and observed at an acceptable RSSI;
7. only one open session is permitted for a room at a time; and
8. a student account is associated with one installation identifier unless an administrator performs a controlled reset.

These controls address casual sharing, duplicate submission, stale capture, cross-room beacon use, and simple client tampering. They do not prevent every adversarial scenario. A student could physically carry a friend's registered phone, an advanced attacker could relay a live signal in real time, and an application-generated installation identifier is not hardware-backed proof. Security claims must therefore remain proportional to the implementation and evaluation.

## 2.9 Review of Closely Related Studies

### 2.9.1 Bluetooth Smart Attendance

Lodha et al. (2015) proposed a Bluetooth Smart attendance system using electronic tags and a Bluetooth-enabled device. The system reduced the time and human errors associated with manual attendance and produced records for administrative use. Its reliance on tags differs from the present student-phone scanning model, and the published description does not address a rotating session credential or room-specific replay controls.

### 2.9.2 Android and BLE Beacon Attendance

Noguchi et al. (2015) designed an attendance system using BLE beacons and Android devices. The work is closely related because an Android phone detects a classroom beacon before submitting attendance information. A fixed beacon, however, remains a reusable signal unless the server adds session context. The present project extends this pattern with an open-session requirement, room registration, RSSI policy, a lecturer-generated rotating BLE option, and replay checks.

### 2.9.3 UNITEN Smart Attendance System

Azmi et al. (2018) implemented UniSas with BLE beacons and compared paper, RFID, and beacon attendance using accuracy, time, and energy considerations. The authors reported that their beacon method performed better than the traditional alternatives evaluated. The system provides strong evidence that BLE beacons are practical in university attendance. The present study differs by allowing the lecturer phone and a fixed beacon to act as alternative BLE sources and by documenting the security limitation of a static beacon.

### 2.9.4 BLE Classroom Positioning

Puckdeevongs et al. (2020) combined BLE stations, RSSI fingerprinting, and neural-network methods to record attendance and estimate classroom position. Their real-classroom evaluation showed that BLE can support attendance despite indoor interference, but it also recorded positioning error and required several installed stations. The study supports the use of BLE in a classroom while confirming that robust position estimation is more complex than reading one RSSI value.

### 2.9.5 Proximity-Based IoT Attendance

Hayati and Nugraha (2023) implemented an Android smart attendance application that detected a beacon and communicated with a cloud database. Their field evaluation covered two courses and multiple mobile devices; the authors reported functional-test results of 91.67% and 100%, with one limitation arising from a phone that did not detect the beacon. The architecture is close to the present project and is particularly relevant to Telecommunication Science. It also confirms that handset compatibility can affect beacon systems.

### 2.9.6 Fraud-Aware Mobile Attendance

Nwabuwe et al. (2023) combined dynamic QR codes, geofencing, and IMEI verification. Their evaluation reported successful mitigation of the tested attendance-fraud attempts. Although the signal technologies differ, the study supports dynamic session evidence and one-device controls. The present project substitutes acoustic and BLE proximity for the QR/geofence path and uses an application installation identifier because direct IMEI access is restricted.

### 2.9.7 BLE Signal Imitation

Kim et al. (2018) examined a commercial BLE electronic attendance system and found that predictable, static beacon messages could be imitated and forwarded. This is the most important security-related prior work for the beacon path. The result explains why the CP27 identifier is never treated as a session secret and why server-side room, time, account, and duplicate rules are required.

### 2.9.8 Acoustic Copresence

Getreuer et al. (2018) developed a near-ultrasonic token protocol on consumer hardware, while Jia et al. (2022) developed smartphone near-ultrasonic ranging. Neither paper presents a classroom attendance application, but both establish that phones can exchange or measure high-frequency acoustic signals. Their methods also show that modulation, synchronisation, coding, multipath handling, and hardware response determine range. The present project's simpler acoustic implementation is therefore evaluated independently rather than assumed to reproduce their performance.

## 2.10 Comparative Analysis

**Table 2.1: Comparison of Closely Related Studies**

| Study | Principal technology | Reported contribution or result | Limitation relevant to this project |
| --- | --- | --- | --- |
| Lodha et al. (2015) | Bluetooth Smart tags | Reduced manual attendance time and human error | Requires electronic tags; limited discussion of rotating proof and fraud controls |
| Noguchi et al. (2015) | BLE beacon and Android | Classroom beacon detection and mobile attendance submission | Static beacon context can be reused unless constrained by session rules |
| Azmi et al. (2018) | BLE beacon | UniSas implementation; reported better evaluated performance than paper and RFID alternatives | Beacon-centric design; static-signal security not the main focus |
| Kim et al. (2018) | BLE security analysis | Demonstrated imitation and forwarding against a deployed attendance system | Analyses attack rather than implementing this project's combined workflow |
| Puckdeevongs et al. (2020) | Multiple BLE stations and RSSI fingerprinting | Real-classroom attendance and indoor-positioning evaluation | Requires fixed infrastructure, calibration, and positioning models |
| Hayati and Nugraha (2023) | Android, beacon, cloud database | Field-tested proximity attendance across two courses; 91.67% and 100% functional results reported | One device failed to perceive the beacon; no acoustic alternative |
| Nwabuwe et al. (2023) | Dynamic QR, geofence, IMEI | Combined dynamic proof, location, and device checks to mitigate tested fraud cases | GPS/geofence does not reliably separate indoor rooms; IMEI access is restricted |
| Getreuer et al. (2018) | Near-ultrasonic communication | Demonstrated robust short-token communication on consumer hardware | Not an attendance system; uses a more advanced protocol than this prototype |
| Jia et al. (2022) | Near-ultrasonic ranging | Demonstrated smartphone acoustic proximity measurement | Ranging algorithm and test objective differ from attendance-token decoding |
| Present study | Acoustic token, lecturer BLE, registered room beacon, Django validation | Combines alternative physical-signal paths, room-aware beacon validation, device binding, replay control, reporting, and hosted access | Small four-device evaluation; acoustic range is very short; multi-room scale remains unproven |

## 2.11 Research Gap

The literature establishes several individual capabilities: Bluetooth can reduce attendance time; Android phones can detect classroom beacons; BLE stations can support indoor positioning; near-ultrasonic signals can exchange short tokens; and dynamic credentials, location, or device checks can reduce selected forms of fraud. It also identifies a serious weakness: a static BLE attendance signal can be copied or forwarded.

Within the reviewed work, the remaining practical gap is not the absence of another attendance interface. It is the need for a modest, deployable system that combines:

1. a rotating lecturer-device signal for freshness;
2. a fixed room beacon for coverage where required;
3. an independent acoustic path for close-range copresence;
4. room-aware server validation rather than unconditional beacon acceptance;
5. proof integrity, duplicate, replay, and device-association controls; and
6. complete lecturer and student workflows with session-specific reporting.

The implemented study addresses this gap through alternative acoustic and BLE proof paths rather than requiring both signals for every submission. This choice reflects observed reliability: BLE is the main classroom mechanism, while acoustic evidence is retained for very short-range use. The contribution is the integration and validation policy, not a claim that the underlying radio or acoustic technologies are new.

## 2.12 Summary

The reviewed literature shows that electronic attendance can improve speed and record management, but each technology has a different evidential limit. RFID and NFC depend on credentials and readers; QR codes can be shared; GPS and network presence are weak at room level; biometrics introduce privacy and operational concerns; BLE offers useful classroom reach but can be variable, copied, or relayed; and acoustic communication depends strongly on coding, hardware, distance, and noise.

The literature supports a design in which BLE provides practical proximity coverage, acoustic signalling provides supplementary copresence evidence, and the backend evaluates every proof within an authenticated student, open session, room, time, and device context. Chapter Three explains how those principles were translated into the implemented architecture.
