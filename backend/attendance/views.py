from rest_framework import viewsets, generics

from .models import AttendanceProof, Session
from .serializers import AttendanceProofSerializer, SessionSerializer


class SessionViewSet(viewsets.ModelViewSet):
    queryset = Session.objects.all().order_by("-starts_at")
    serializer_class = SessionSerializer


class AttendanceProofListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = AttendanceProofSerializer

    def get_queryset(self):
        queryset = AttendanceProof.objects.select_related("session").order_by("-created_at")
        session_id = self.request.query_params.get("session")
        student_id = self.request.query_params.get("student_id")

        if session_id:
            queryset = queryset.filter(session_id=session_id)
        if student_id:
            queryset = queryset.filter(student_id=student_id.strip())
        return queryset
