from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0007_attendanceproof_face_match_score"),
    ]

    operations = [
        migrations.AddField(
            model_name="attendanceproof",
            name="device_trust_detail",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="device_trust_status",
            field=models.CharField(
                choices=[
                    ("registered_device", "Registered Device"),
                    ("bound_on_submit", "Bound On Submit"),
                ],
                default="registered_device",
                max_length=32,
            ),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="registered_device_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="registered_device_id",
            field=models.CharField(blank=True, max_length=128),
        ),
    ]
