import re
import ipaddress
from datetime import timedelta, datetime, timezone as dt_timezone

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework import serializers
from django.db import IntegrityError

from .models import (
    AttendanceProof,
    AttendanceReplayGuard,
    RegisteredBeacon,
    Session,
    UserProfile,
)


class SessionSerializer(serializers.ModelSerializer):
    created_by_role = serializers.CharField(source="created_by.role", read_only=True)
    created_by_username = serializers.CharField(source="created_by.user.username", read_only=True)
    created_by_matric_number = serializers.CharField(source="created_by.matric_number", read_only=True)

    class Meta:
        model = Session
        fields = [
            "id",
            "course_code",
            "course_title",
            "lecturer_name",
            "created_by_role",
            "created_by_username",
            "created_by_matric_number",
            "room",
            "starts_at",
            "ends_at",
            "active",
            "attendance_open",
            "attendance_opened_at",
            "attendance_closes_at",
            "token_version",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "attendance_open",
            "attendance_opened_at",
            "attendance_closes_at",
        ]


class AttendanceProofSerializer(serializers.ModelSerializer):
    FRESHNESS_WINDOW_SECONDS = 120
    SIGNAL_EXPIRY_SECONDS = 60
    ACOUSTIC_PATTERN = re.compile(
        r"^ac\|(?P<session>\d+)\|(?P<version>[A-Za-z0-9_.-]+)\|(?P<issued>\d{10})\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    COMPACT_ACOUSTIC_PATTERN = re.compile(
        r"^ac2\|(?P<session>[A-Za-z0-9]+)\|(?P<issued>[A-Za-z0-9]+)\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    BLE_PATTERN = re.compile(
        r"^ble\|(?P<session>\d+)\|(?P<issued>\d{10})\|(?P<nonce>[A-Za-z0-9_]+)$"
    )
    WIFI_PATTERN = re.compile(
        r"^wifi\|(?P<session>\d+)\|(?P<issued>\d{10})$"
    )
    BEACON_PATTERN = re.compile(
        r"^beacon\|(?P<type>eddystone_uid|ibeacon)\|(?P<a>[A-Fa-f0-9-]+)\|(?P<b>[A-Fa-f0-9]+)\|?(?P<c>[A-Fa-f0-9]*)$"
    )

    student_name = serializers.SerializerMethodField()
    course_code = serializers.CharField(source="session.course_code", read_only=True)
    course_title = serializers.CharField(source="session.course_title", read_only=True)
    lecturer_name = serializers.CharField(source="session.lecturer_name", read_only=True)
    room = serializers.CharField(source="session.room", read_only=True)
    registered_beacon_name = serializers.CharField(
        source="registered_beacon.name", read_only=True
    )
    face_verification_status = serializers.CharField(required=False)
    face_match_score = serializers.FloatField(required=False)

    class Meta:
        model = AttendanceProof
        fields = [
            "id",
            "session",
            "student_id",
            "student_name",
            "course_code",
            "course_title",
            "lecturer_name",
            "room",
            "device_id",
            "device_trust_status",
            "device_trust_detail",
            "acoustic_token",
            "ble_nonce",
            "wifi_proof",
            "wifi_client_ip",
            "beacon_proof",
            "beacon_type",
            "beacon_uuid",
            "beacon_major",
            "beacon_minor",
            "beacon_namespace_id",
            "beacon_instance_id",
            "beacon_rssi",
            "registered_beacon",
            "registered_beacon_name",
            "rssi",
            "observed_at",
            "signature",
            "attendance_face_image_base64",
            "face_verification_status",
            "face_match_score",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "device_trust_status",
            "device_trust_detail",
            "wifi_client_ip",
            "beacon_type",
            "beacon_uuid",
            "beacon_major",
            "beacon_minor",
            "beacon_namespace_id",
            "beacon_instance_id",
            "registered_beacon",
            "registered_beacon_name",
        ]
        extra_kwargs = {
            "acoustic_token": {"allow_blank": True},
            "ble_nonce": {"allow_blank": True},
            "wifi_proof": {"allow_blank": True},
            "beacon_proof": {"allow_blank": True},
            "attendance_face_image_base64": {"allow_blank": True},
        }

    def validate(self, attrs):
        observed_at = attrs["observed_at"]
        now = timezone.now()
        lower_bound = now - timedelta(seconds=self.FRESHNESS_WINDOW_SECONDS)
        upper_bound = now + timedelta(seconds=10)

        if observed_at < lower_bound or observed_at > upper_bound:
            raise serializers.ValidationError(
                {
                    "observed_at": (
                        "Proof timestamp is outside the allowed freshness window."
                    )
                }
            )

        session = attrs["session"]
        if not session.active:
            raise serializers.ValidationError(
                {"session": "Selected session is not active."}
            )
        if not session.attendance_open:
            raise serializers.ValidationError(
                {
                    "session": (
                        "Attendance is not open yet. Wait for the lecturer to start broadcast."
                    )
                }
            )
        if session.attendance_closes_at and now > session.attendance_closes_at:
            raise serializers.ValidationError(
                {"session": "Attendance window has closed for this session."}
            )
        if not session.created_by or session.created_by.role != UserProfile.ROLE_LECTURER:
            raise serializers.ValidationError(
                {"session": "Session must belong to an active lecturer owner."}
            )

        acoustic = attrs["acoustic_token"].strip()
        ble = attrs["ble_nonce"].strip()
        wifi = attrs.get("wifi_proof", "").strip()
        beacon = attrs.get("beacon_proof", "").strip()
        acoustic_match = self.ACOUSTIC_PATTERN.match(acoustic) if acoustic else None
        compact_acoustic_match = (
            self.COMPACT_ACOUSTIC_PATTERN.match(acoustic) if acoustic else None
        )
        ble_match = self.BLE_PATTERN.match(ble) if ble else None
        wifi_match = self.WIFI_PATTERN.match(wifi) if wifi else None
        beacon_match = self.BEACON_PATTERN.match(beacon) if beacon else None
        if acoustic and not acoustic_match and not compact_acoustic_match:
            raise serializers.ValidationError(
                {"acoustic_token": "Invalid acoustic token format."}
            )
        if ble and not ble_match:
            raise serializers.ValidationError({"ble_nonce": "Invalid BLE nonce format."})
        if wifi and not wifi_match:
            raise serializers.ValidationError({"wifi_proof": "Invalid Wi-Fi proof format."})
        if beacon and not beacon_match:
            raise serializers.ValidationError(
                {"beacon_proof": "Invalid BLE beacon proof format."}
            )
        if (
            not acoustic_match
            and not compact_acoustic_match
            and not ble_match
            and not wifi_match
            and not beacon_match
        ):
            raise serializers.ValidationError(
                "Provide at least one valid attendance signal: acoustic, BLE, beacon, or Wi-Fi/LAN."
            )

        challenge_token = ""
        ble_nonce_value = ""
        effective_acoustic_match = compact_acoustic_match or acoustic_match
        if effective_acoustic_match:
            if compact_acoustic_match:
                ac_session = int(compact_acoustic_match.group("session"), 36)
                issued_epoch = int(compact_acoustic_match.group("issued"), 36)
            else:
                ac_session = int(acoustic_match.group("session"))
                issued_epoch = int(acoustic_match.group("issued"))
            if ac_session != session.id:
                raise serializers.ValidationError(
                    {"session": "Acoustic payload session_id does not match selected session."}
                )
            ac_issued = datetime.fromtimestamp(
                issued_epoch, tz=dt_timezone.utc
            )
            if (now - ac_issued).total_seconds() > self.SIGNAL_EXPIRY_SECONDS or (
                now - ac_issued
            ).total_seconds() < -10:
                raise serializers.ValidationError(
                    {"acoustic_token": "Acoustic token has expired."}
                )
            challenge_token = effective_acoustic_match.group("challenge")

        if ble_match:
            ble_session = int(ble_match.group("session"))
            if ble_session != session.id:
                raise serializers.ValidationError(
                    {"session": "BLE payload session_id does not match selected session."}
                )
            ble_issued = datetime.fromtimestamp(
                int(ble_match.group("issued")), tz=dt_timezone.utc
            )
            if (now - ble_issued).total_seconds() > self.SIGNAL_EXPIRY_SECONDS or (
                now - ble_issued
            ).total_seconds() < -10:
                raise serializers.ValidationError({"ble_nonce": "BLE nonce has expired."})
            ble_nonce_value = ble_match.group("nonce")

        if wifi_match:
            wifi_session = int(wifi_match.group("session"))
            if wifi_session != session.id:
                raise serializers.ValidationError(
                    {"session": "Wi-Fi proof session_id does not match selected session."}
                )
            wifi_issued = datetime.fromtimestamp(
                int(wifi_match.group("issued")), tz=dt_timezone.utc
            )
            if (now - wifi_issued).total_seconds() > self.SIGNAL_EXPIRY_SECONDS or (
                now - wifi_issued
            ).total_seconds() < -10:
                raise serializers.ValidationError({"wifi_proof": "Wi-Fi proof has expired."})
            remote_addr = self._request_remote_addr()
            if not self._is_private_lan_address(remote_addr):
                raise serializers.ValidationError(
                    {
                        "wifi_proof": (
                            "Wi-Fi/LAN proof requires the phone to reach the "
                            "backend through a local private network."
                        )
                    }
                )
            attrs["wifi_client_ip"] = remote_addr

        if beacon_match:
            registered_beacon = self._validate_beacon(session, beacon_match, attrs)
            attrs["registered_beacon"] = registered_beacon

        attrs["_decoded_challenge_token"] = challenge_token
        attrs["_decoded_ble_nonce"] = ble_nonce_value
        if AttendanceReplayGuard.objects.filter(
            session=session,
            challenge_token=challenge_token,
            ble_nonce=ble_nonce_value,
        ).exists():
            raise serializers.ValidationError(
                {"ble_nonce": "Replay detected: challenge/nonce already used."}
            )

        # Application-level duplicate guard for clearer API errors.
        student_id = attrs["student_id"].strip()
        if AttendanceProof.objects.filter(session=session, student_id=student_id).exists():
            raise serializers.ValidationError(
                {"student_id": "Attendance already submitted for this session."}
            )

        attrs["student_id"] = student_id
        attrs["device_id"] = attrs["device_id"].strip()
        attrs["acoustic_token"] = attrs["acoustic_token"].strip()
        attrs["ble_nonce"] = attrs["ble_nonce"].strip()
        attrs["wifi_proof"] = attrs.get("wifi_proof", "").strip()
        attrs["beacon_proof"] = attrs.get("beacon_proof", "").strip()
        attrs["signature"] = attrs["signature"].strip()
        attrs["attendance_face_image_base64"] = attrs.get(
            "attendance_face_image_base64", ""
        ).strip()
        attrs["face_verification_status"] = (
            attrs.get("face_verification_status", "not_required").strip()
            or "not_required"
        )
        attrs["face_match_score"] = float(attrs.get("face_match_score") or 0)
        return attrs

    def _validate_beacon(self, session, beacon_match, attrs):
        beacon_type = beacon_match.group("type").lower()
        if beacon_type == RegisteredBeacon.BEACON_TYPE_EDDYSTONE_UID:
            namespace_id = beacon_match.group("a").lower()
            instance_id = beacon_match.group("b").lower()
            registered_beacon = RegisteredBeacon.objects.filter(
                active=True,
                beacon_type=RegisteredBeacon.BEACON_TYPE_EDDYSTONE_UID,
                namespace_id__iexact=namespace_id,
                instance_id__iexact=instance_id,
            ).first()
            attrs["beacon_type"] = beacon_type
            attrs["beacon_namespace_id"] = namespace_id
            attrs["beacon_instance_id"] = instance_id
        else:
            uuid = beacon_match.group("a").lower()
            major = int(beacon_match.group("b"))
            minor = int(beacon_match.group("c") or 0)
            registered_beacon = RegisteredBeacon.objects.filter(
                active=True,
                beacon_type=RegisteredBeacon.BEACON_TYPE_IBEACON,
                uuid__iexact=uuid,
                major=major,
                minor=minor,
            ).first()
            attrs["beacon_type"] = beacon_type
            attrs["beacon_uuid"] = uuid
            attrs["beacon_major"] = major
            attrs["beacon_minor"] = minor

        if registered_beacon is None:
            raise serializers.ValidationError(
                {"beacon_proof": "This BLE beacon is not registered for attendance."}
            )

        session_room = (session.room or "").strip().lower()
        beacon_room = (registered_beacon.room or "").strip().lower()
        if beacon_room and session_room and beacon_room != session_room:
            raise serializers.ValidationError(
                {
                    "beacon_proof": (
                        "Detected BLE beacon is not assigned to this session room."
                    )
                }
            )

        beacon_rssi = attrs.get("beacon_rssi")
        if beacon_rssi is None:
            beacon_rssi = attrs.get("rssi")
        if beacon_rssi is not None and beacon_rssi < registered_beacon.min_rssi:
            raise serializers.ValidationError(
                {"beacon_rssi": "BLE beacon signal is too weak for attendance."}
            )
        attrs["beacon_rssi"] = beacon_rssi
        return registered_beacon

    def create(self, validated_data):
        challenge_token = validated_data.pop("_decoded_challenge_token", None)
        ble_nonce_value = validated_data.pop("_decoded_ble_nonce", None)
        proof = super().create(validated_data)
        if not challenge_token and not ble_nonce_value:
            return proof
        try:
            AttendanceReplayGuard.objects.create(
                session=proof.session,
                challenge_token=challenge_token or "",
                ble_nonce=ble_nonce_value or "",
                student_id=proof.student_id,
            )
        except IntegrityError:
            raise serializers.ValidationError(
                {"ble_nonce": "Replay detected: challenge/nonce already used."}
            )
        return proof

    def _request_remote_addr(self):
        request = self.context.get("request")
        if request is None:
            return ""
        forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR", "").strip()

    def _is_private_lan_address(self, value):
        try:
            address = ipaddress.ip_address(value)
        except ValueError:
            return False
        return address.is_private or address.is_loopback

    def validate_student_id(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("student_id cannot be empty.")
        return cleaned

    def validate_device_id(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("device_id cannot be empty.")
        return cleaned

    def validate_acoustic_token(self, value):
        cleaned = value.strip()
        return cleaned

    def validate_ble_nonce(self, value):
        cleaned = value.strip()
        return cleaned

    def validate_signature(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("signature cannot be empty.")
        return cleaned

    def get_student_name(self, obj):
        # For students, student_id is matric_number
        try:
            profile = UserProfile.objects.get(matric_number=obj.student_id)
            return profile.user.first_name
        except UserProfile.DoesNotExist:
            # For lecturers, student_id is username
            try:
                user = User.objects.get(username=obj.student_id)
                return user.first_name
            except User.DoesNotExist:
                return ''


class RegisterSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    matric_number = serializers.CharField(max_length=64, required=False, allow_blank=True)
    username = serializers.CharField(max_length=150, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=UserProfile.ROLE_CHOICES)
    password = serializers.CharField(write_only=True, min_length=6)
    face_image_base64 = serializers.CharField(required=False, allow_blank=True)
    device_id = serializers.CharField(max_length=128, required=False, allow_blank=True)

    def validate(self, attrs):
        role = attrs["role"]
        matric_number = attrs.get("matric_number", "").strip()
        username = attrs.get("username", "").strip()
        device_id = attrs.get("device_id", "").strip()

        if role == UserProfile.ROLE_STUDENT:
            if not matric_number:
                raise serializers.ValidationError(
                    {"matric_number": "matric_number is required for students."}
                )
            if UserProfile.objects.filter(matric_number=matric_number).exists():
                raise serializers.ValidationError(
                    {"matric_number": "matric_number already registered."}
                )
            if device_id and UserProfile.objects.filter(
                role=UserProfile.ROLE_STUDENT,
                registered_device_id=device_id,
            ).exists():
                raise serializers.ValidationError(
                    {
                        "device_id": (
                            "This phone is already linked to another student account."
                        )
                    }
                )
            attrs["username"] = matric_number
            attrs["matric_number"] = matric_number
        else:
            if not username:
                raise serializers.ValidationError(
                    {"username": "username is required for lecturers."}
                )
            if User.objects.filter(username=username).exists():
                raise serializers.ValidationError(
                    {"username": "username already exists."}
                )
            attrs["username"] = username
            attrs["matric_number"] = None

        return attrs

    def create(self, validated_data):
        full_name = validated_data["full_name"].strip()
        matric_number = validated_data.get("matric_number")
        username = validated_data["username"]
        role = validated_data["role"]
        password = validated_data["password"]
        face_image_base64 = validated_data.get("face_image_base64", "").strip()
        device_id = validated_data.get("device_id", "").strip()

        user = User.objects.create_user(
            username=username,
            first_name=full_name,
            password=password,
        )
        profile = UserProfile.objects.create(
            user=user,
            matric_number=matric_number,
            role=role,
            face_image_base64=face_image_base64,
            registered_device_id=(
                device_id if role == UserProfile.ROLE_STUDENT else ""
            ),
            registered_device_at=(
                timezone.now()
                if role == UserProfile.ROLE_STUDENT and device_id
                else None
            ),
        )
        token, _ = Token.objects.get_or_create(user=user)
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
            "has_face_enrollment": bool(profile.face_image_base64),
            "registered_device_id": profile.registered_device_id,
        }


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField(max_length=150)
    password = serializers.CharField(write_only=True)
    device_id = serializers.CharField(max_length=128, required=False, allow_blank=True)

    def validate(self, attrs):
        identifier = attrs["identifier"].strip()
        password = attrs["password"]
        user = authenticate(username=identifier, password=password)
        if not user:
            raise serializers.ValidationError("Invalid credentials.")
        device_id = attrs.get("device_id", "").strip()
        profile = user.profile
        if profile.role == UserProfile.ROLE_STUDENT and device_id:
            conflicting = (
                UserProfile.objects.filter(
                    role=UserProfile.ROLE_STUDENT,
                    registered_device_id=device_id,
                )
                .exclude(pk=profile.pk)
                .exists()
            )
            if conflicting:
                raise serializers.ValidationError(
                    "This phone is already linked to another student account."
                )
            if profile.registered_device_id and profile.registered_device_id != device_id:
                raise serializers.ValidationError(
                    "This student account is already linked to another phone."
                )
            attrs["device_id"] = device_id
        attrs["user"] = user
        return attrs

    def create(self, validated_data):
        user = validated_data["user"]
        profile = user.profile
        device_id = validated_data.get("device_id", "").strip()
        if (
            profile.role == UserProfile.ROLE_STUDENT
            and device_id
            and not profile.registered_device_id
        ):
            profile.registered_device_id = device_id
            profile.registered_device_at = timezone.now()
            profile.save(
                update_fields=["registered_device_id", "registered_device_at"]
            )
        token, _ = Token.objects.get_or_create(user=user)
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
            "has_face_enrollment": bool(profile.face_image_base64),
            "registered_device_id": profile.registered_device_id,
        }
