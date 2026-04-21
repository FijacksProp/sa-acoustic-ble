from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("attendance", "0006_face_verification_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="attendanceproof",
            name="face_match_score",
            field=models.FloatField(default=0),
        ),
    ]
