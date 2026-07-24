from django.db import migrations, models
from django.db.models import Q


def clear_duplicate_student_device_bindings(apps, schema_editor):
    UserProfile = apps.get_model("attendance", "UserProfile")
    seen = set()
    profiles = UserProfile.objects.filter(
        role="student",
    ).exclude(
        registered_device_id="",
    ).order_by("registered_device_at", "id")
    for profile in profiles.iterator():
        device_id = profile.registered_device_id
        if device_id not in seen:
            seen.add(device_id)
            continue
        profile.registered_device_id = ""
        profile.registered_device_at = None
        profile.save(
            update_fields=["registered_device_id", "registered_device_at"],
        )


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0011_session_attendance_window"),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name="attendancereplayguard",
            unique_together=set(),
        ),
        migrations.RunPython(
            clear_duplicate_student_device_bindings,
            migrations.RunPython.noop,
        ),
        migrations.AddConstraint(
            model_name="attendancereplayguard",
            constraint=models.UniqueConstraint(
                fields=("session", "student_id", "challenge_token"),
                condition=~Q(challenge_token=""),
                name="uniq_student_acoustic_signal",
            ),
        ),
        migrations.AddConstraint(
            model_name="attendancereplayguard",
            constraint=models.UniqueConstraint(
                fields=("session", "student_id", "ble_nonce"),
                condition=~Q(ble_nonce=""),
                name="uniq_student_ble_signal",
            ),
        ),
        migrations.AddConstraint(
            model_name="userprofile",
            constraint=models.UniqueConstraint(
                fields=("registered_device_id",),
                condition=Q(role="student") & ~Q(registered_device_id=""),
                name="unique_student_registered_device",
            ),
        ),
    ]
