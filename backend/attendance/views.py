import re
from datetime import datetime, timezone as dt_timezone

from rest_framework import viewsets, generics, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from rest_framework.views import APIView

from .models import AttendanceProof, Session, UserProfile
from .serializers import (
    AttendanceProofSerializer,
    SessionSerializer,
    RegisterSerializer,
    LoginSerializer,
)


class SessionViewSet(viewsets.ModelViewSet):
    serializer_class = SessionSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        base = Session.objects.select_related("created_by", "created_by__user")
        if profile.role == UserProfile.ROLE_LECTURER:
            return base.filter(created_by=profile).order_by("-starts_at")
        return base.filter(active=True).order_by("-starts_at")

    def perform_create(self, serializer):
        profile = self.request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER:
            raise PermissionDenied("Only lecturers can create sessions.")
        serializer.save(created_by=profile)


class AttendanceProofListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = AttendanceProofSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        queryset = AttendanceProof.objects.select_related("session").order_by("-created_at")
        if profile.role == UserProfile.ROLE_LECTURER:
            queryset = queryset.filter(session__created_by=profile)
        else:
            identity = profile.matric_number or self.request.user.username
            queryset = queryset.filter(student_id=identity)

        session_id = self.request.query_params.get("session")
        student_id = self.request.query_params.get("student_id")

        if session_id:
            queryset = queryset.filter(session_id=session_id)
        if student_id and profile.role == UserProfile.ROLE_LECTURER:
            queryset = queryset.filter(student_id=student_id.strip())
        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        if profile.role != UserProfile.ROLE_STUDENT:
            raise PermissionDenied("Only students can submit attendance proofs.")

        identity = profile.matric_number or self.request.user.username
        requested = serializer.validated_data.get("student_id", "").strip()
        if requested and requested != identity:
            raise PermissionDenied("student_id must match authenticated student identity.")
        serializer.save(student_id=identity)


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


class AttendanceValidationReportAPIView(APIView):
    ACOUSTIC_PATTERN = re.compile(
        r"^ac\|(?P<session>\d+)\|(?P<version>[A-Za-z0-9_.-]+)\|(?P<issued>\d{10})\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    BLE_PATTERN = re.compile(
        r"^ble\|(?P<session>\d+)\|(?P<issued>\d{10})\|(?P<nonce>[A-Za-z0-9_]+)$"
    )
    EXPIRY_SECONDS = 60

    def get(self, request):
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER:
            raise PermissionDenied("Only lecturers can view validation report.")

        proofs = (
            AttendanceProof.objects.select_related("session")
            .filter(session__created_by=profile)
            .order_by("-created_at")[:100]
        )
        items = [self._build_item(proof) for proof in proofs]
        return Response({"results": items}, status=status.HTTP_200_OK)

    def _build_item(self, proof: AttendanceProof):
        passed = []
        failed = []
        now = datetime.now(dt_timezone.utc)

        am = self.ACOUSTIC_PATTERN.match(proof.acoustic_token.strip())
        bm = self.BLE_PATTERN.match(proof.ble_nonce.strip())
        if am:
            passed.append("Acoustic format")
        else:
            failed.append("Acoustic format")
        if bm:
            passed.append("BLE format")
        else:
            failed.append("BLE format")

        ac_age = None
        ble_age = None
        if am:
            ac_session = int(am.group("session"))
            ac_issued = datetime.fromtimestamp(int(am.group("issued")), tz=dt_timezone.utc)
            ac_age = int((now - ac_issued).total_seconds())
            if ac_session == proof.session_id:
                passed.append("Acoustic session match")
            else:
                failed.append("Acoustic session mismatch")
            if 0 <= ac_age <= self.EXPIRY_SECONDS:
                passed.append("Acoustic freshness")
            else:
                failed.append("Acoustic freshness")
        if bm:
            ble_session = int(bm.group("session"))
            ble_issued = datetime.fromtimestamp(int(bm.group("issued")), tz=dt_timezone.utc)
            ble_age = int((now - ble_issued).total_seconds())
            if ble_session == proof.session_id:
                passed.append("BLE session match")
            else:
                failed.append("BLE session mismatch")
            if 0 <= ble_age <= self.EXPIRY_SECONDS:
                passed.append("BLE freshness")
            else:
                failed.append("BLE freshness")

        return {
            "proof_id": proof.id,
            "session_id": proof.session_id,
            "student_id": proof.student_id,
            "observed_at": proof.observed_at,
            "acoustic_age_seconds": ac_age,
            "ble_age_seconds": ble_age,
            "passed_checks": passed,
            "failed_checks": failed,
            "status": "pass" if not failed else "fail",
        }
