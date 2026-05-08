# Chapter Two: Literature Review

## 2.1 Introduction

This chapter reviews literature relevant to the design and implementation of a smart attendance system using acoustic and Bluetooth Low Energy (BLE) proximity verification. The review covers attendance management systems, smart attendance technologies, mobile-based verification, proximity-aware systems, acoustic communication, BLE proximity, and anti-fraud considerations in digital attendance systems. The purpose is to establish the academic and technical foundation for the proposed system and to identify the gap that the project addresses.

Attendance monitoring is a common administrative requirement in universities because it provides evidence of student participation and supports academic accountability. However, the method used to capture attendance affects speed, accuracy, convenience, privacy, and resistance to fraud. Earlier approaches such as manual roll call and paper registers are simple, but they are slow and vulnerable to proxy attendance. More recent systems use RFID, NFC, QR codes, biometrics, GPS, Bluetooth, Wi-Fi, and mobile applications to automate attendance capture. Each method offers benefits, but each also has limitations when used alone.

The proposed system is positioned within this body of work as a mobile-based attendance platform that uses short-range communication signals to support classroom proximity verification. The system focuses mainly on BLE proximity and acoustic beaconing, while Wi-Fi/LAN is treated as a secondary fallback for controlled classroom-network situations. This distinction is important because the current acoustic prototype is short-ranged, BLE has shown better practical range after correct Android permissions were enabled, and Wi-Fi verifies network presence rather than exact physical distance. The anti-fraud design considers device trust, duplicate prevention, signal freshness, replay protection, and exception handling. These controls are discussed as design safeguards rather than as claims of complete fraud prevention.

## 2.2 Concept of Attendance Management Systems

Attendance management refers to the process of recording, storing, validating, and reporting the presence of individuals in a scheduled activity. In an academic environment, it is used to determine student participation in lectures, laboratories, tutorials, examinations, and institutional events. A reliable attendance system should be accurate, fast, easy to use, auditable, and resistant to manipulation.

Manual attendance systems remain common because they require little or no technology. Examples include roll call, paper registers, and signature sheets. These methods are easy to understand but become inefficient in large classes. They consume lecture time, require manual compilation, and can produce incomplete or inaccurate records. Manual registers may also be damaged, misplaced, or altered. Most importantly, manual attendance is vulnerable to proxy attendance, where one student signs or answers for another student.

Automated attendance systems were introduced to address these weaknesses. They use identification technologies, mobile applications, or sensing methods to reduce manual effort and improve record management. Rashid (2024) notes that smart attendance systems using technologies such as RFID, BLE, and NFC can support more efficient and accurate attendance tracking with real-time monitoring capabilities. However, automation alone does not automatically solve all attendance problems. A system may record data quickly but still be vulnerable if it cannot verify that the correct student is physically present in the correct place at the correct time.

Therefore, the central problem in modern attendance management is not only how to digitize records, but also how to verify presence, reduce impersonation, and maintain usability. This is the point at which proximity verification, signal freshness, device identity, and backend validation become important.

## 2.3 Smart Attendance Systems

Smart attendance systems use digital technologies to automate attendance capture and reporting. They may be web-based, mobile-based, sensor-based, or integrated into a broader smart campus infrastructure. Common technologies include RFID cards, NFC tags, QR codes, Bluetooth beacons, biometric recognition, GPS geofencing, and cloud databases.

The main advantages of smart attendance systems include speed, reduced paperwork, better data storage, and easier report generation. A lecturer can retrieve attendance records for a particular class, course, or date without manually sorting paper sheets. Digital systems can also support timestamping, duplicate prevention, and centralized storage.

However, smart attendance systems must be designed carefully. If the system only confirms login identity but not physical presence, students may share credentials. If the system only uses a QR code, the code can be photographed or forwarded. If the system only uses GPS, indoor accuracy may be poor. If the system only uses biometrics, deployment may become expensive or privacy-sensitive. If the system only uses BLE, it may face device compatibility, permission, RSSI variation, and relay risks. These limitations show the need for balanced designs that combine speed, presence verification, and fraud-aware validation.

The proposed project follows this direction by combining a mobile application, backend server, acoustic beaconing, BLE proximity verification, signal freshness checks, duplicate prevention, and reporting features. It does not claim that any single technology is perfect. Instead, it treats attendance capture as a verification process involving identity, session, proximity, time, and device evidence.

## 2.4 Mobile-Based Attendance Verification

Mobile-based attendance verification uses smartphones as the primary attendance device. This approach is practical because many students already own smartphones with microphones, speakers, Bluetooth radios, cameras, sensors, and internet connectivity. A mobile app can authenticate the user, scan for a session signal, submit proof to a backend server, and display attendance history.

