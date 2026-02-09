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
