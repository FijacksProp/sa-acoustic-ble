import hashlib
import string
from datetime import timedelta

from django.contrib.auth.models import User
from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import AttendanceProof, RegisteredBeacon, Session, UserProfile


@override_settings(
    PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
)
class AttendanceApiTests(APITestCase):
    def setUp(self):
        self.lecturer = self._create_profile(
            username="lecturer",
            full_name="Test Lecturer",
            role=UserProfile.ROLE_LECTURER,
        )
        self.other_lecturer = self._create_profile(
            username="other-lecturer",
            full_name="Other Lecturer",
            role=UserProfile.ROLE_LECTURER,
        )
        self.student = self._create_profile(
            username="MAT001",
            full_name="Student One",
            role=UserProfile.ROLE_STUDENT,
            matric_number="MAT001",
            device_id="dev_student_1",
        )
        self.student_two = self._create_profile(
            username="MAT002",
            full_name="Student Two",
            role=UserProfile.ROLE_STUDENT,
            matric_number="MAT002",
            device_id="dev_student_2",
        )

    def test_student_cannot_update_lecturer_session(self):
        session = self._create_session(attendance_open=True)
        self.client.force_authenticate(self.student.user)

        response = self.client.patch(
            f"/api/sessions/{session.id}/",
            {"course_title": "Tampered title"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        session.refresh_from_db()
        self.assertEqual(session.course_title, "Digital Communications")

    def test_owner_can_update_session_but_lecturer_name_remains_authenticated(self):
        session = self._create_session()
        self.client.force_authenticate(self.lecturer.user)

        response = self.client.patch(
            f"/api/sessions/{session.id}/",
            {
                "course_title": "Updated Course",
                "lecturer_name": "Impersonated Lecturer",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        session.refresh_from_db()
        self.assertEqual(session.course_title, "Updated Course")
        self.assertEqual(session.lecturer_name, "Test Lecturer")

    def test_open_attendance_rejects_room_conflict(self):
        self._create_session(attendance_open=True)
        second = self._create_session(course_code="TCS402")
        self.client.force_authenticate(self.lecturer.user)

        response = self.client.post(
            f"/api/sessions/{second.id}/open-attendance/",
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        second.refresh_from_db()
        self.assertFalse(second.attendance_open)

    def test_expired_room_session_does_not_block_new_attendance(self):
        expired = self._create_session(attendance_open=True)
        expired.attendance_closes_at = timezone.now() - timedelta(seconds=1)
        expired.save(update_fields=["attendance_closes_at"])
        second = self._create_session(course_code="TCS402")
        self.client.force_authenticate(self.lecturer.user)

        response = self.client.post(
            f"/api/sessions/{second.id}/open-attendance/",
            {},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        expired.refresh_from_db()
        self.assertFalse(expired.attendance_open)

    def test_valid_ble_proof_is_accepted_and_duplicate_is_rejected(self):
        session = self._create_session(attendance_open=True)
        self.client.force_authenticate(self.student.user)
        issued = int(timezone.now().timestamp())
        ble_nonce = f"ble|{session.id}|{issued}|nonce001"

        first = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                ble_nonce=ble_nonce,
            ),
            format="json",
        )
        duplicate = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                ble_nonce=f"ble|{session.id}|{issued}|nonce002",
            ),
            format="json",
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(duplicate.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(AttendanceProof.objects.filter(session=session).count(), 1)

    def test_broadcast_ble_nonce_can_be_used_by_distinct_students(self):
        session = self._create_session(attendance_open=True)
        issued = int(timezone.now().timestamp())
        ble_nonce = f"ble|{session.id}|{issued}|shared01"

        self.client.force_authenticate(self.student.user)
        first = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                ble_nonce=ble_nonce,
            ),
            format="json",
        )
        self.client.force_authenticate(self.student_two.user)
        second = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student_two,
                ble_nonce=ble_nonce,
            ),
            format="json",
        )

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_201_CREATED)
        self.assertEqual(AttendanceProof.objects.filter(session=session).count(), 2)

    def test_tampered_proof_digest_is_rejected(self):
        session = self._create_session(attendance_open=True)
        issued = int(timezone.now().timestamp())
        self.client.force_authenticate(self.student.user)
        payload = self._proof_payload(
            session=session,
            profile=self.student,
            ble_nonce=f"ble|{session.id}|{issued}|digest01",
        )
        payload["rssi"] = -91

        response = self.client.post("/api/attendance/", payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("signature", response.data)

    def test_student_cannot_submit_for_another_identity(self):
        session = self._create_session(attendance_open=True)
        issued = int(timezone.now().timestamp())
        self.client.force_authenticate(self.student.user)
        payload = self._proof_payload(
            session=session,
            profile=self.student,
            ble_nonce=f"ble|{session.id}|{issued}|identity1",
        )
        payload["student_id"] = self.student_two.matric_number
        fields = [
            str(session.id),
            payload["student_id"],
            payload["device_id"],
            payload["acoustic_token"],
            payload["ble_nonce"],
            payload["wifi_proof"],
            payload["beacon_proof"],
            str(payload["rssi"]),
            payload["observed_at"],
        ]
        payload["signature"] = hashlib.sha256(
            "|".join(fields).encode("utf-8")
        ).hexdigest()

        response = self.client.post("/api/attendance/", payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("student_id", response.data)
        self.assertFalse(AttendanceProof.objects.filter(session=session).exists())

    def test_new_wifi_proof_is_rejected(self):
        session = self._create_session(attendance_open=True)
        issued = int(timezone.now().timestamp())
        self.client.force_authenticate(self.student.user)

        response = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                wifi_proof=f"wifi|{session.id}|{issued}",
            ),
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("wifi_proof", response.data)

    def test_compact_acoustic_proof_is_reported_as_accepted(self):
        session = self._create_session(attendance_open=True)
        issued = int(timezone.now().timestamp())
        acoustic = (
            f"ac2|{self._base36(session.id)}|"
            f"{self._base36(issued)}|acoustic1"
        )
        self.client.force_authenticate(self.student.user)
        created = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                acoustic_token=acoustic,
            ),
            format="json",
        )
        self.client.force_authenticate(self.lecturer.user)
        report = self.client.get(f"/api/attendance/report/?session={session.id}")

        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        self.assertEqual(report.status_code, status.HTTP_200_OK)
        row = report.data["results"][0]
        self.assertEqual(row["status"], "pass")
        self.assertIsNotNone(row["acoustic_age_seconds"])
        self.assertEqual(row["failed_checks"], [])

    def test_beacon_proof_enforces_room_and_rssi(self):
        session = self._create_session(attendance_open=True, room="LT 1")
        beacon = RegisteredBeacon.objects.create(
            name="LT 1 Beacon",
            room="LT 1",
            beacon_type=RegisteredBeacon.BEACON_TYPE_IBEACON,
            uuid="e2c56db5-dffb-48d2-b060-d0f5a71096e0",
            major=5,
            minor=6,
            min_rssi=-70,
        )
        beacon_proof = (
            f"beacon|ibeacon|{beacon.uuid}|{beacon.major}|{beacon.minor}"
        )
        self.client.force_authenticate(self.student.user)

        weak = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                beacon_proof=beacon_proof,
                rssi=-80,
            ),
            format="json",
        )
        accepted = self.client.post(
            "/api/attendance/",
            self._proof_payload(
                session=session,
                profile=self.student,
                beacon_proof=beacon_proof,
                rssi=-55,
            ),
            format="json",
        )

        self.assertEqual(weak.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(accepted.status_code, status.HTTP_201_CREATED)

    def test_beacon_resolution_rejects_ambiguous_room_sessions(self):
        self._create_session(attendance_open=True, room="LT 1")
        self._create_session(
            course_code="TCS402",
            attendance_open=True,
            room="LT 1",
        )
        beacon = RegisteredBeacon.objects.create(
            name="LT 1 Beacon",
            room="LT 1",
            beacon_type=RegisteredBeacon.BEACON_TYPE_IBEACON,
            uuid="e2c56db5-dffb-48d2-b060-d0f5a71096e0",
            major=5,
            minor=6,
            min_rssi=-90,
        )
        self.client.force_authenticate(self.student.user)

        response = self.client.post(
            "/api/attendance/resolve-beacon-session/",
            {
                "beacon_proof": (
                    f"beacon|ibeacon|{beacon.uuid}|"
                    f"{beacon.major}|{beacon.minor}"
                ),
                "beacon_rssi": -50,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)

    def test_student_registration_enforces_one_device_owner(self):
        payload = {
            "full_name": "New Student",
            "matric_number": "MAT003",
            "role": UserProfile.ROLE_STUDENT,
            "password": "StrongPass123",
            "device_id": "dev_student_1",
        }

        response = self.client.post("/api/auth/register/", payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("device_id", response.data)

    def test_profile_response_does_not_expose_legacy_face_data(self):
        self.student.face_image_base64 = "legacy-sensitive-image"
        self.student.save(update_fields=["face_image_base64"])
        self.client.force_authenticate(self.student.user)

        response = self.client.get("/api/auth/me/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertNotIn("face_image_base64", response.data)
        self.assertNotIn("has_face_enrollment", response.data)

    def test_logout_revokes_the_current_token(self):
        token = Token.objects.create(user=self.student.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        response = self.client.post("/api/auth/logout/", {}, format="json")

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Token.objects.filter(key=token.key).exists())

    def _create_profile(
        self,
        *,
        username,
        full_name,
        role,
        matric_number=None,
        device_id="",
    ):
        user = User.objects.create_user(
            username=username,
            first_name=full_name,
            password="StrongPass123",
        )
        return UserProfile.objects.create(
            user=user,
            role=role,
            matric_number=matric_number,
            registered_device_id=device_id,
            registered_device_at=timezone.now() if device_id else None,
        )

    def _create_session(
        self,
        *,
        course_code="TCS401",
        room="LT 1",
        attendance_open=False,
    ):
        now = timezone.now()
        return Session.objects.create(
            course_code=course_code,
            course_title="Digital Communications",
            lecturer_name=self.lecturer.user.first_name,
            created_by=self.lecturer,
            room=room,
            starts_at=now,
            active=True,
            attendance_open=attendance_open,
            attendance_opened_at=now if attendance_open else None,
            token_version="v1",
        )

    def _proof_payload(
        self,
        *,
        session,
        profile,
        acoustic_token="",
        ble_nonce="",
        beacon_proof="",
        wifi_proof="",
        rssi=-50,
    ):
        observed_at = timezone.now().isoformat().replace("+00:00", "Z")
        student_id = profile.matric_number or profile.user.username
        fields = [
            str(session.id),
            student_id,
            profile.registered_device_id,
            acoustic_token,
            ble_nonce,
            wifi_proof,
            beacon_proof,
            str(rssi),
            observed_at,
        ]
        signature = hashlib.sha256("|".join(fields).encode("utf-8")).hexdigest()
        return {
            "session": session.id,
            "student_id": student_id,
            "device_id": profile.registered_device_id,
            "acoustic_token": acoustic_token,
            "ble_nonce": ble_nonce,
            "wifi_proof": wifi_proof,
            "beacon_proof": beacon_proof,
            "beacon_rssi": rssi if beacon_proof else None,
            "rssi": rssi,
            "observed_at": observed_at,
            "signature": signature,
        }

    @staticmethod
    def _base36(value):
        alphabet = string.digits + string.ascii_lowercase
        if value == 0:
            return "0"
        output = ""
        while value:
            value, remainder = divmod(value, 36)
            output = alphabet[remainder] + output
        return output
