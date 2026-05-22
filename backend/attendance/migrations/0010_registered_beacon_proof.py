from django.db import migrations, models
import django.db.models.deletion


def seed_cp27_beacon(apps, schema_editor):
    registered_beacon = apps.get_model("attendance", "RegisteredBeacon")
    registered_beacon.objects.get_or_create(
        beacon_type="eddystone_uid",
        namespace_id="e5a4a7e5a48f31323334",
        instance_id="44584c29191a",
        defaults={
            "name": "DX-CP27 Mini Beacon",
            "room": "",
            "rssi_at_1m": -57,
            "min_rssi": -90,
            "tx_power_dbm": 2.5,
            "advertising_interval_ms": 400,
            "active": True,
            "notes": "Default CP27 Eddystone UID configured for first beacon integration tests.",
        },
    )


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0009_wifi_lan_proof"),
    ]

    operations = [
        migrations.CreateModel(
            name="RegisteredBeacon",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("name", models.CharField(max_length=80)),
                ("room", models.CharField(blank=True, max_length=64)),
                (
                    "beacon_type",
                    models.CharField(
                        choices=[
                            ("ibeacon", "iBeacon"),
                            ("eddystone_uid", "Eddystone UID"),
                        ],
                        max_length=32,
                    ),
                ),
                ("uuid", models.CharField(blank=True, max_length=64)),
                ("major", models.IntegerField(blank=True, null=True)),
                ("minor", models.IntegerField(blank=True, null=True)),
                ("namespace_id", models.CharField(blank=True, max_length=32)),
                ("instance_id", models.CharField(blank=True, max_length=32)),
                ("rssi_at_1m", models.IntegerField(default=-57)),
                ("min_rssi", models.IntegerField(default=-90)),
                ("tx_power_dbm", models.FloatField(default=2.5)),
                ("advertising_interval_ms", models.IntegerField(default=400)),
                ("active", models.BooleanField(default=True)),
                ("notes", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_instance_id",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_major",
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_minor",
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_namespace_id",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_proof",
            field=models.CharField(blank=True, max_length=160),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_rssi",
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_type",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="beacon_uuid",
            field=models.CharField(blank=True, max_length=64),
        ),
        migrations.AddField(
            model_name="attendanceproof",
            name="registered_beacon",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="proofs",
                to="attendance.registeredbeacon",
            ),
        ),
        migrations.RunPython(seed_cp27_beacon, migrations.RunPython.noop),
    ]
