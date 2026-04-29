# Chapter One: Introduction

## 1.1 Background of the Study

Attendance monitoring is an important administrative and academic activity in higher institutions because it provides evidence of student participation, supports course administration, and contributes to accountability in teaching and learning environments. In many university classrooms, attendance is still recorded through manual signing, roll call, or paper-based registers. Although these methods are simple to deploy, they are often slow, difficult to audit, and vulnerable to proxy attendance, where one student signs or responds on behalf of another. The challenge becomes more obvious in large classes where the lecturer has limited time to verify each student physically.

Several automated attendance systems have been introduced to reduce the weaknesses of manual attendance. These include barcode and QR code systems, radio frequency identification (RFID), near-field communication (NFC), fingerprint biometrics, facial recognition, and mobile application-based systems. RFID and biometric systems can reduce manual effort, but they may require dedicated hardware, installation cost, or physical contact with a reader. QR code systems are easy to implement but can be photographed or forwarded to absent students if the design does not include strong proximity control. Earlier attendance research has shown that automated identification technologies can improve attendance collection, but the problem of confirming that the student is physically present in the classroom still requires careful system design (Wahab et al., 2009).

The growth of smartphone technology and short-range wireless communication provides an opportunity to design attendance systems that use the sensors and radios already available on students' devices. Modern smartphones contain microphones, speakers, Bluetooth radios, and network interfaces, making them suitable for mobile proximity verification. In telecommunication science, this kind of system is relevant because it applies signal transmission, wireless propagation, proximity sensing, data encoding, and network-based validation to solve a practical educational problem.

Bluetooth Low Energy (BLE) is a low-power wireless communication technology designed for short-range discovery and data exchange. BLE advertisements can be used to broadcast small data packets without requiring devices to pair or maintain a full connection. Received Signal Strength Indicator (RSSI) values can also provide approximate information about signal strength and proximity, although RSSI is affected by distance, phone orientation, obstacles, and indoor multipath effects (Ramirez et al., 2021). This makes BLE useful for classroom-level proximity detection, but it should be combined with careful freshness and replay checks to reduce misuse.

Acoustic communication provides another proximity channel. Research on near-ultrasonic communication has shown that commodity speakers and microphones can transmit short tokens in high-frequency bands near or above the range of normal human hearing (Getreuer et al., 2018). Smartphone-based near-ultrasonic techniques have also been studied for proximity and social-distance detection, showing that sound-based signals can support short-range device-to-device identification under suitable conditions (Jia et al., 2022). However, acoustic communication is sensitive to background noise, speaker quality, microphone response, room acoustics, and distance.

This project therefore proposes a smart attendance system that uses two proximity verification channels: an acoustic beacon and BLE proximity signal. The lecturer's mobile device broadcasts a session-specific attendance signal, while the student's device scans for the acoustic or BLE signal and submits proof to a backend server. The backend validates the proof based on session identity, freshness, replay protection, and duplicate prevention. This dual-channel approach is intended to improve attendance reliability compared with systems that rely only on manual signing, static QR codes, or a single sensing method.

## 1.2 Statement of the Problem

Manual attendance systems in higher institutions are time-consuming and prone to manipulation. In a large classroom, taking attendance by passing paper sheets or calling names can reduce lecture time and may still fail to confirm the actual presence of every student. Students may sign for absent colleagues, and paper records can be misplaced, damaged, or difficult to process.

Digital attendance systems such as QR code or online forms reduce paperwork but may still be vulnerable if a code or link can be shared outside the classroom. Biometric systems can improve identity verification, but they often require additional hardware, raise privacy concerns, and may introduce operational difficulties in large classes. RFID and NFC systems also require readers or tags, which can increase deployment cost and maintenance requirements.

The problem addressed by this project is the need for a practical attendance system that can verify student presence in a classroom using available smartphone capabilities, while reducing proxy attendance, duplicate submission, and replay of old attendance signals. The system must be usable in an academic environment, relevant to telecommunication science, and capable of validating attendance proofs through proximity-based signals rather than static codes alone.

## 1.3 Aim and Objectives of the Study

The aim of this project is to design and implement a smart attendance system using acoustic beacon and Bluetooth Low Energy proximity verification for classroom attendance management.

The specific objectives are to:

