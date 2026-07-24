from django.db import models
from django.contrib.auth.models import User
from django.db.models import Q


class Session(models.Model):
    course_code = models.CharField(max_length=32)
    course_title = models.CharField(max_length=128, blank=True)
    lecturer_name = models.CharField(max_length=128)
    created_by = models.ForeignKey(
        "UserProfile",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_sessions",
    )
    room = models.CharField(max_length=64, blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    attendance_open = models.BooleanField(default=False)
    attendance_opened_at = models.DateTimeField(null=True, blank=True)
    attendance_closes_at = models.DateTimeField(null=True, blank=True)
    token_version = models.CharField(max_length=32, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"{self.course_code} - {self.starts_at:%Y-%m-%d %H:%M}"


class AttendanceProof(models.Model):
    DEVICE_TRUST_REGISTERED = "registered_device"
    DEVICE_TRUST_BOUND_ON_SUBMIT = "bound_on_submit"
    DEVICE_TRUST_CHOICES = [
        (DEVICE_TRUST_REGISTERED, "Registered Device"),
        (DEVICE_TRUST_BOUND_ON_SUBMIT, "Bound On Submit"),
    ]

    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="proofs")
    student_id = models.CharField(max_length=64)
    device_id = models.CharField(max_length=128)
    device_trust_status = models.CharField(
        max_length=32,
        choices=DEVICE_TRUST_CHOICES,
        default=DEVICE_TRUST_REGISTERED,
    )
    device_trust_detail = models.CharField(max_length=255, blank=True)

    acoustic_token = models.CharField(max_length=128)
    ble_nonce = models.CharField(max_length=128)
    wifi_proof = models.CharField(max_length=128, blank=True)
    wifi_client_ip = models.GenericIPAddressField(null=True, blank=True)
    beacon_proof = models.CharField(max_length=160, blank=True)
    beacon_type = models.CharField(max_length=32, blank=True)
    beacon_uuid = models.CharField(max_length=64, blank=True)
    beacon_major = models.IntegerField(null=True, blank=True)
    beacon_minor = models.IntegerField(null=True, blank=True)
    beacon_namespace_id = models.CharField(max_length=32, blank=True)
    beacon_instance_id = models.CharField(max_length=32, blank=True)
    beacon_rssi = models.IntegerField(null=True, blank=True)
    registered_beacon = models.ForeignKey(
        "RegisteredBeacon",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="proofs",
    )
    rssi = models.IntegerField()

    observed_at = models.DateTimeField()
    signature = models.TextField()
    attendance_face_image_base64 = models.TextField(blank=True)
    face_verification_status = models.CharField(max_length=32, default="pending_review")
    face_match_score = models.FloatField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("session", "student_id")

    def __str__(self) -> str:
        return f"{self.student_id} @ {self.session_id}"


class UserProfile(models.Model):
    ROLE_STUDENT = "student"
    ROLE_LECTURER = "lecturer"
    ROLE_CHOICES = [
        (ROLE_STUDENT, "Student"),
        (ROLE_LECTURER, "Lecturer"),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    matric_number = models.CharField(max_length=64, unique=True, null=True, blank=True)
    role = models.CharField(max_length=16, choices=ROLE_CHOICES)
    face_image_base64 = models.TextField(blank=True)
    registered_device_id = models.CharField(max_length=128, blank=True)
    registered_device_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("registered_device_id",),
                condition=Q(role="student") & ~Q(registered_device_id=""),
                name="unique_student_registered_device",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.matric_number} ({self.role})"


class RegisteredBeacon(models.Model):
    BEACON_TYPE_IBEACON = "ibeacon"
    BEACON_TYPE_EDDYSTONE_UID = "eddystone_uid"
    BEACON_TYPE_CHOICES = [
        (BEACON_TYPE_IBEACON, "iBeacon"),
        (BEACON_TYPE_EDDYSTONE_UID, "Eddystone UID"),
    ]

    name = models.CharField(max_length=80)
    room = models.CharField(max_length=64, blank=True)
    beacon_type = models.CharField(max_length=32, choices=BEACON_TYPE_CHOICES)
    uuid = models.CharField(max_length=64, blank=True)
    major = models.IntegerField(null=True, blank=True)
    minor = models.IntegerField(null=True, blank=True)
    namespace_id = models.CharField(max_length=32, blank=True)
    instance_id = models.CharField(max_length=32, blank=True)
    rssi_at_1m = models.IntegerField(default=-57)
    min_rssi = models.IntegerField(default=-90)
    tx_power_dbm = models.FloatField(default=2.5)
    advertising_interval_ms = models.IntegerField(default=400)
    active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        room = f" / {self.room}" if self.room else ""
        return f"{self.name}{room}"


class AttendanceReplayGuard(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="replay_guards")
    challenge_token = models.CharField(max_length=128)
    ble_nonce = models.CharField(max_length=128)
    student_id = models.CharField(max_length=64)
    used_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=("session", "student_id", "challenge_token"),
                condition=~Q(challenge_token=""),
                name="uniq_student_acoustic_signal",
            ),
            models.UniqueConstraint(
                fields=("session", "student_id", "ble_nonce"),
                condition=~Q(ble_nonce=""),
                name="uniq_student_ble_signal",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.session_id}:{self.challenge_token}:{self.ble_nonce}"