Mobile-based systems have several advantages over fixed hardware systems. They reduce the need for dedicated readers, allow students and lecturers to use familiar devices, and can be updated through software. A mobile system can also combine multiple verification methods, such as login identity, location, proximity signal, device ID, timestamp, and backend validation.

Despite these advantages, mobile-based systems must handle device diversity. Different phones may have different speaker volume, microphone sensitivity, Bluetooth chipsets, Android versions, permission behavior, and battery conditions. A good design should therefore avoid depending on one perfect signal. It should provide clear error messages, allow controlled exceptions, and validate submissions on the server rather than trusting the mobile app alone.

In this project, the mobile application is used by the lecturer to create and broadcast session-specific signals, and by the student to scan and submit attendance proof. The backend validates session identity, freshness, duplicate attendance, replay attempts, and registered-device trust. This architecture supports speed while keeping important validation logic outside the client device.

## 2.5 Proximity-Based Attendance Verification

Proximity-based attendance verification attempts to confirm that a student is physically near the lecturer or classroom when attendance is taken. This is different from simply confirming that a student knows a password or can access an online form. Proximity verification is important because attendance is meant to represent physical presence in a class session.

Several technologies can support proximity verification. GPS can estimate location outdoors, but it is less reliable indoors. Wi-Fi can support network-level presence through a classroom router or access point, but it does not by itself prove exact distance from the lecturer. BLE can detect nearby beacons or advertisements, but signal strength varies across devices and indoor environments. Acoustic signals can support close-range copresence because sound must be received by the student's microphone, but acoustic performance depends strongly on speaker quality, microphone response, distance, and noise.

A proximity-based attendance system should also use signal freshness. A signal should be short-lived so that an old signal cannot be reused after the session. It should also use duplicate prevention so that a student cannot submit multiple proofs for the same session. These ideas are related to replay protection in communication systems, where old messages must not be accepted as current evidence.

The proposed system uses session-specific acoustic tokens and BLE nonces. A student proof is valid only when the decoded signal belongs to the current session and is fresh within the allowed time window. This design supports classroom proximity without claiming precise indoor positioning.

## 2.6 Acoustic Communication and Acoustic Beaconing

Acoustic communication refers to the transmission of information using sound waves. In the context of smartphones, one device can play an encoded sound while another device records and decodes it using a microphone. Acoustic communication can use audible sound or near-ultrasonic sound. Near-ultrasonic signals are attractive for proximity applications because they can be less disturbing to users while still being detectable by microphones under suitable conditions.

Getreuer, Gnegy, Lyon, and Saurous (2018) demonstrated near-ultrasonic communication using consumer hardware in the 18.5 to 20 kHz band. Their work is important because it shows that commodity smartphone speakers and microphones can transmit short tokens for copresence detection. The study also reports that high-frequency sound tends to be constrained to nearby spaces because it does not pass through walls easily. This property is relevant to classroom attendance because the purpose is to verify presence near the lecturer rather than broad location over a large outdoor area.

Jia et al. (2022) also studied smartphone-based near-ultrasonic signals for social distance detection. Their work supports the idea that acoustic signals can be used for short-range device-to-device proximity sensing. In attendance systems, the acoustic signal can act as a session beacon: the lecturer device emits a token, while the student device records and decodes it.

Acoustic beaconing has limitations. Speaker and microphone hardware differ across phones. High-frequency signals may be attenuated by phone speakers, Bluetooth speakers, distance, noise, and room acoustics. Some users may faintly hear near-ultrasonic tones depending on frequency and device output. Background noise can reduce decoding reliability. These limitations mean that acoustic communication should be evaluated under real classroom conditions and should not be presented as a perfect replacement for all other methods.

In this project, acoustic beaconing is used as a short-range proximity verification channel. Its role is to provide a short-lived classroom signal that the student device can capture and submit as proof when the devices are close enough and the environment is favourable. The current prototype has shown that acoustic decoding is sensitive to distance and noise, so it is not treated as the main large-classroom channel. The system also supports BLE as a stronger practical classroom signal so that attendance does not depend entirely on acoustic reception.

## 2.7 Bluetooth Low Energy Proximity Verification

Bluetooth Low Energy is a short-range wireless communication technology designed for low-power discovery and data exchange. BLE devices can advertise small packets of data, and nearby devices can scan for those advertisements. This makes BLE useful for proximity-aware applications because the student device can detect that a lecturer device or beacon is nearby without requiring full pairing.

