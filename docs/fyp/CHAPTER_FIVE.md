# Chapter Five: Summary, Conclusion and Recommendations

## 5.1 Summary of the Study

This study addressed the need for a faster and more accountable classroom attendance process in higher education. Manual roll call and paper registers consume lecture time, require later compilation, and can permit proxy attendance. Basic digital forms improve storage but do not establish that the authenticated device observed evidence associated with the classroom.

The project designed and implemented a smart attendance system that combines an Android application, acoustic communication, Bluetooth Low Energy proximity evidence, and a hosted Django validation service. The lecturer creates a course session, selects a room, opens attendance, and starts rotating acoustic and BLE signals. A student scans for a valid signal and submits a proof. A fixed DX-CP27 beacon may also provide registered room evidence.

The server determines whether attendance is accepted. It checks the authenticated identity, session owner and state, attendance window, signal format, session match, proof time, cryptographic digest, room-beacon registration, RSSI rule, device association, duplicate record, and student-scoped replay record. This arrangement prevents the mobile interface from declaring attendance without server approval.

The project followed an iterative Agile process. Acoustic, lecturer BLE, fixed-beacon support, device binding, reporting, hosted deployment, permission guidance, and interface refinements were added and revised through physical-device use.

Verification combined 15 backend API tests, four Flutter tests, Django checks, native Android compilation, and small-scale physical testing with a Redmi 13C, POCO C71, Samsung A05, and Vivo Y33. The physical tests covered acoustic and BLE reception, estimated distance groups, common obstacles, Android permissions, CP27 detection, hosted connectivity, proof submission, and reporting.

## 5.2 Achievement of the Objectives

The first objective was to design a mobile attendance system through which a lecturer could create sessions, select rooms, open attendance, and manage records. This objective was achieved. The lecturer portal supports owned-session management, live attendance, search, session-specific reporting, permanent deletion, and CSV export.

The second objective was to implement acoustic and BLE proximity verification. Both channels were implemented on Android. The lecturer phone transmits compact acoustic frames and rotating BLE service data. The student app captures both channels concurrently and also parses registered iBeacon and Eddystone UID frames. The acoustic mechanism is functional at close range; lecturer BLE provides the principal measured coverage.

The third objective was to develop server-side validation for integrity, freshness, room, RSSI, duplicate, replay, and device controls. The Django API and database implement these rules. Automated tests verified the critical authorisation, identity, digest, duplicate, replay, beacon, and device-uniqueness cases.

The fourth objective was to provide role-appropriate interfaces. Lecturer and student portals, permission guidance, scan feedback, history, reports, profile/device information, search, expandable student rows, and CSV export were implemented. Mobile viewport tests completed without layout overflow for the tested student and lecturer screens.

The fifth objective was to evaluate the system on real Android devices under different conditions. A small-scale four-device evaluation was completed. It established functional acoustic transfer at very close range and lecturer BLE detection across the estimated distance groups. The objective was achieved within the declared prototype scope, but the evaluation is not broad enough to support institution-wide performance claims.

## 5.3 Major Findings

The first finding is that BLE is the most practical proximity channel in the present implementation. Each of the three student phones detected the lecturer advertisement at estimated ranges of 1-5 m, 5-10 m, and above 10 m under the tested conditions. BLE also remained detectable through several ordinary indoor obstacles.

The second finding is that the acoustic design works but does not provide classroom-wide range. Reception was generally observed between approximately 1 and 30 cm. A distance slightly above 50 cm was reached in the best reported quiet and high-volume condition. Noise, placement, loudness, speaker response, and microphone sensitivity affected decoding. Acoustic proof is consequently retained as supplementary close-range evidence.

The third finding is that a commercial fixed beacon can be integrated without becoming the session authority. The CP27 frame was detected and registered to a room. Its static identity is accepted only when a session is open in that room and the RSSI rule is satisfied. This avoids treating a powered beacon as permanent attendance permission.

The fourth finding is that permission handling can be mistaken for radio performance. BLE range improved materially after the required Android location-related permission was enabled. Bluetooth state and permission guidance are therefore part of the operational design, not merely interface details.

The fifth finding is that fraud controls must be scoped correctly. A classroom nonce is intentionally shared among students, so global nonce uniqueness would reject legitimate classmates. Student-scoped replay rules allow independent submissions while preventing the same student from reusing the signal. Device binding prevents one installation identifier from being assigned to several student accounts but cannot prove who is physically holding the registered phone.

The sixth finding is that hosting improves repeatability of the installed application. The Render deployment removed dependence on USB and a changing local IP address. Its free-tier cold start of approximately one to two minutes remains an availability limitation.

## 5.4 Conclusion

The study concludes that a BLE-centred, server-validated attendance system is feasible on the tested Android devices. The completed prototype supports the full path from lecturer session creation to student signal capture, server validation, session-specific reporting, and export. It offers stronger evidence than a static online form because acceptance requires an authenticated student, an open lecturer-owned session, and an authorised physical-signal path.

Lecturer-device BLE currently provides the best balance of coverage, speed, and reliance on equipment already available in the phones. A registered room beacon can extend or stabilise coverage, particularly when its location and RSSI policy are configured for the room. Neither signal should be treated as exact positioning. BLE propagation beyond a wall and the possibility of imitation or relay require contextual server controls.

The acoustic channel demonstrates a second telecommunication path and provides close-range copresence evidence. Its measured range is too short and noise-sensitive for use as the sole mechanism in a normal medium or large class. Retaining it as an alternative rather than a mandatory second signal prevents the weakest channel from reducing overall availability.

The system reduces several common forms of misuse through identity matching, installation binding, signal rotation, digest comparison, room registration, duplicate prevention, replay records, and lecturer ownership. It does not eliminate collusion, live relay, or use of another person's registered phone. The prototype should therefore be described as fraud-aware rather than fraud-proof.

