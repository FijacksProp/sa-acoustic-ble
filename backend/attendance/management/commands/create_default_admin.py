import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from attendance.models import UserProfile


class Command(BaseCommand):
    help = "Create a non-interactive superuser from environment variables."

    def handle(self, *args, **options):
        username = os.environ.get("DJANGO_SUPERUSER_USERNAME", "").strip()
        email = os.environ.get("DJANGO_SUPERUSER_EMAIL", "").strip()
        password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "").strip()

        if not username or not password:
            self.stdout.write(
                self.style.WARNING(
                    "Skipping admin creation. Set DJANGO_SUPERUSER_USERNAME "
                    "and DJANGO_SUPERUSER_PASSWORD to enable it."
                )
            )
            return

        User = get_user_model()
        user, created = User.objects.get_or_create(
            username=username,
            defaults={
                "email": email,
                "is_staff": True,
                "is_superuser": True,
            },
        )

        if created:
            user.set_password(password)
            user.save(update_fields=["password"])
            self.stdout.write(self.style.SUCCESS(f"Created superuser '{username}'."))
        else:
            changed_fields = []
            if email and user.email != email:
                user.email = email
                changed_fields.append("email")
            if not user.is_staff:
                user.is_staff = True
                changed_fields.append("is_staff")
            if not user.is_superuser:
                user.is_superuser = True
                changed_fields.append("is_superuser")
            if changed_fields:
                user.save(update_fields=changed_fields)
            self.stdout.write(f"Superuser '{username}' already exists.")

        UserProfile.objects.get_or_create(
            user=user,
            defaults={
                "role": UserProfile.ROLE_LECTURER,
                "matric_number": None,
            },
        )