BLE has been used in attendance and indoor positioning research. Puckdeevongs, Tripathi, Witayangkurn, and Saengudomlert (2020) proposed classroom attendance systems based on BLE indoor positioning for smart campus environments. Their work shows the relevance of BLE to classroom attendance, especially where location or proximity is needed. Ramirez et al. (2021) reviewed practical BLE RSSI measurement for indoor positioning and highlighted the role of RSSI in estimating proximity. However, RSSI-based proximity is not perfectly stable because signal strength is affected by phone orientation, obstacles, device differences, distance, and indoor multipath.

BLE attendance systems also have security concerns. Kim, Lee, and Paek (2018) analyzed BLE beacon-based electronic attendance systems and discussed signal imitation and forwarding attacks. Their work is important because it shows that a BLE signal alone may not be sufficient if an attacker can imitate or relay the beacon. Therefore, BLE attendance systems should use freshness, short-lived random values, backend validation, and additional risk controls.

In this project, BLE is used as the primary practical proximity signal rather than as precise indoor positioning. The lecturer device advertises a session-specific nonce, and the student device scans for it. The backend validates that the nonce belongs to the current session and has not expired. This design reduces dependence on RSSI accuracy while still benefiting from BLE's ability to detect nearby devices. The system can also be extended with fixed BLE beacons in larger rooms; such beacons do not amplify the lecturer phone, but act as additional broadcasters placed at strategic points in the classroom.

## 2.8 Review of Existing Attendance Technologies

### 2.8.1 Manual Attendance

Manual attendance includes roll call, paper registers, and signature sheets. Its advantage is simplicity. It does not require smartphones, internet access, or additional hardware. However, it is slow in large classes, difficult to process, and vulnerable to proxy attendance. It also creates administrative burden when records must be transferred into digital formats.

### 2.8.2 RFID and NFC Attendance

RFID and NFC systems use tags, cards, or phones to identify users near a reader. They can reduce time spent on manual attendance and support automatic record creation. Wahab et al. (2009) reviewed active RFID attendance approaches, showing that RFID can support automated class attendance. More recent reviews also show that RFID and NFC are common in smart campus attendance designs (Rashid, 2024).

The limitation is that RFID/NFC systems usually require tags, cards, readers, installation, and maintenance. Cards may be forgotten, lost, or exchanged. If the system only checks the card and not the person holding it, proxy attendance may still occur.

### 2.8.3 QR Code Attendance

QR code attendance systems are popular because they are inexpensive and easy to implement. A lecturer can display a QR code, and students scan it with a mobile app. Ayop et al. (2018) proposed a location-aware event attendance system using QR code and GPS technology to speed up registration and support tracking through user identification, location, and timestamp.

The weakness of QR codes is that they can be photographed, screenshotted, or shared unless the system adds dynamic generation, location checking, or other safeguards. Static QR codes are especially weak for classroom attendance because students outside the room may receive the code from friends. Dynamic QR codes reduce this risk, but they still need proximity or location verification to reduce sharing.

### 2.8.4 Biometric Attendance

Biometric attendance systems use unique physical characteristics such as fingerprints, face, iris, or voice. They can provide stronger identity verification than cards or passwords. However, biometric systems can be expensive, privacy-sensitive, and operationally difficult in large classes. Face recognition may be affected by lighting, camera quality, pose, occlusion, and demographic bias. Fingerprint systems may require contact with shared hardware, which may be inconvenient or unhygienic.

For this project, biometric verification was considered but is not part of the main implemented system. This decision keeps the system focused on proximity verification using communication signals and avoids increasing complexity at this stage.

### 2.8.5 GPS and Geofencing Attendance

GPS and geofencing can verify whether a user is within a defined location boundary. Nwabuwe, Sanghera, Alade, and Olajide (2023) used geofencing, dynamic QR code, and IMEI checking to reduce attendance fraud. GPS-based systems are useful for outdoor or large event spaces, but indoor performance can be weak due to signal blockage, multipath, and limited accuracy inside buildings. GPS also confirms general location rather than room-level proximity.

### 2.8.6 BLE Attendance

BLE attendance systems use beacons or advertising devices to confirm that a student is near a classroom signal. BLE is low power, widely supported, and suitable for short-range discovery. However, BLE may be affected by Bluetooth permission settings, hardware differences, RSSI fluctuation, interference, and signal imitation risks. Therefore, BLE systems should use short-lived session values and server-side validation rather than relying only on raw signal strength.

### 2.8.7 Acoustic Attendance