Within the stated four-device and small-scale scope, the project achieved its aim. It is suitable for academic demonstration and structured pilot testing. Wider deployment would require quantitative field trials, production hosting, operational policy, stronger device assurance where available, and institutional review of privacy and exception handling.

## 5.5 Contributions of the Study

The main technical contribution is the integration of three alternative proximity observations within one attendance-validation workflow:

1. a compact rotating acoustic token;
2. a rotating lecturer-device BLE nonce; and
3. a static registered room-beacon identity constrained by session and room context.

The study also contributes a practical BLE source-selection method. The scanner compares lecturer and beacon RSSI observations, selects one source when it is at least 10 dB stronger, and retains both when their values are within the margin. This makes beacon use responsive to the observed signal rather than applying an unconditional lecturer-first preference.

A further contribution is the student-scoped replay model. It recognises that a broadcast is shared public classroom evidence and that many authenticated students must be able to submit the same current nonce. Replay prevention is applied to one student and session rather than incorrectly consuming the signal globally.

The room-aware beacon design contributes an operational method for nearby classrooms. A beacon has a registered room and cannot resolve attendance unless one unexpired session is open in that room. Only one session may be open for the room at a time. These rules reduce ambiguity without requiring the beacon itself to receive a new lecture schedule.

From a Telecommunication Science perspective, the implementation demonstrates applied acoustic modulation, frequency-selective filtering, BLE advertising, RSSI interpretation, indoor propagation effects, mobile-network communication, and layered validation. The study also documents the difference between theoretical feasibility and measured performance on consumer hardware.

## 5.6 Limitations

The study is limited by the size and formality of its evaluation. Four Android phones cannot represent the full range of speakers, microphones, Bluetooth radios, antenna layouts, firmware, and power-management policies. Physical distances were estimated, trial counts were not fixed, and noise and sound pressure were not measured.

The acoustic frame is not sufficiently robust for room-wide use. Its two-tone design, 12 ms bit windows, and simple checksum provide a functional prototype but less coding gain and error correction than established ultrasonic communication protocols.

BLE RSSI is an approximate and device-dependent observation. The configured minimum RSSI can reject very weak signals but cannot draw a precise geometric boundary around a classroom. Multiple rooms, crowds, interference, phone orientation, and real-time relay require further evaluation.

The DX-CP27 was integrated but not tested across a full multi-beacon deployment. The current findings do not establish the number or placement of beacons required for a large lecture theatre.

The installation identifier is generated and stored by the application. It is useful for continuity and account/device policy but is not hardware-backed attestation. A legitimate device replacement also requires an administrative reset process.

The free hosted service provides no institutional availability guarantee. The implementation has not undergone formal penetration testing, high-volume load testing, disaster-recovery testing, accessibility evaluation, iOS implementation, or long-term operational assessment.

## 5.7 Recommendations

BLE should remain the principal proximity mechanism for the present version. Lecturer-device advertising avoids immediate infrastructure cost, while registered room beacons should be introduced only where measured room coverage justifies them.

Each deployed beacon should have an inventory record containing its room, format, UUID or namespace, major/minor or instance value, transmit power, advertising interval, mounting position, installation date, and minimum RSSI policy. Beacon values should not be treated as confidential credentials.

The acoustic path should remain optional while its receiver is improved. Any redesign should be compared through fixed trial counts at measured distances and noise levels. More robust synchronisation, forward-error correction, coding gain, and device calibration are preferable to simply increasing volume.

The next field evaluation should record device model, Android version, room dimensions, phone orientation, obstruction, distance, RSSI, signal source, scan duration, submission outcome, and elapsed time. A fixed number of attempts per condition would support detection rate, false rejection, and confidence intervals.

Adjacent-room tests should open simultaneous lecturer sessions and operate multiple registered beacons. A successful evaluation should demonstrate that a student in one room does not resolve or submit against the other room merely because its BLE signal is detectable.

Device changes should require a documented recovery process. An administrator should verify the student's identity and reason, reset the old binding, and retain an audit entry. Automatic unrestricted re-binding would defeat the one-installation rule.

Institutional deployment should use a paid, monitored hosting service or managed university infrastructure with PostgreSQL backups, HTTPS, secret rotation, health monitoring, audit logging, rate limiting, availability targets, and tested recovery procedures.

Attendance records should remain subject to human review. A technical rejection caused by a dead phone, denied permission, inaccessible hardware, or signal interference should have a controlled exception process rather than automatically becoming an academic penalty.

## 5.8 Suggestions for Further Work

Further acoustic research may compare binary frequency-shift keying with chirp spread spectrum or direct-sequence methods, investigate adaptive thresholds, and add stronger error detection or correction. Testing should include spectral measurements and user audibility at the selected frequencies.

BLE work should evaluate calibrated RSSI policies for different rooms and handset groups. Multiple observations over a scan period may be filtered to reduce a single transient reading. Beacon-only, lecturer-only, and combined-source trials should be reported separately.

An offline-first extension could queue an already captured proof during a brief network interruption. Such a queue would need protected local storage, server-signed session material, strict expiry, and replay-safe synchronisation; otherwise, offline support could weaken freshness.

Stronger Android device assurance may be investigated through platform attestation and signed server challenges. This would raise implementation complexity and still would not prove that the registered student is carrying the phone.

An iOS client may be developed after the Android workflow is stable. Background BLE advertising, audio capture, and operating-system restrictions would need an independent design and evaluation rather than a direct assumption of parity.

Finally, a controlled pilot with a complete class should measure simultaneous submissions, lecturer workload, student completion time, error recovery, report accuracy, and perceived usability over several sessions. Those data would determine whether the prototype is suitable for departmental adoption.
