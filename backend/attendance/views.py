from rest_framework import viewsets, generics, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import AttendanceProof, Session
from .serializers import (
    AttendanceProofSerializer,
    SessionSerializer,
    RegisterSerializer,
    LoginSerializer,
)


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


class RegisterAPIView(generics.GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.save()
        return Response(payload, status=status.HTTP_201_CREATED)


class LoginAPIView(generics.GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = LoginSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.save()
        return Response(payload, status=status.HTTP_200_OK)