Acoustic attendance systems use sound as a proximity signal. They can work without additional radio infrastructure because smartphones already have speakers and microphones. Acoustic signals can support room-level copresence, especially when short tokens are transmitted near the lecturer. Their limitations include noise, distance, speaker volume, microphone sensitivity, and room acoustics. For this reason, acoustic attendance should be tested on real devices and ideally paired with another channel such as BLE.

### 2.8.8 Wi-Fi/LAN Fallback Attendance

Wi-Fi can support attendance verification when students connect to a classroom network or when the backend is reachable only from a local network. The advantage of Wi-Fi is wider coverage and easier use in rooms where acoustic and BLE reception may be inconsistent. However, Wi-Fi is weaker as a proximity proof because a connected device may be outside the exact classroom boundary if the network signal extends beyond the room. It is therefore best treated as supporting evidence or a fallback path, not as the main proof of physical presence.

In this project, Wi-Fi/LAN proof is used minimally. A student device can generate a short proof for the latest active session, and the backend accepts it only when the request reaches the server through a private local network and the normal identity, session, duplicate, and device-trust checks pass. This approach is useful for demonstrations and controlled environments, but BLE and acoustic signals remain the main proximity technologies discussed in the project.

## 2.9 Anti-Fraud Considerations in Smart Attendance

Attendance fraud can occur in several ways. A student may sign for another student, share a QR code, forward a link, lend an RFID card, log in with another student's credentials, or attempt to reuse an old attendance signal. In workplace attendance, similar forms of fraud are often described as buddy punching or proxy attendance. Nwabuwe et al. (2023) note that attendance fraud remains a concern even after organizations adopt automated systems.

A fraud-aware attendance system should therefore validate more than one factor. It may consider user identity, device identity, proximity signal, timestamp, session status, duplicate records, and device history. Device binding is useful because it links a student account to a trusted phone. If a student logs into another student's account using their own phone, the backend can detect that the device ID does not match the registered student. This does not solve every possible case, but it reduces a common form of account-sharing fraud.

The proposed anti-fraud design for this project considers a risk-based approach. A normal submission from the registered device with a fresh acoustic or BLE signal can be accepted automatically. A submission from an unregistered or borrowed device may be treated as an exception and scored using rules such as signal freshness, duplicate submission, device ownership conflict, and recent exception history. This mechanism is planned as a system-managed safeguard so that lecturers are not required to manually approve most cases.

It is important to state the limitation clearly: device ID binding cannot fully prevent a student from physically carrying a friend's phone to class. However, it can detect when a student logs into another account from a device already associated with a different student. It can also reveal repeated suspicious patterns, such as one phone submitting for multiple students in the same session. Therefore, device trust should be treated as one layer in a broader validation model, not as a perfect identity solution.

## 2.10 Review of Related Works

Wahab et al. (2009) reviewed class attendance using active RFID. Their work shows how RFID can automate attendance capture and reduce manual effort. The limitation is that RFID-based attendance depends on tags and readers, and proxy attendance may still occur if a student gives a tag to another student.

Ayop et al. (2018) developed a location-aware event attendance system using QR code and GPS technology. The system combined QR scanning with user identification, location, and timestamp to improve event attendance tracking. This work is relevant because it shows how mobile phones can be used for attendance verification. Its limitation is that GPS may be less reliable indoors, and QR codes may require extra safeguards against sharing.

Getreuer et al. (2018) implemented near-ultrasonic communication using consumer hardware. Their study is highly relevant to the acoustic part of this project because it shows that commodity smartphone speakers and microphones can exchange short tokens for copresence detection. The limitation is that acoustic performance depends on hardware and environmental conditions.

Kim et al. (2018) analyzed BLE beacon-based electronic attendance systems and demonstrated the importance of considering signal imitation and forwarding attacks. This work is relevant because it warns against trusting BLE beacons without freshness, authentication, or additional validation.

Puckdeevongs et al. (2020) proposed classroom attendance systems based on BLE indoor positioning for smart campus applications. Their work supports the use of BLE in academic attendance systems, but BLE positioning is affected by environmental and device-related factors.

Ramirez et al. (2021) studied practical BLE RSSI measurement for indoor positioning. Their work is relevant because it explains why BLE RSSI can be useful but unstable. This supports the decision in the proposed system to use BLE primarily as a proximity evidence channel rather than as exact indoor positioning.

Jia et al. (2022) studied smartphone-based near-ultrasonic signals for social distance detection. Their work supports the broader idea that sound-based signals can be used for proximity detection between smartphones. This is relevant to the acoustic beacon component of the proposed attendance system.

Nwabuwe et al. (2023) proposed fraud mitigation in attendance monitoring using dynamic QR codes, geofencing, and IMEI technologies. Their work is relevant to the anti-fraud design of this project because it shows that device identity and location-based restrictions can reduce attendance fraud. The proposed system differs by focusing on acoustic and BLE proximity signals instead of QR code and GPS as the main presence proof.

