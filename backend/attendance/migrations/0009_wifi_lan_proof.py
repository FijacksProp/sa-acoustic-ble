from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0008_device_binding"),
    ]

    operations = [
        migrations.AddField(
            model_name="attendanceproof",
            name="wifi_client_ip",
            field=models.GenericIPAddressField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="wifi_proof",
            field=models.CharField(blank=True, max_length=128),
        ),
    ]
