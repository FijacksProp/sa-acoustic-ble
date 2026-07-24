from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    AttendanceProofListCreateAPIView,
    BeaconRoomListAPIView,
    HealthCheckAPIView,
    ResolveBeaconSessionAPIView,
    SessionViewSet,
    RegisterAPIView,
    LoginAPIView,
    LogoutAPIView,
    MeAPIView,
    AttendanceValidationReportAPIView,
)


router = DefaultRouter()
router.register("sessions", SessionViewSet, basename="session")

urlpatterns = [
    path("", include(router.urls)),
    path("health/", HealthCheckAPIView.as_view(), name="health-check"),
    path(
        "attendance/",
        AttendanceProofListCreateAPIView.as_view(),
        name="attendance-list-create",
    ),
    path(
        "attendance/resolve-beacon-session/",
        ResolveBeaconSessionAPIView.as_view(),
        name="attendance-resolve-beacon-session",
    ),
    path(
        "attendance/report/",
        AttendanceValidationReportAPIView.as_view(),
        name="attendance-validation-report",
    ),
    path("beacon-rooms/", BeaconRoomListAPIView.as_view(), name="beacon-room-list"),
    path("auth/register/", RegisterAPIView.as_view(), name="auth-register"),
    path("auth/login/", LoginAPIView.as_view(), name="auth-login"),
    path("auth/logout/", LogoutAPIView.as_view(), name="auth-logout"),
    path("auth/me/", MeAPIView.as_view(), name="auth-me"),
]