Rashid (2024) reviewed smart attendance systems in smart campus environments and identified technologies such as RFID, NFC, BLE, and IoT as important approaches for modern attendance monitoring. This review supports the general direction of moving from manual attendance to digital, real-time, and technology-supported attendance management.

## 2.11 Comparative Analysis of Reviewed Systems

| Attendance Method | Main Strength | Main Limitation | Fraud Concern | Relevance to Proposed System |
| --- | --- | --- | --- | --- |
| Manual roll call/register | Simple and low cost | Slow, hard to audit, paper-based | Proxy attendance | Shows why automation is needed |
| RFID/NFC | Fast and contactless | Requires cards/readers | Cards can be shared | Useful comparison for hardware-based attendance |
| QR code | Cheap and easy to deploy | Code can be shared if not dynamic | Screenshot or forwarding | Shows need for freshness and proximity |
| GPS/geofencing | Confirms broad location | Weak indoors and not room-specific | Location spoofing or inaccurate indoor data | Useful but less suitable as main classroom proof |
| Biometrics | Stronger identity verification | Privacy, lighting, cost, device issues | Presentation attacks or recognition errors | Considered but excluded from main scope |
| BLE | Short-range wireless proximity | Permissions, RSSI variation, signal imitation | Relay or imitation attacks | Main practical proximity channel |
| Acoustic beacon | Uses phone speaker/microphone, supports close-range copresence | Noise, distance, hardware differences | Recording/replay if freshness is weak | Short-range supplementary proximity channel |
| Wi-Fi/LAN | Wider classroom network reach | Proves network presence, not exact distance | Students outside room may still connect if signal leaks | Minimal fallback and support channel |
| Proposed Acoustic + BLE system with Wi-Fi fallback | Layered proof, freshness, backend validation | Still affected by device, permission, and environment constraints | Requires duplicate and device-trust controls | Main focus of this project |

The comparison shows that no attendance technology is completely free from limitations. The strength of the proposed system is not that acoustic or BLE is perfect, but that the system combines mobile proximity evidence with server-side validation and reporting. This makes it more flexible than single-channel systems and more practical than solutions requiring dedicated hardware.

## 2.12 Identified Research Gap

The reviewed literature shows that automated attendance systems can improve speed and record management, but many systems still depend on a single verification channel. Manual and paper-based systems are slow and vulnerable to proxy attendance. RFID and NFC systems require additional tags or readers and may still be misused if cards are exchanged. QR code systems are easy to deploy but can be shared unless combined with dynamic and location-aware controls. GPS and geofencing are useful for broad location verification but are less reliable for indoor classroom presence. Biometric systems can strengthen identity verification but may introduce privacy, lighting, cost, and usability concerns.

BLE-based systems are relevant to smart campus attendance, but BLE proximity can be affected by hardware differences, operating-system permissions, radio interference, signal strength variation, and possible signal imitation. Acoustic communication can support room-level copresence using commodity smartphone hardware, but it is affected by distance, noise, speaker quality, microphone response, and room acoustics. These limitations do not make BLE or acoustic methods unsuitable; rather, they show that each method should be used carefully and validated through freshness, session identity, and backend checks.

The research gap is therefore the need for a practical mobile attendance system that combines proximity-based verification, freshness control, duplicate prevention, reporting, and device-trust considerations without relying on a single signal channel or expensive dedicated hardware. This project addresses that gap by designing and implementing an Android-based attendance system where BLE provides the main practical classroom signal, acoustic beaconing provides short-range copresence evidence, Wi-Fi/LAN provides a minimal fallback where policy permits, and the backend validates attendance records for the current session.

## 2.13 Summary

This chapter reviewed literature on attendance management systems, smart attendance technologies, mobile verification, proximity-based attendance, acoustic communication, BLE proximity, and anti-fraud considerations. The review shows that existing systems improve attendance capture in different ways, but each method has trade-offs. RFID and NFC require hardware, QR codes can be shared, GPS may be weak indoors, biometrics raise privacy and operational concerns, BLE may face signal and security limitations, and acoustic signals may be affected by noise and device quality.

The proposed system builds on these findings by using BLE and acoustic proximity verification with backend validation, while keeping Wi-Fi/LAN as a secondary fallback rather than the main proof channel. The literature supports the need for short-lived session signals, duplicate prevention, replay resistance, and device-trust logic. Chapter Three will present the methodology, system analysis, architecture, database design, and implementation approach for the proposed system.
