from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    AttendanceProofListCreateAPIView,
    SessionViewSet,
    RegisterAPIView,
    LoginAPIView,
    FaceEnrollmentAPIView,
    MeAPIView,
    AttendanceValidationReportAPIView,
)


router = DefaultRouter()
router.register("sessions", SessionViewSet, basename="session")

urlpatterns = [
    path("", include(router.urls)),
    path("attendance/", AttendanceProofListCreateAPIView.as_view(), name="attendance-list-create"),
    path("attendance/report/", AttendanceValidationReportAPIView.as_view(), name="attendance-validation-report"),
    path("auth/register/", RegisterAPIView.as_view(), name="auth-register"),
    path("auth/login/", LoginAPIView.as_view(), name="auth-login"),
    path("auth/face-enrollment/", FaceEnrollmentAPIView.as_view(), name="auth-face-enrollment"),
    path("auth/me/", MeAPIView.as_view(), name="auth-me"),
]
