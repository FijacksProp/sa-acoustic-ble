# Cost Implication

## Purpose

This document outlines the possible cost implications if a school decides to adopt the smart attendance system.

The analysis is not a final financial quotation. It is a practical breakdown that can be refined later for Chapter Five or the presentation slides.

## Main Cost Advantage

The main advantage of this project is that it uses devices many users already have:

- Student Android phones.
- Lecturer Android phone or laptop.
- Existing school Wi-Fi or local network.
- Backend server that can run on a school server or cloud host.

This reduces the need for dedicated attendance hardware in the basic version.

## Deployment Levels

### 1. Low-Cost Deployment

This is the current project model.

Required items:

- Student Android phones.
- Lecturer Android phone.
- Backend server or lecturer laptop.
- Local Wi-Fi or hotspot.
- Mobile app APK.

Advantages:

- Lowest hardware cost.
- Good for pilot testing.
- No RFID cards or biometric devices required.
- Easy to demonstrate.

Limitations:

- Depends on phone compatibility.
- Backend may need to run on a laptop or local server.
- Acoustic and BLE range may be limited in large rooms.

### 2. Medium-Cost Deployment

This version adds classroom infrastructure.

Possible additions:

- Fixed BLE beacons in classrooms.
- Dedicated classroom router or access point.
- School-hosted backend server.
- Basic admin dashboard.

Advantages:

- Better room coverage.
- More reliable than relying only on lecturer phone broadcasts.
- Suitable for medium and larger classrooms.

Limitations:

- Requires hardware purchase.
- Requires setup and maintenance.
- Beacon batteries may need replacement unless powered beacons are used.

### 3. Full Institutional Deployment

This version supports many departments and courses.

Possible additions:

- Central cloud or school server.
- Admin dashboard.
- Department-level lecturer/student management.
- Classroom BLE beacons or Wi-Fi integration.
- Technical support and maintenance.
- Data backup and security policies.

Advantages:

- Scalable across the institution.
- Better data management.
- Stronger policy enforcement.

Limitations:

- Higher setup and maintenance cost.
- Requires IT support.
- Requires formal data protection and access control policies.

## Cost Comparison with Other Systems

| System Type | Cost Level | Main Cost Items | Key Limitation |
| --- | --- | --- | --- |
| Manual attendance | Low | Paper, printing, staff time | Slow and vulnerable to proxy attendance |
| QR code attendance | Low | App or web system | Code can be shared |
| RFID attendance | Medium | RFID cards, readers, installation | Cards can be lost or shared |
| Biometric attendance | High | Biometric scanners, installation, privacy management | Cost, privacy, and queue delays |
| Acoustic + BLE mobile attendance | Low to medium | App, backend, optional beacons | Depends on phone hardware and signal conditions |

## Estimated Cost Ranges in Nigeria

These are rough planning estimates in Nigerian Naira as of May 2026. Prices can change based on exchange rate, vendor, quantity, shipping, and device quality.

| Item | Estimated Unit Cost | Notes |
| --- | --- | --- |
| Basic portable MiFi | ₦25,000-₦70,000 | Useful for demo or small groups; many support around 10 devices |
| Stronger 4G classroom router | ₦90,000-₦200,000 | Better for classroom LAN; some models support dozens of devices |
| BLE beacon | ₦15,000-₦35,000 per beacon | Imported beacons may be cheaper before shipping; local delivered prices can be higher |
| Entry-level Android phone | ₦80,000-₦180,000 | Usually not purchased by school if students use personal phones |
| Backend hosting | ₦5,000-₦25,000 per month | Depends on VPS/cloud provider and traffic |
| Local school server option | Variable | Can be cheaper if the school already has servers |
| App maintenance/developer support | Variable | Depends on whether school has in-house IT support |

## Example Deployment Budgets

These examples are for planning discussion only.

### Demo / Seminar Setup

