from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0010_registered_beacon_proof"),
    ]

    operations = [
        migrations.AddField(
            model_name="session",
            name="attendance_open",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="session",
            name="attendance_opened_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="session",
            name="attendance_closes_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
