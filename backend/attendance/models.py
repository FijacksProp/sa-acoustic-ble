from django.db import models
from django.contrib.auth.models import User


class Session(models.Model):
    course_code = models.CharField(max_length=32)
    course_title = models.CharField(max_length=128, blank=True)
    lecturer_name = models.CharField(max_length=128)
    room = models.CharField(max_length=64, blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    token_version = models.CharField(max_length=32, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"{self.course_code} - {self.starts_at:%Y-%m-%d %H:%M}"


class AttendanceProof(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name="proofs")
    student_id = models.CharField(max_length=64)
    device_id = models.CharField(max_length=128)

    acoustic_token = models.CharField(max_length=128)
    ble_nonce = models.CharField(max_length=128)
    rssi = models.IntegerField()

    observed_at = models.DateTimeField()
    signature = models.TextField()

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

    def __str__(self) -> str:
        return f"{self.matric_number} ({self.role})"
