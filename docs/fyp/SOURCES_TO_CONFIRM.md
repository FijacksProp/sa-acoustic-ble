# Source Verification Register

This register records how the report sources were checked and how each source may be used. The formal APA 7 list is maintained in `REFERENCES.md`.

## Verification Status

| Source | Verification record | Appropriate use in the report |
| --- | --- | --- |
| Android Developers (n.d.) | Official Android documentation: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions | Android BLE scan, advertise, connect, nearby-device, and location permission requirements. |
| Ayop et al. (2018) | DOI and journal record: https://doi.org/10.14569/IJACSA.2018.090959 | Comparison with QR code and GPS attendance. |
| Azmi et al. (2018) | IEEE DOI and UNITEN repository metadata: https://doi.org/10.1109/IC3e.2018.8632631 | Prior BLE beacon attendance implementation and comparison with paper/RFID attendance. |
| Beck et al. (2001) | Original Agile Manifesto: https://agilemanifesto.org/ | Basis for the iterative software-development approach. |
| Getreuer et al. (2018) | IEEE DOI and author publication record: https://doi.org/10.1109/TMM.2017.2766049 | Near-ultrasonic communication using commodity speakers and microphones. |
| Hayati and Nugraha (2023) | Journal record and DOI: https://doi.org/10.17933/bpostel.v21i2.380 | Closely related Android, beacon, cloud-server, and proximity-based attendance system; especially relevant to Telecommunication Science. |
| Jia et al. (2022) | Publisher record: https://doi.org/10.3390/s22197345 | Smartphone near-ultrasonic proximity sensing and environmental constraints. |
| Kim et al. (2018) | IEEE DOI and DOAJ metadata: https://doi.org/10.1109/ACCESS.2018.2884488 | BLE attendance signal imitation, forwarding, replay risks, and the need for server-side safeguards. |
| Lodha et al. (2015) | Elsevier DOI and journal metadata: https://doi.org/10.1016/j.procs.2015.03.094 | Early Bluetooth Smart attendance implementation and operational benefits. |
| Miao et al. (2020) | Journal DOI and publisher metadata: https://doi.org/10.26599/TST.2018.9010141 | RFID attendance and anti-cheating comparison. |
| Noguchi et al. (2015) | IEEE DOI and proceedings metadata: https://doi.org/10.1109/NBiS.2015.109 | BLE beacon and Android attendance architecture closely related to the project. |
| Nwabuwe et al. (2023) | DOI and University of East Anglia repository record: https://doi.org/10.14569/IJACSA.2023.01404104 | Dynamic proof, geofencing, device identity, and attendance-fraud mitigation. |
| Puckdeevongs et al. (2020) | Publisher record: https://doi.org/10.3390/info11060329 | BLE classroom attendance, RSSI fingerprinting, room installation, and measured positioning limitations. |
| Ramirez et al. (2021) | Publisher record: https://doi.org/10.3390/s21155181 | BLE RSSI variation, environmental effects, and limits of converting RSSI into exact distance. |
| Rashid (2024) | Journal record: https://doi.org/10.35934/segi.v8i2.85 | Broad review of smart-campus attendance technologies. |

## Evidence Rules Used During Writing

- A source supports only the claim for which its publisher record or full text provides evidence.
- Findings from another system are not presented as results of this project.
- The report paraphrases ideas in new wording and does not copy abstracts or literature-review passages.
- Direct quotations are avoided because paraphrase with an author-date citation is sufficient for this report.
- Implementation claims are checked against the repository, migrations, automated tests, and current mobile/backend behavior.
- Field-performance statements use the reported four-device observations and are labelled as small-scale results.
- No success percentage, exact range, sample size, RSSI value, or classroom capacity is invented where it was not measured.
- Device binding is described as a deterrent to casual account sharing, not as conclusive proof that the registered person is holding the phone.
- BLE RSSI is described as approximate evidence, not an exact distance measurement.
