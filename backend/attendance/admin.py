from django.contrib import admin

from .models import AttendanceProof, AttendanceReplayGuard, Session, UserProfile


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "course_code",
        "course_title",
        "lecturer_name",
        "room",
        "active",
        "starts_at",
        "created_by",
    )
    list_filter = ("active", "course_code", "room", "starts_at")
    search_fields = (
        "course_code",
        "course_title",
        "lecturer_name",
        "room",
        "created_by__user__first_name",
        "created_by__user__username",
    )
    readonly_fields = ("created_at",)
    ordering = ("-starts_at",)


@admin.register(AttendanceProof)
class AttendanceProofAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "student_id",
        "student_name",
        "session",
        "device_display",
        "device_trust_status",
        "scan_mode",
        "rssi",
        "observed_at",
        "created_at",
    )
    list_filter = (
        "device_trust_status",
        "session__course_code",
        "session__room",
        "created_at",
    )
    search_fields = (
        "student_id",
        "device_id",
        "session__course_code",
        "session__course_title",
        "session__lecturer_name",
    )
    readonly_fields = (
        "created_at",
        "signature",
        "acoustic_token",
        "ble_nonce",
        "device_trust_status",
        "device_trust_detail",
        "student_name",
        "scan_mode",
        "device_display",
    )
    ordering = ("-created_at",)
    fieldsets = (
        (
            "Attendance",
            {
                "fields": (
                    "session",
                    "student_id",
                    "student_name",
                    "observed_at",
                    "created_at",
                )
            },
        ),
        (
            "Device Trust",
            {
                "fields": (
                    "device_id",
                    "device_display",
                    "device_trust_status",
                    "device_trust_detail",
                )
            },
        ),
        (
            "Signal Evidence",
            {
                "fields": (
                    "scan_mode",
                    "acoustic_token",
                    "ble_nonce",
                    "rssi",
                    "signature",
                )
            },
        ),
        (
            "Face Fields",
            {
                "classes": ("collapse",),
                "fields": (
                    "face_verification_status",
                    "face_match_score",
                    "attendance_face_image_base64",
                ),
            },
        ),
    )

    @admin.display(description="Student Name")
    def student_name(self, obj):
        try:
            return UserProfile.objects.select_related("user").get(
                matric_number=obj.student_id
            ).user.first_name
        except UserProfile.DoesNotExist:
            return "Unknown"

    @admin.display(description="Device")
    def device_display(self, obj):
        return _display_device_id(obj.device_id)

    @admin.display(description="Mode")
    def scan_mode(self, obj):
        has_acoustic = bool(obj.acoustic_token.strip())
        has_ble = bool(obj.ble_nonce.strip())
        if has_acoustic and has_ble:
            return "Acoustic + BLE"
        if has_acoustic:
            return "Acoustic"
        if has_ble:
            return "BLE"
        return "Unknown"


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "full_name",
        "role",
        "matric_number",
        "username",
        "registered_device_display",
        "registered_device_at",
    )
    list_filter = ("role", "registered_device_at")
    search_fields = (
        "user__first_name",
        "user__username",
        "matric_number",
        "registered_device_id",
    )
    readonly_fields = (
        "full_name",
        "username",
        "registered_device_display",
    )
    ordering = ("role", "matric_number", "user__username")

    @admin.display(description="Full Name")
    def full_name(self, obj):
        return obj.user.first_name

    @admin.display(description="Username")
    def username(self, obj):
        return obj.user.username

    @admin.display(description="Registered Device")
    def registered_device_display(self, obj):
        return _display_device_id(obj.registered_device_id)


@admin.register(AttendanceReplayGuard)
class AttendanceReplayGuardAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "session",
        "student_id",
        "challenge_preview",
        "ble_preview",
        "used_at",
    )
    list_filter = ("session__course_code", "used_at")
    search_fields = (
        "student_id",
        "challenge_token",
        "ble_nonce",
        "session__course_code",
    )
    readonly_fields = ("used_at",)
    ordering = ("-used_at",)

    @admin.display(description="Challenge")
    def challenge_preview(self, obj):
        return _short_value(obj.challenge_token)

    @admin.display(description="BLE Nonce")
    def ble_preview(self, obj):
        return _short_value(obj.ble_nonce)


def _display_device_id(raw_device_id: str) -> str:
    raw = (raw_device_id or "").strip()
    if not raw:
        return "Not linked"
    compact = raw.removeprefix("dev_").replace("-", "").upper()
    suffix = compact if len(compact) <= 8 else compact[-8:]
    return f"DEV-{suffix}"


def _short_value(value: str) -> str:
    cleaned = (value or "").strip()
    if not cleaned:
        return "-"
    if len(cleaned) <= 14:
        return cleaned
    return f"{cleaned[:6]}...{cleaned[-6:]}"
