from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import AttendanceProofCreateAPIView, SessionViewSet


router = DefaultRouter()
router.register("sessions", SessionViewSet, basename="session")

urlpatterns = [
    path("", include(router.urls)),
    path("attendance/", AttendanceProofCreateAPIView.as_view(), name="attendance-create"),
]
