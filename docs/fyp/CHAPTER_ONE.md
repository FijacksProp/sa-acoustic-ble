# Chapter One: Introduction

## 1.1 Background of the Study

Attendance records are used in universities to document participation in scheduled academic activities and to support course administration. In many classrooms, however, attendance is still recorded through roll call, signature sheets, or paper registers. These methods are easy to understand, but they consume lecture time, require manual compilation, and are difficult to audit. They also permit proxy attendance when one student answers or signs for an absent colleague.

Digital attendance systems have been developed to reduce these weaknesses. The technologies reported in the literature include radio-frequency identification (RFID), near-field communication (NFC), quick-response (QR) codes, biometrics, geofencing, Bluetooth, and mobile applications (Rashid, 2024). Such systems can improve the speed of attendance capture and simplify reporting, but digitisation alone does not establish physical presence. For example, a card may be exchanged, a static QR code may be forwarded, or valid account credentials may be used on behalf of another student. Miao et al. (2020) addressed attendance fraud within an RFID system, while Nwabuwe et al. (2023) combined dynamic QR codes, geofencing, and device identity to reduce several forms of proxy attendance. These studies show that identity, time, location or proximity, and replay controls must be considered together.

The widespread availability of smartphones creates an opportunity to perform attendance verification with hardware already carried by lecturers and students. A typical Android smartphone provides a loudspeaker, microphone, Bluetooth radio, network interface, local application storage, and runtime security controls. These facilities can support short-range signal transmission, proximity sensing, authentication, and communication with a remote validation service. The project is therefore relevant to Telecommunication Science because it applies signal generation, reception, wireless propagation, data encoding, proximity estimation, and networked service delivery to an educational problem.

Bluetooth Low Energy (BLE) is suited to nearby-device discovery because an advertiser can transmit small packets that nearby scanners receive without conventional pairing. Earlier attendance implementations used Bluetooth Smart or BLE beacons to reduce manual attendance effort (Azmi et al., 2018; Lodha et al., 2015; Noguchi et al., 2015). Puckdeevongs et al. (2020) further demonstrated a BLE classroom attendance and positioning framework. BLE signal strength is nevertheless affected by distance, antenna orientation, obstacles, phone hardware, interference, and indoor multipath. Ramirez et al. (2021) found that RSSI-based estimates varied with measurement geometry and environmental complexity. RSSI is consequently treated in this project as approximate proximity evidence rather than an exact distance measurement.

Acoustic communication provides a second proximity channel. Getreuer et al. (2018) demonstrated that commodity smartphone speakers and microphones could exchange short tokens in a near-ultrasonic band. Jia et al. (2022) also used smartphone near-ultrasonic signals for proximity measurement. These studies establish the feasibility of acoustic signalling with consumer devices, but they do not imply identical performance on every handset or in every room. Speaker response, microphone sensitivity, background noise, frequency attenuation, and placement all influence reception. The acoustic channel in this project is therefore used as a supplementary, very-short-range proof of copresence rather than as the principal full-room mechanism.

The system developed in this study combines a Flutter Android application with a Django REST backend. A lecturer creates a class session, selects a registered room, opens attendance, and starts a foreground broadcast service. The service rotates a short-lived acoustic token and lecturer-device BLE nonce while attendance remains open. A student scans for valid evidence and submits a proof to the hosted backend. The backend accepts either a valid acoustic proof, a current lecturer-device BLE proof, or evidence from a registered BLE beacon assigned to the session room.

A fixed room beacon, such as the DX-CP27 used during development, broadcasts a stable identifier rather than a newly generated session nonce. It is therefore not accepted by identity alone. The backend confirms that the beacon is registered and active, belongs to the room selected for the session, satisfies the configured minimum RSSI rule, and corresponds to an attendance session that is currently open in that room. This room-aware rule allows lecturer-device BLE and fixed beacon coverage to coexist without treating every detectable beacon as valid attendance evidence.

Attendance acceptance is decided by the backend rather than by the scan interface alone. The validation process checks authenticated identity, session status, student and device association, proof format, cryptographic digest, signal freshness where applicable, beacon-room association, RSSI policy, duplicate attendance, and replay use. The design responds to evidence that a static BLE beacon signal can be imitated or forwarded (Kim et al., 2018). It does not claim to eliminate every form of attendance fraud; instead, it combines independent controls to make casual proxy attendance and stale-proof reuse more difficult while retaining a fast classroom workflow.

## 1.2 Statement of the Problem

