import hashlib
import hmac
import re
from datetime import timedelta, datetime, timezone as dt_timezone

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework import serializers

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
            "lecturer_name",
            "attendance_open",
            "attendance_opened_at",
            "attendance_closes_at",
        ]
        extra_kwargs = {
            "course_code": {"allow_blank": False},
            "course_title": {"allow_blank": False},
            "room": {"allow_blank": False},
        }


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
        beacon_match = self.BEACON_PATTERN.match(beacon) if beacon else None
        if acoustic and not acoustic_match and not compact_acoustic_match:
            raise serializers.ValidationError(
                {"acoustic_token": "Invalid acoustic token format."}
            )
        if ble and not ble_match:
            raise serializers.ValidationError({"ble_nonce": "Invalid BLE nonce format."})
        if wifi:
            raise serializers.ValidationError(
                {
                    "wifi_proof": (
                        "Wi-Fi/LAN proof is no longer accepted. "
                        "Use acoustic, lecturer BLE, or a registered room beacon."
                    )
                }
            )
        if beacon and not beacon_match:
            raise serializers.ValidationError(
                {"beacon_proof": "Invalid BLE beacon proof format."}
            )
        if (
            not acoustic_match
            and not compact_acoustic_match
            and not ble_match
            and not beacon_match
        ):
            raise serializers.ValidationError(
                "Provide at least one valid attendance signal: acoustic, lecturer BLE, or room beacon."
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

        if beacon_match:
            registered_beacon = self._validate_beacon(session, beacon_match, attrs)
            attrs["registered_beacon"] = registered_beacon

        student_id = attrs["student_id"].strip()
        request = self.context.get("request")
        if request is not None and request.user.is_authenticated:
            profile = request.user.profile
            if profile.role == UserProfile.ROLE_STUDENT:
                authenticated_id = profile.matric_number or request.user.username
                if student_id != authenticated_id:
                    raise serializers.ValidationError(
                        {
                            "student_id": (
                                "Student identity must match the signed-in account."
                            )
                        }
                    )
        replay_query = Q()
        if challenge_token:
            replay_query |= Q(challenge_token=challenge_token)
        if ble_nonce_value:
            replay_query |= Q(ble_nonce=ble_nonce_value)
        if replay_query and AttendanceReplayGuard.objects.filter(
            session=session,
            student_id=student_id,
        ).filter(replay_query).exists():
            raise serializers.ValidationError(
                {"signal": "This attendance signal has already been used."}
            )

        # Application-level duplicate guard for clearer API errors.
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
        self._validate_proof_digest(attrs)
        attrs["_decoded_challenge_token"] = challenge_token
        attrs["_decoded_ble_nonce"] = ble_nonce_value
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
            try:
                major = int(beacon_match.group("b"))
                minor = int(beacon_match.group("c") or 0)
            except ValueError:
                raise serializers.ValidationError(
                    {"beacon_proof": "Invalid iBeacon major or minor value."}
                )
            if not 0 <= major <= 65535 or not 0 <= minor <= 65535:
                raise serializers.ValidationError(
                    {"beacon_proof": "iBeacon major and minor must be between 0 and 65535."}
                )
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
        if not beacon_room:
            raise serializers.ValidationError(
                {
                    "beacon_proof": (
                        "Detected BLE beacon is registered but has not been assigned to a room."
                    )
                }
            )
        if not session_room:
            raise serializers.ValidationError(
                {
                    "session": (
                        "Session room is required before BLE beacon attendance can be accepted."
                    )
                }
            )
        if beacon_room != session_room:
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
        try:
            with transaction.atomic():
                proof = super().create(validated_data)
                if challenge_token or ble_nonce_value:
                    AttendanceReplayGuard.objects.create(
                        session=proof.session,
                        challenge_token=challenge_token or "",
                        ble_nonce=ble_nonce_value or "",
                        student_id=proof.student_id,
                    )
                return proof
        except IntegrityError:
            raise serializers.ValidationError(
                {
                    "signal": (
                        "Attendance was already submitted or this signal "
                        "has already been used."
                    )
                }
            )

    def _validate_proof_digest(self, attrs):
        raw_observed_at = str(self.initial_data.get("observed_at", "")).strip()
        digest_payload = "|".join(
            [
                str(attrs["session"].id),
                attrs["student_id"],
                attrs["device_id"],
                attrs["acoustic_token"],
                attrs["ble_nonce"],
                attrs["wifi_proof"],
                attrs["beacon_proof"],
                str(attrs["rssi"]),
                raw_observed_at,
            ]
        )
        expected = hashlib.sha256(digest_payload.encode("utf-8")).hexdigest()
        if not hmac.compare_digest(attrs["signature"].lower(), expected):
            raise serializers.ValidationError(
                {"signature": "Attendance proof integrity check failed. Scan again."}
            )

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
        cached_names = self.context.get("student_names")
        if cached_names is not None:
            return cached_names.get(obj.student_id, "")
        try:
            profile = UserProfile.objects.get(matric_number=obj.student_id)
            return profile.user.first_name
        except UserProfile.DoesNotExist:
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
    password = serializers.CharField(write_only=True, min_length=8)
    device_id = serializers.CharField(max_length=128, required=False, allow_blank=True)

    def validate_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as error:
            raise serializers.ValidationError(error.messages)
        return value

    def validate(self, attrs):
        role = attrs["role"]
        matric_number = attrs.get("matric_number", "").strip().upper()
        username = attrs.get("username", "").strip()
        device_id = attrs.get("device_id", "").strip()

        if role == UserProfile.ROLE_STUDENT:
            if not matric_number:
                raise serializers.ValidationError(
                    {"matric_number": "matric_number is required for students."}
                )
            if UserProfile.objects.filter(matric_number__iexact=matric_number).exists():
                raise serializers.ValidationError(
                    {"matric_number": "matric_number already registered."}
                )
            if User.objects.filter(username__iexact=matric_number).exists():
                raise serializers.ValidationError(
                    {"matric_number": "An account already uses this matric number."}
                )
            if not device_id:
                raise serializers.ValidationError(
                    {"device_id": "A device ID is required for student registration."}
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
            if User.objects.filter(username__iexact=username).exists():
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
        device_id = validated_data.get("device_id", "").strip()

        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=username,
                    first_name=full_name,
                    password=password,
                )
                profile = UserProfile.objects.create(
                    user=user,
                    matric_number=matric_number,
                    role=role,
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
        except IntegrityError:
            raise serializers.ValidationError(
                {"account": "This account or student device is already registered."}
            )
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
            "registered_device_id": profile.registered_device_id,
        }


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField(max_length=150)
    password = serializers.CharField(write_only=True)
    device_id = serializers.CharField(max_length=128, required=False, allow_blank=True)

    def validate(self, attrs):
        identifier = attrs["identifier"].strip()
        password = attrs["password"]
        matched_user = User.objects.filter(username__iexact=identifier).first()
        user = authenticate(
            username=matched_user.username if matched_user else identifier,
            password=password,
        )
        if not user:
            raise serializers.ValidationError("Invalid credentials.")
        device_id = attrs.get("device_id", "").strip()
        profile = user.profile
        if profile.role == UserProfile.ROLE_STUDENT:
            if not device_id:
                raise serializers.ValidationError(
                    "A device ID is required for student login."
                )
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
        device_id = validated_data.get("device_id", "").strip()
        try:
            with transaction.atomic():
                profile = UserProfile.objects.select_for_update().get(
                    pk=user.profile.pk
                )
                if profile.role == UserProfile.ROLE_STUDENT:
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
                    if (
                        profile.registered_device_id
                        and profile.registered_device_id != device_id
                    ):
                        raise serializers.ValidationError(
                            "This student account is already linked to another phone."
                        )
                    if device_id and not profile.registered_device_id:
                        profile.registered_device_id = device_id
                        profile.registered_device_at = timezone.now()
                        profile.save(
                            update_fields=[
                                "registered_device_id",
                                "registered_device_at",
                            ]
                        )
                token, _ = Token.objects.get_or_create(user=user)
        except IntegrityError:
            raise serializers.ValidationError(
                "This phone is already linked to another student account."
            )
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
            "registered_device_id": profile.registered_device_id,
        }
