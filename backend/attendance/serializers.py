from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from .models import AttendanceProof, Session


class SessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Session
        fields = [
            "id",
            "course_code",
            "course_title",
            "lecturer_name",
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

        # Application-level duplicate guard for clearer API errors.
        session = attrs["session"]
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
