import re
from datetime import timedelta, datetime, timezone as dt_timezone

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework import serializers
from django.db import IntegrityError

from .models import AttendanceProof, Session, UserProfile, AttendanceReplayGuard


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
            "token_version",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class AttendanceProofSerializer(serializers.ModelSerializer):
    FRESHNESS_WINDOW_SECONDS = 120
    SIGNAL_EXPIRY_SECONDS = 60
    ACOUSTIC_PATTERN = re.compile(
        r"^ac\|(?P<session>\d+)\|(?P<version>[A-Za-z0-9_.-]+)\|(?P<issued>\d{10})\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    BLE_PATTERN = re.compile(
        r"^ble\|(?P<session>\d+)\|(?P<issued>\d{10})\|(?P<nonce>[A-Za-z0-9_]+)$"
    )

    class Meta:
        model = AttendanceProof
        fields = [
            "id",
            "session",
            "student_id",
            "device_id",
            "acoustic_token",
            "ble_nonce",
            "rssi",
            "observed_at",
            "signature",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

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
        if not session.created_by or session.created_by.role != UserProfile.ROLE_LECTURER:
            raise serializers.ValidationError(
                {"session": "Session must belong to an active lecturer owner."}
            )

        acoustic = attrs["acoustic_token"].strip()
        ble = attrs["ble_nonce"].strip()
        acoustic_match = self.ACOUSTIC_PATTERN.match(acoustic)
        if not acoustic_match:
            raise serializers.ValidationError(
                {"acoustic_token": "Invalid acoustic token format."}
            )
        ble_match = self.BLE_PATTERN.match(ble)
        if not ble_match:
            raise serializers.ValidationError({"ble_nonce": "Invalid BLE nonce format."})

        ac_session = int(acoustic_match.group("session"))
        ble_session = int(ble_match.group("session"))
        if ac_session != session.id or ble_session != session.id:
            raise serializers.ValidationError(
                {"session": "Payload session_id does not match selected session."}
            )

        ac_issued = datetime.fromtimestamp(
            int(acoustic_match.group("issued")), tz=dt_timezone.utc
        )
        ble_issued = datetime.fromtimestamp(
            int(ble_match.group("issued")), tz=dt_timezone.utc
        )
        if (now - ac_issued).total_seconds() > self.SIGNAL_EXPIRY_SECONDS or (
            now - ac_issued
        ).total_seconds() < -10:
            raise serializers.ValidationError(
                {"acoustic_token": "Acoustic token has expired."}
            )
        if (now - ble_issued).total_seconds() > self.SIGNAL_EXPIRY_SECONDS or (
            now - ble_issued
        ).total_seconds() < -10:
            raise serializers.ValidationError({"ble_nonce": "BLE nonce has expired."})

        challenge_token = acoustic_match.group("challenge")
        ble_nonce_value = ble_match.group("nonce")
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
        attrs["signature"] = attrs["signature"].strip()
        return attrs

    def create(self, validated_data):
        challenge_token = validated_data.pop("_decoded_challenge_token", None)
        ble_nonce_value = validated_data.pop("_decoded_ble_nonce", None)
        proof = super().create(validated_data)
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
        if not cleaned:
            raise serializers.ValidationError("acoustic_token cannot be empty.")
        return cleaned

    def validate_ble_nonce(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("ble_nonce cannot be empty.")
        return cleaned

    def validate_signature(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("signature cannot be empty.")
        return cleaned


class RegisterSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    matric_number = serializers.CharField(max_length=64, required=False, allow_blank=True)
    username = serializers.CharField(max_length=150, required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=UserProfile.ROLE_CHOICES)
    password = serializers.CharField(write_only=True, min_length=6)

    def validate(self, attrs):
        role = attrs["role"]
        matric_number = attrs.get("matric_number", "").strip()
        username = attrs.get("username", "").strip()

        if role == UserProfile.ROLE_STUDENT:
            if not matric_number:
                raise serializers.ValidationError(
                    {"matric_number": "matric_number is required for students."}
                )
            if UserProfile.objects.filter(matric_number=matric_number).exists():
                raise serializers.ValidationError(
                    {"matric_number": "matric_number already registered."}
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

        user = User.objects.create_user(
            username=username,
            first_name=full_name,
            password=password,
        )
        profile = UserProfile.objects.create(
            user=user,
            matric_number=matric_number,
            role=role,
        )
        token, _ = Token.objects.get_or_create(user=user)
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
        }


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField(max_length=150)
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        identifier = attrs["identifier"].strip()
        password = attrs["password"]
        user = authenticate(username=identifier, password=password)
        if not user:
            raise serializers.ValidationError("Invalid credentials.")
        attrs["user"] = user
        return attrs

    def create(self, validated_data):
        user = validated_data["user"]
        profile = user.profile
        token, _ = Token.objects.get_or_create(user=user)
        return {
            "token": token.key,
            "matric_number": profile.matric_number,
            "username": user.username,
            "role": profile.role,
            "full_name": user.first_name,
        }