Manual attendance in higher institutions consumes time that could be used for teaching and produces records that require additional processing. Passing a register through a large class or calling every name may interrupt the lecture, yet neither method reliably prevents one student from responding or signing for another. Paper records can also be misplaced, altered, damaged, or compiled incorrectly.

Some digital alternatives solve the record-keeping problem without adequately solving the presence problem. A static form or QR code can be shared outside the classroom. RFID and NFC systems require tags or readers and may still authenticate the object rather than the person carrying it. Biometric systems strengthen identity verification but introduce equipment, privacy, environmental, and throughput concerns. GPS-based methods can support geofencing but are not consistently precise within indoor rooms. BLE-based attendance offers practical coverage, but a reusable beacon identifier can be copied or relayed if it is accepted without session and server controls (Kim et al., 2018).

The problem addressed by this study is therefore the absence of a practical smartphone-based attendance process that combines rapid capture with evidence of classroom proximity and server-side fraud controls. The proposed solution must identify the student and active class session, accept evidence only through an authorised acoustic or BLE path, reject duplicate and stale submissions, distinguish registered room beacons from unrelated BLE devices, and maintain records that lecturers can review and export. It must also reflect the measured limitations of the prototype: the present acoustic implementation is reliable only at very short range, whereas BLE provides the main useful classroom coverage.

## 1.3 Aim and Objectives of the Study

The aim of this study is to design and implement a smart attendance system that uses acoustic and Bluetooth Low Energy proximity verification with server-side validation for classroom attendance management.

The specific objectives are to:

1. design a mobile attendance system through which lecturers can create class sessions, select registered rooms, open attendance, and manage attendance records;
2. implement acoustic and BLE proximity verification, using acoustic proof as very-short-range copresence evidence and BLE proof from either a lecturer-device advertisement or a registered room beacon;
3. develop a backend validation process that verifies session identity, proof integrity and freshness, beacon-room association, RSSI policy, duplicate prevention, replay protection, and student device binding;
4. provide lecturer and student interfaces for signal broadcasting, scanning, proof submission, attendance history, session reports, profile information, permission guidance, and CSV export; and
5. evaluate the implemented system on Android devices under different distance, noise, obstacle, permission, hosting, and beacon conditions.

## 1.4 Research Questions

The study addresses the following questions:

1. How can acoustic beaconing and BLE advertisements be used to support smartphone-based classroom attendance?
2. How can lecturer-device BLE and registered room beacons coexist without accepting evidence from an unrelated room?
3. Which server-side controls can reduce duplicate attendance, stale-proof reuse, replay, and casual account sharing?
4. What practical limitations affect acoustic and BLE reception on the tested Android devices?
5. How effectively does the implemented workflow support session creation, scanning, proof submission, reporting, and export during small-scale testing?

## 1.5 Scope of the Study

The study covers the design, implementation, and small-scale evaluation of an Android smart attendance system. Its software components are a Flutter mobile application, native Android acoustic and BLE modules, and a Django REST backend hosted on Render with a PostgreSQL database. SQLite remains available for local development. The application provides separate lecturer and student workflows, while the Django administration interface supports controlled management and inspection of users, sessions, beacons, proofs, and replay records.

The lecturer workflow includes authentication, session creation, room selection, attendance opening and closure, background acoustic and BLE broadcasting, live-session management, session-specific validation reports, search, and CSV export. The student workflow includes authentication, device registration, permission checks, concurrent acoustic and BLE scanning, proof review, one-time submission, attendance history, and profile information.

Three proof sources are within scope:

1. a short-lived acoustic token transmitted by the lecturer phone;
2. a short-lived BLE nonce advertised by the lecturer phone; and
3. a static registered room-beacon identifier validated against an open session, room assignment, and RSSI rule.

The implementation focuses on Android because the acoustic decoder, BLE advertiser, foreground service, wake lock, and runtime permissions use Android-specific facilities. An iOS version is outside the completed implementation. The active attendance paths are limited to acoustic and BLE evidence.

The system verifies proximity evidence; it does not claim precise indoor positioning or conclusive biometric identity. BLE RSSI is not converted into an exact distance, and the application-generated device identifier is a device-trust control rather than hardware-backed attestation. Institutional-scale load testing, multi-room field trials, formal penetration testing, and accessibility studies are beyond the completed small-scale evaluation.

## 1.6 Significance of the Study

