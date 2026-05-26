# Render + Supabase Deployment Guide

This guide prepares the project for a hosted backend:

```text
Flutter APK -> Render Django API -> Supabase PostgreSQL
```

The mobile app should still scan acoustic/BLE signals locally. Only login, session creation, proof submission, reports, and admin work go through the hosted API.

## 1. Create the Supabase Database

1. Create a Supabase project.
2. Open **Project Settings -> Database**.
3. Copy the PostgreSQL connection string.
4. Prefer the pooled connection string if Supabase recommends it for external services.
5. Add `?sslmode=require` to the end of the connection string if it is not already present.

Example format:

```text
postgresql://USER:PASSWORD@HOST:PORT/postgres?sslmode=require
```

Use the exact value from Supabase, not the example above.

## 2. Create the Render Web Service

On Render:

1. Create a new **Web Service**.
2. Connect the GitHub repository.
3. Set the root directory to:

```text
backend
```

4. Set the build command:

```bash
pip install -r requirements.txt && python manage.py collectstatic --noinput && python manage.py migrate && python manage.py create_default_admin
```

5. Set the start command:

```bash
gunicorn config.wsgi:application
```

## 3. Render Environment Variables

Set these in the Render dashboard.

```text
DJANGO_DEBUG=False
SECRET_KEY=generate-a-long-random-django-secret
DATABASE_URL=your-supabase-postgres-url-with-sslmode-require
ALLOWED_HOSTS=your-render-service.onrender.com
CSRF_TRUSTED_ORIGINS=https://your-render-service.onrender.com
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=your-email@example.com
DJANGO_SUPERUSER_PASSWORD=choose-a-strong-password
```

Optional:

```text
CORS_ALLOWED_ORIGINS=https://your-frontend-domain.com
DB_SSLMODE=require
```

Render currently supports setting Python through `.python-version` or `PYTHON_VERSION`. This backend includes `backend/.python-version` for Python `3.14.3`.

## 4. Health Check and Wake-Up URL

After deployment, open this before demos to wake the free Render service:

```text
https://your-render-service.onrender.com/api/health/
```

Expected response:

```json
{
  "status": "ok",
  "service": "sa-acoustic-ble-api",
  "time": "..."
}
```

Render free services may sleep after inactivity, so open the health URL a few minutes before testing.

## 5. Build the APK Against Render

Once Render is live, rebuild the APK with the hosted API URL:

```powershell
cd C:\Users\HP\Desktop\SAS\sa-acoustic-ble\mobile\app
flutter build apk --debug --dart-define=API_BASE_URL=https://your-render-service.onrender.com
```

The APK will be created at:

```text
mobile/app/build/app/outputs/flutter-apk/app-debug.apk
```

## 6. Admin Panel

The deployment command creates a superuser automatically from the `DJANGO_SUPERUSER_*` environment variables.

Open:

```text
https://your-render-service.onrender.com/admin/
```

Use the admin username and password you set in Render.

## 7. Local Development Still Works

If `DATABASE_URL` is not set, Django still uses local SQLite:

```powershell
cd backend
python manage.py runserver 0.0.0.0:8000
```

That means hosted deployment and local testing can coexist.
