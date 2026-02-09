from rest_framework import viewsets, generics

from .models import AttendanceProof, Session
from .serializers import AttendanceProofSerializer, SessionSerializer


class SessionViewSet(viewsets.ModelViewSet):
    queryset = Session.objects.all().order_by("-starts_at")
    serializer_class = SessionSerializer


class AttendanceProofCreateAPIView(generics.CreateAPIView):
    queryset = AttendanceProof.objects.all()
    serializer_class = AttendanceProofSerializer