| Item | Quantity | Estimated Cost |
| --- | --- | --- |
| Existing lecturer laptop | 1 | ₦0 if already available |
| Existing Android phones | 2-5 | ₦0 if already available |
| Portable MiFi or phone hotspot | 1 | ₦0-₦70,000 |
| Backend on lecturer laptop | 1 | ₦0 |
| Total | - | About ₦0-₦70,000 |

### Small Classroom Pilot

| Item | Quantity | Estimated Cost |
| --- | --- | --- |
| 4G router or reliable classroom AP | 1 | ₦90,000-₦200,000 |
| BLE beacons | 0-2 | ₦0-₦70,000 |
| Backend hosting | 1 month | ₦5,000-₦25,000 |
| Total | - | About ₦95,000-₦295,000 |

### Medium Classroom Pilot

| Item | Quantity | Estimated Cost |
| --- | --- | --- |
| 4G router or access point | 1 | ₦90,000-₦200,000 |
| BLE beacons | 2-4 | ₦30,000-₦140,000 |
| Backend hosting | 1 month | ₦5,000-₦25,000 |
| Total | - | About ₦125,000-₦365,000 |

### Large Lecture Hall Extension

| Item | Quantity | Estimated Cost |
| --- | --- | --- |
| Classroom access points | 1-2 | ₦180,000-₦400,000 |
| BLE beacons | 4-8 | ₦60,000-₦280,000 |
| Backend hosting | 1 month | ₦5,000-₦25,000 |
| Total | - | About ₦245,000-₦705,000 |

## Cost Interpretation

The lowest-cost version is possible because students and lecturers already have phones. The main additional cost appears when the school wants reliable medium or large classroom coverage.

In that case, cost comes mainly from:

- Dedicated Wi-Fi/router infrastructure.
- Fixed BLE beacons.
- Backend hosting or server maintenance.
- Technical support.

## Possible Cost Components

### Software Development

Includes:

- Mobile app development.
- Backend development.
- Database design.
- API development.
- Report generation.
- Testing and debugging.

For the FYP, this is handled as student development work. For school adoption, maintenance and upgrades would require developer support.

### Backend Hosting

Options:

- Lecturer laptop for demo.
- Department server.
- School data center.
- Cloud VPS.

For final deployment, a proper server is better than a laptop.

### BLE Beacons

If used, BLE beacons may be placed in classrooms to improve coverage.

Cost depends on:

- Number of classrooms.
- Number of beacons per room.
- Battery-powered or USB-powered beacons.
- Beacon quality and range.

For larger rooms, multiple beacons may be needed.

### Network Infrastructure

If Wi-Fi verification is adopted, the school may need:

- Reliable classroom Wi-Fi.
- Router/access point management.
- Network security policies.
- Stable server access.

### Maintenance

Maintenance may include:

- Updating the mobile app.
- Fixing bugs.
- Server backups.
- Replacing BLE beacon batteries.
- Managing student accounts.
- Handling device-change policies.

## Recommended Adoption Strategy

The best adoption path is gradual:

1. Start with pilot testing in small classrooms.
2. Use lecturer phone broadcasts and student APK installation.
3. Add device ID binding to reduce impersonation.
4. Test BLE and acoustic range in real rooms.
5. Add fixed BLE beacons only where larger room coverage is needed.
6. Move backend from laptop to school server or cloud when scaling up.

## Presentation Position

Recommended wording:

> The basic version has low deployment cost because it uses existing student and lecturer smartphones. For larger classrooms, the cost may increase if fixed BLE beacons or classroom network infrastructure are added. Even with these additions, the system can still be more affordable and flexible than biometric or RFID-based systems because it reduces dependence on dedicated attendance terminals and physical cards.

## Important Note

Final cost should be estimated after testing:

- Number of expected users.
- Number of classrooms.
- Room sizes.
- Need for BLE beacons.
- Hosting choice.
- Maintenance plan.
