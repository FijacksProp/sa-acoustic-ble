from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0005_attendancereplayguard"),
    ]

    operations = [
        migrations.AddField(
            model_name="attendanceproof",
            name="attendance_face_image_base64",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="face_verification_status",
            field=models.CharField(default="pending_review", max_length=32),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="face_image_base64",
            field=models.TextField(blank=True),
        ),
    ]