The study demonstrates how telecommunication and mobile-computing principles can be applied to an administrative problem in higher education. It combines acoustic signal encoding and decoding, BLE advertising and scanning, signal-strength policy, mobile networking, a hosted validation service, and database reporting in one working system.

For lecturers, the system reduces the steps required to collect and compile attendance and produces a report tied to the selected class session. For students, attendance can be submitted from a personal Android device without paper, a contact-based biometric reader, or conventional Bluetooth pairing. For administrators, the backend provides auditable records, registered room-beacon management, duplicate controls, device-binding information, and controlled device-reset actions.

The project also provides evidence for choosing between the two signal paths. Its four-device evaluation shows that the present acoustic design is useful only at close range, while BLE is the stronger operational mechanism. This result is important because it avoids presenting a technically novel acoustic feature as more reliable than the measured evidence supports. The fixed-beacon design offers a route to improved room coverage, while the room and session checks reduce the risk of accepting every beacon detected nearby.

Finally, the implementation provides a foundation for further research on room-specific BLE deployment, acoustic coding for noisy classrooms, risk-based device replacement, large-class concurrency, and proximity-aware educational services.

## 1.7 Methodology Overview

An iterative Agile approach was adopted because the project contained interacting mobile, signal-processing, backend, security, deployment, and interface components. Agile development emphasises working software and response to change (Beck et al., 2001). In this project, each increment was tested on physical Android devices and revised when field behaviour differed from the initial assumption.

Development began with authentication, session management, and a basic mobile workflow. Acoustic transmission and decoding were then implemented through native Android code, followed by lecturer-device BLE advertising and student BLE scanning. Device binding, duplicate prevention, replay records, reports, export, hosted deployment, registered room beacons, signal-source selection, runtime permission guidance, foreground broadcasting, and interface refinement were added in later iterations.

The final verification combined automated and physical tests. The backend API suite exercised authentication, authorisation, proof integrity, multiple-student use of a shared classroom nonce, duplicate prevention, replay scope, compact acoustic proof, beacon-room validation, RSSI rules, device uniqueness, profile privacy, and token revocation. Flutter tests covered authentication rendering, small-screen layouts, and preservation of the installation identifier after logout. Native Android compilation verified the foreground service and Kotlin signal modules. Physical tests used a Redmi 13C as the principal lecturer phone and a POCO C71, Samsung A05, and Vivo Y33 as student phones.

Chapter Three describes the architecture, requirements, proof construction, validation pipeline, database design, and development process in detail.

## 1.8 Limitations of the Study

The physical evaluation involved four Android phones and repeated small-scale trials rather than a full class. The results therefore demonstrate feasibility on the tested devices but do not establish performance across all Android manufacturers, operating-system versions, room types, or class sizes.

Acoustic decoding is affected by speaker output, microphone response, phone placement, background noise, and high-frequency attenuation. In the observed tests, useful reception was generally limited to approximately 1-30 cm, with a best observed distance slightly above 50 cm in a quiet environment at high volume. The acoustic path cannot presently cover a medium or large classroom.

BLE provided substantially better coverage, including detections above 10 m, but RSSI remained variable and cannot prove an exact physical distance. Radio signals may also cross a wall or reach an adjacent room. The system mitigates this limitation with room assignment, session status, beacon registration, source freshness, and an RSSI threshold; these controls reduce ambiguity but cannot eliminate relay attacks or every adjacent-room condition.

The installed DX-CP27 beacon was detectable, but lecturer-device BLE was selected more often during the reported tests. Formal tests of multiple beacons, adjacent active rooms, beacon placement, crowd absorption, and simultaneous sessions remain limited. Device binding discourages use of one phone for several student accounts, but it cannot prove that the registered owner is the person carrying the phone.

The backend runs on a free hosted service during development and may require approximately one to two minutes to wake after inactivity. A free service is suitable for development and demonstration but does not provide the availability, monitoring, backup, and support expected of an institution-wide production deployment.

## 1.9 Organization of the Study

The report is organised into five chapters. Chapter One presents the background, problem, aim, objectives, research questions, scope, significance, methodology overview, and limitations. Chapter Two reviews manual and automated attendance methods, acoustic communication, BLE proximity, related attendance systems, and fraud controls. Chapter Three explains the development method, requirements, architecture, proof formats, backend validation, database, user workflows, and implementation tools. Chapter Four presents implementation evidence, automated verification, physical test conditions, results, and discussion. Chapter Five summarises the work, states the conclusions, identifies contributions and limitations, and presents recommendations for deployment and further research.