1. Design a mobile-based attendance system that allows a lecturer to create and broadcast a session-specific attendance signal.
2. Implement an acoustic beacon mechanism that transmits a short attendance token using the lecturer device speaker and receives it through the student device microphone.
3. Implement BLE proximity verification that allows a lecturer device to advertise a short-lived session nonce and allows student devices to scan for it.
4. Develop a backend server that validates submitted attendance proofs using session identity, freshness, duplicate prevention, and replay protection.
5. Provide student and lecturer interfaces for session creation, signal scanning, proof submission, attendance history, validation reports, and CSV export.
6. Evaluate the system using real Android devices under different signal conditions, distances, and classroom-like scenarios.

## 1.4 Research Questions

This study is guided by the following research questions:

1. How can acoustic beaconing and BLE proximity be combined to verify classroom attendance using smartphones?
2. How can attendance proofs be designed to reduce duplicate submissions, stale signal reuse, and proxy attendance?
3. What backend validation mechanisms are required to confirm that an attendance signal belongs to an active session?
4. What are the practical limitations of acoustic and BLE proximity verification in a classroom environment?
5. How usable is the proposed system for lecturers and students during session creation, scanning, submission, and report generation?

## 1.5 Scope of the Study

The scope of this project is limited to the design and implementation of a smart attendance system for higher institution classroom use. The system consists of a backend server, a mobile application, acoustic signal transmission and reception, BLE advertising and scanning, proof submission, duplicate prevention, and attendance reporting.

The mobile implementation focuses on Android devices because the acoustic and BLE signal features require native platform access. The backend provides authentication, session management, attendance proof submission, validation reporting, and CSV export support. The system accepts attendance through either acoustic verification, BLE verification, or both where available.

The project does not implement facial recognition or biometric verification as part of the main system. It also does not claim perfect indoor positioning, because BLE RSSI and acoustic signal reception can be affected by device hardware, distance, noise, phone orientation, and room conditions. These limitations will be considered during testing and evaluation.

## 1.6 Significance of the Study

This project is significant because it applies telecommunication and mobile computing concepts to a practical academic problem. By using acoustic and BLE signals, the system demonstrates how short-range communication channels can be used for proximity-based attendance verification. The work is relevant to telecommunication science because it involves signal generation, signal detection, wireless broadcasting, proximity estimation, mobile networking, and server-side validation.

For lecturers, the system can reduce the time spent collecting attendance and provide a cleaner digital report for each class session. For students, the system provides a mobile-based attendance process that does not require paper signing or additional cards. For the department and institution, the system offers a foundation for improving attendance accountability using technologies that are already available on many smartphones.

The study may also contribute to future research on proximity-aware academic systems, BLE-based classroom services, acoustic token transmission, and fraud-resistant mobile attendance platforms.

## 1.7 Methodology Overview

The project follows an Agile and iterative development approach. Agile methodology is suitable for this project because the system includes several interacting components that require gradual design, implementation, testing, and refinement. The backend, mobile user interface, acoustic beacon, BLE proximity feature, validation report, and CSV export were developed in phases, with each phase tested and improved based on practical results from real devices.

The system was implemented using a Django-based backend for authentication, session management, proof validation, and report generation. The mobile application was developed using Flutter, while Android native code was used for acoustic signal transmission, microphone-based decoding, BLE advertising, and BLE scanning. Attendance proof validation is performed on the backend to ensure that submitted signals belong to active sessions and have not already been used.

Further details of the methodology, system architecture, database design, and development tools will be presented in Chapter Three.

## 1.8 Limitations of the Study

The current system depends on smartphone hardware capability. Acoustic performance is affected by speaker quality, microphone sensitivity, classroom noise, signal frequency, and distance. BLE performance is affected by phone hardware, Bluetooth permissions, Android version, device orientation, RSSI variation, and obstacles in the environment. Therefore, the system is designed as a proximity verification system rather than a precise indoor positioning system.

The project currently focuses on Android devices. iOS implementation would require additional native development and platform-specific testing. The final range and reliability values will depend on experimental testing across several devices and classroom environments.

## 1.9 Organization of the Study

This project is organized into five chapters. Chapter One introduces the study, including the background, problem statement, aim and objectives, research questions, scope, significance, methodology overview, and limitations. Chapter Two reviews related literature on attendance systems, RFID, QR code systems, biometric attendance, BLE proximity, and acoustic communication. Chapter Three presents the system analysis and design, including architecture, methodology, data flow, database design, and proof validation model. Chapter Four discusses implementation, testing, results, and evaluation of the developed system. Chapter Five presents the summary, conclusion, recommendations, and possible future improvements.

