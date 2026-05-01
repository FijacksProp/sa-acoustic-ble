# Anti-Fraud Device Binding and Exception Rules

This document records the planned anti-fraud process for handling attendance submissions when a student logs into another account from a different phone.

The goal is to let the system make most decisions automatically, so attendance remains fast while still discouraging impersonation.

## Core Idea

Each student should be linked to a trusted device ID. During attendance submission, the backend compares the submitting device ID with the device ID registered to the student account.

The system should not reject every mismatch immediately, because genuine cases can happen, such as a dead phone, faulty phone, or forgotten phone. Instead, the system should apply risk rules and classify the submission.

## Attendance Outcomes

- `accepted`: the attendance proof is trusted and counted normally.
- `accepted_with_exception`: the proof is counted, but marked as a verified exception.
- `flagged_for_review`: the proof is saved, but not counted automatically.
- `rejected`: the proof is too risky and is not accepted.

## Device Trust Categories

- `trusted_device`: the device matches the student's registered device.
- `new_device`: the device is not yet linked to any student.
- `borrowed_device`: the device is linked to another student.
- `conflicting_device`: the device has suspicious recent activity.

## Risk Score Rules

Start each attendance proof with a score of `0`.

### Positive Rules

- `+35` if the device matches the student.
- `+25` if a fresh Acoustic or BLE scan is valid for the current session.
- `+15` if both Acoustic and BLE are valid.
- `+10` if no previous attendance exists for this student in the same session.
- `+15` if a valid exception reason is provided.
- `+10` if the student's exception usage is still within the allowed limit.

### Negative Rules

- `-30` if the student is using an unknown or new device.
- `-45` if the device is already registered to another student.
- `-60` if the same device already submitted for another student in the same session.
- `-80` if the same device attempts attendance for three or more students in one session.
- `-25` if the student has exceeded the borrowed-device allowance.
- `-20` if the borrowed device has been used too often recently.
- `-30` if no valid proximity signal was captured.

## Decision Thresholds

- Score `70` and above: `accepted`.
- Score `50` to `69`: `accepted_with_exception`.
- Score `30` to `49`: `flagged_for_review`.
- Score below `30`: `rejected`.

## Exception Reasons

The student may be asked to select one reason when using another device:

- `phone_dead`
- `phone_faulty`
- `forgot_phone`
- `temporary_device`

The reason should be stored with the attendance proof for transparency and audit purposes.

## Recommended Limits

- A student should have a limited number of borrowed-device attendances per course or semester.
- A single phone should not be allowed to submit attendance for many students in the same session.
- If a device repeatedly submits for different accounts, the system should automatically increase risk and eventually reject submissions.

## Practical Flow

1. Student scans Acoustic or BLE signal.
2. Student submits attendance proof.
3. Backend checks the device ID against the student's registered device.
4. Backend calculates the risk score using the rules above.
5. Backend saves the proof with the final decision and risk details.
6. Mobile app shows a short friendly message, not raw technical details.
7. Lecturer report can optionally show exception records separately.

## Important Limitation

Device ID binding helps stop the common fraud case where a student logs into another student's account from their own phone. It cannot fully stop a student who physically carries a friend's registered phone to class.

That case should be handled later using additional policies such as spot checks, unusual pattern detection, or optional biometric verification if required.
