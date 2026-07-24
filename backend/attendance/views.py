import re
from datetime import datetime, timedelta, timezone as dt_timezone

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import viewsets, generics, status
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from rest_framework.views import APIView

from .models import AttendanceProof, RegisteredBeacon, Session, UserProfile
from .serializers import (
    AttendanceProofSerializer,
    SessionSerializer,
    RegisterSerializer,
    LoginSerializer,
)


def _close_expired_attendance_sessions():
    Session.objects.filter(
        attendance_open=True,
        attendance_closes_at__isnull=False,
        attendance_closes_at__lte=timezone.now(),
    ).update(attendance_open=False)


class HealthCheckAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response(
            {
                "status": "ok",
                "service": "sa-acoustic-ble-api",
                "time": timezone.now().isoformat(),
            },
            status=status.HTTP_200_OK,
        )


class SessionViewSet(viewsets.ModelViewSet):
    serializer_class = SessionSerializer

    def get_queryset(self):
        _close_expired_attendance_sessions()
        profile = self.request.user.profile
        base = Session.objects.select_related("created_by", "created_by__user")
        if profile.role == UserProfile.ROLE_LECTURER:
            return base.filter(created_by=profile).order_by("-starts_at")
        return base.filter(
            Q(attendance_closes_at__isnull=True) | Q(attendance_closes_at__gt=timezone.now()),
            active=True,
            attendance_open=True,
        ).order_by("-starts_at")

    def perform_create(self, serializer):
        profile = self.request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER:
            raise PermissionDenied("Only lecturers can create sessions.")
        serializer.save(
            created_by=profile,
            lecturer_name=self.request.user.first_name or self.request.user.username,
        )

    def perform_update(self, serializer):
        profile = self.request.user.profile
        instance = self.get_object()
        if (
            profile.role != UserProfile.ROLE_LECTURER
            or instance.created_by_id != profile.id
        ):
            raise PermissionDenied(
                "Only the lecturer who created this session can update it."
            )
        serializer.save(
            lecturer_name=self.request.user.first_name or self.request.user.username,
        )

    def perform_destroy(self, instance):
        profile = self.request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER or instance.created_by_id != profile.id:
            raise PermissionDenied("Only the lecturer who created this session can delete it.")
        instance.delete()

    @action(detail=True, methods=["post"], url_path="open-attendance")
    def open_attendance(self, request, pk=None):
        session = self.get_object()
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER or session.created_by_id != profile.id:
            raise PermissionDenied("Only the lecturer who created this session can open attendance.")
        room = (session.room or "").strip()
        if room:
            room_conflict = Session.objects.filter(
                active=True,
                attendance_open=True,
                room__iexact=room,
            ).exclude(pk=session.pk).exists()
            if room_conflict:
                return Response(
                    {
                        "room": (
                            "Another attendance session is already open in this room. "
                            "Close it before opening a new one."
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )
        now = timezone.now()
        session.active = True
        session.attendance_open = True
        session.attendance_opened_at = now
        session.attendance_closes_at = now + timedelta(
            minutes=settings.ATTENDANCE_WINDOW_MINUTES
        )
        session.save(
            update_fields=[
                "active",
                "attendance_open",
                "attendance_opened_at",
                "attendance_closes_at",
            ]
        )
        return Response(self.get_serializer(session).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="close-attendance")
    def close_attendance(self, request, pk=None):
        session = self.get_object()
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER or session.created_by_id != profile.id:
            raise PermissionDenied("Only the lecturer who created this session can close attendance.")
        session.attendance_open = False
        session.attendance_closes_at = timezone.now()
        session.save(update_fields=["attendance_open", "attendance_closes_at"])
        return Response(self.get_serializer(session).data, status=status.HTTP_200_OK)


class AttendanceProofListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = AttendanceProofSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        queryset = AttendanceProof.objects.select_related(
            "session",
            "registered_beacon",
        ).order_by("-created_at")
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

    def get_serializer_context(self):
        context = super().get_serializer_context()
        if self.request.method != "GET":
            return context
        student_ids = set(
            self.get_queryset().values_list("student_id", flat=True)
        )
        profiles = UserProfile.objects.select_related("user").filter(
            Q(matric_number__in=student_ids) | Q(user__username__in=student_ids)
        )
        context["student_names"] = {
            profile.matric_number or profile.user.username: profile.user.first_name
            for profile in profiles
        }
        return context

    def perform_create(self, serializer):
        profile = self.request.user.profile
        if profile.role != UserProfile.ROLE_STUDENT:
            raise PermissionDenied("Only students can submit attendance proofs.")

        try:
            with transaction.atomic():
                locked_profile = UserProfile.objects.select_for_update().get(pk=profile.pk)
                identity = locked_profile.matric_number or self.request.user.username
                requested = serializer.validated_data.get("student_id", "").strip()
                if requested and requested != identity:
                    raise PermissionDenied(
                        "student_id must match authenticated student identity."
                    )
                submitted_device_id = serializer.validated_data.get(
                    "device_id",
                    "",
                ).strip()
                device_trust_status = AttendanceProof.DEVICE_TRUST_REGISTERED
                device_trust_detail = (
                    "Attendance submitted from the registered student device."
                )

                if not submitted_device_id:
                    raise PermissionDenied("Device ID is required for attendance submission.")

                conflicting_owner = (
                    UserProfile.objects.filter(
                        role=UserProfile.ROLE_STUDENT,
                        registered_device_id=submitted_device_id,
                    )
                    .exclude(pk=locked_profile.pk)
                    .first()
                )
                if conflicting_owner:
                    raise PermissionDenied(
                        "This phone is already linked to another student account. "
                        "Use your registered phone for attendance."
                    )

                if not locked_profile.registered_device_id:
                    locked_profile.registered_device_id = submitted_device_id
                    locked_profile.registered_device_at = timezone.now()
                    locked_profile.save(
                        update_fields=["registered_device_id", "registered_device_at"]
                    )
                    device_trust_status = AttendanceProof.DEVICE_TRUST_BOUND_ON_SUBMIT
                    device_trust_detail = (
                        "This phone has been linked as the student's registered device."
                    )
                elif locked_profile.registered_device_id != submitted_device_id:
                    raise PermissionDenied(
                        "This student account is already linked to another phone. "
                        "Use the registered phone or request a device reset."
                    )

                serializer.save(
                    student_id=identity,
                    device_trust_status=device_trust_status,
                    device_trust_detail=device_trust_detail,
                )
        except IntegrityError:
            raise PermissionDenied(
                "This phone is already linked to another student account."
            )


class ResolveBeaconSessionAPIView(APIView):
    def post(self, request):
        _close_expired_attendance_sessions()
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_STUDENT:
            raise PermissionDenied("Only students can resolve beacon attendance sessions.")

        beacon_proof = (request.data.get("beacon_proof") or "").strip()
        if not beacon_proof:
            return Response(
                {"beacon_proof": "BLE beacon proof is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        beacon_match = AttendanceProofSerializer.BEACON_PATTERN.match(beacon_proof)
        if not beacon_match:
            return Response(
                {"beacon_proof": "Invalid BLE beacon proof format."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        registered_beacon = self._find_registered_beacon(beacon_match)
        if registered_beacon is None:
            return Response(
                {"beacon_proof": "This BLE beacon is not registered for attendance."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        beacon_room = (registered_beacon.room or "").strip()
        if not beacon_room:
            return Response(
                {
                    "beacon_proof": (
                        "This BLE beacon is registered but has not been assigned to a room."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        beacon_rssi = self._parse_rssi(request.data.get("beacon_rssi"))
        if beacon_rssi is not None and beacon_rssi < registered_beacon.min_rssi:
            return Response(
                {"beacon_rssi": "BLE beacon signal is too weak for attendance."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        now = timezone.now()
        sessions = (
            Session.objects.select_related("created_by", "created_by__user")
            .filter(
                active=True,
                attendance_open=True,
                room__iexact=beacon_room,
            )
            .filter(
                Q(attendance_closes_at__isnull=True)
                | Q(attendance_closes_at__gt=now)
            )
            .order_by("-attendance_opened_at", "-starts_at", "-id")
        )
        session = sessions.first()
        if session is None:
            return Response(
                {
                    "session": (
                        "No open attendance session is available for this beacon room."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        if sessions.count() > 1:
            return Response(
                {
                    "session": (
                        "More than one attendance session is open in this room. "
                        "Ask the lecturers to close the conflicting session."
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        return Response(
            {
                "session": SessionSerializer(session).data,
                "beacon": {
                    "id": registered_beacon.id,
                    "name": registered_beacon.name,
                    "room": registered_beacon.room,
                    "beacon_type": registered_beacon.beacon_type,
                    "min_rssi": registered_beacon.min_rssi,
                    "rssi": beacon_rssi,
                    "multiple_open_sessions": False,
                },
            },
            status=status.HTTP_200_OK,
        )

    def _find_registered_beacon(self, beacon_match):
        beacon_type = beacon_match.group("type").lower()
        if beacon_type == RegisteredBeacon.BEACON_TYPE_EDDYSTONE_UID:
            return RegisteredBeacon.objects.filter(
                active=True,
                beacon_type=RegisteredBeacon.BEACON_TYPE_EDDYSTONE_UID,
                namespace_id__iexact=beacon_match.group("a").lower(),
                instance_id__iexact=beacon_match.group("b").lower(),
            ).first()

        try:
            major = int(beacon_match.group("b"))
            minor = int(beacon_match.group("c") or 0)
        except ValueError:
            return None
        return RegisteredBeacon.objects.filter(
            active=True,
            beacon_type=RegisteredBeacon.BEACON_TYPE_IBEACON,
            uuid__iexact=beacon_match.group("a").lower(),
            major=major,
            minor=minor,
        ).first()

    def _parse_rssi(self, raw_value):
        if raw_value in (None, ""):
            return None
        try:
            return int(raw_value)
        except (TypeError, ValueError):
            return None


class BeaconRoomListAPIView(APIView):
    def get(self, request):
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER:
            raise PermissionDenied("Only lecturers can view registered beacon rooms.")

        rooms = [
            room.strip()
            for room in RegisteredBeacon.objects.filter(active=True)
            .exclude(room="")
            .values_list("room", flat=True)
        ]
        unique_rooms = sorted({room for room in rooms if room}, key=str.casefold)
        return Response({"results": unique_rooms}, status=status.HTTP_200_OK)


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


class LogoutAPIView(APIView):
    def post(self, request):
        token = getattr(request, "auth", None)
        if token is not None:
            token.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeAPIView(APIView):
    def get(self, request):
        profile = request.user.profile
        return Response(
            {
                "username": request.user.username,
                "full_name": request.user.first_name,
                "role": profile.role,
                "matric_number": profile.matric_number,
                "registered_device_id": profile.registered_device_id,
                "registered_device_display": self._display_device_id(
                    profile.registered_device_id
                ),
            },
            status=status.HTTP_200_OK,
        )

    def _display_device_id(self, raw_device_id: str) -> str:
        raw = (raw_device_id or "").strip()
        if not raw:
            return "Not linked"
        compact = raw.removeprefix("dev_").replace("-", "").upper()
        suffix = compact if len(compact) <= 8 else compact[-8:]
        return f"DEV-{suffix}"


class AttendanceValidationReportAPIView(APIView):
    ACOUSTIC_PATTERN = re.compile(
        r"^ac\|(?P<session>\d+)\|(?P<version>[A-Za-z0-9_.-]+)\|(?P<issued>\d{10})\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    COMPACT_ACOUSTIC_PATTERN = re.compile(
        r"^ac2\|(?P<session>[A-Za-z0-9]+)\|(?P<issued>[A-Za-z0-9]+)\|(?P<challenge>[A-Za-z0-9_]+)$"
    )
    BLE_PATTERN = re.compile(
        r"^ble\|(?P<session>\d+)\|(?P<issued>\d{10})\|(?P<nonce>[A-Za-z0-9_]+)$"
    )
    WIFI_PATTERN = re.compile(
        r"^wifi\|(?P<session>\d+)\|(?P<issued>\d{10})$"
    )
    BEACON_PATTERN = re.compile(
        r"^beacon\|(?P<type>eddystone_uid|ibeacon)\|"
    )
    def get(self, request):
        profile = request.user.profile
        if profile.role != UserProfile.ROLE_LECTURER:
            raise PermissionDenied("Only lecturers can view validation report.")

        session_id = request.query_params.get("session")
        proofs = (
            AttendanceProof.objects.select_related("session", "registered_beacon")
            .filter(session__created_by=profile)
            .order_by("-created_at")
        )
        if session_id:
            proofs = proofs.filter(session_id=session_id)
        proof_rows = list(proofs)
        student_ids = {proof.student_id for proof in proof_rows}
        student_names = {
            profile.matric_number: profile.user.first_name
            for profile in UserProfile.objects.select_related("user").filter(
                matric_number__in=student_ids
            )
        }
        items = [
            self._build_item(
                proof,
                student_names.get(proof.student_id, "Unknown"),
            )
            for proof in proof_rows
        ]
        return Response({"results": items}, status=status.HTTP_200_OK)

    def _build_item(self, proof: AttendanceProof, student_name: str):
        passed = []
        failed = []

        acoustic_token = proof.acoustic_token.strip()
        ble_nonce = proof.ble_nonce.strip()
        wifi_proof = proof.wifi_proof.strip()
        beacon_proof = proof.beacon_proof.strip()
        am = self.ACOUSTIC_PATTERN.match(acoustic_token) if acoustic_token else None
        acm = (
            self.COMPACT_ACOUSTIC_PATTERN.match(acoustic_token)
            if acoustic_token
            else None
        )
        acoustic_match = acm or am
        bm = self.BLE_PATTERN.match(ble_nonce) if ble_nonce else None
        wm = self.WIFI_PATTERN.match(wifi_proof) if wifi_proof else None
        beacon_match = self.BEACON_PATTERN.match(beacon_proof) if beacon_proof else None
        if acoustic_match:
            passed.append("Acoustic format")
        elif acoustic_token:
            failed.append("Acoustic format")
        else:
            passed.append("Acoustic not supplied")
        if bm:
            passed.append("BLE format")
        elif ble_nonce:
            failed.append("BLE format")
        else:
            passed.append("BLE not supplied")
        if wm:
            passed.append("Wi-Fi/LAN format")
        elif wifi_proof:
            failed.append("Wi-Fi/LAN format")
        else:
            passed.append("Wi-Fi/LAN not supplied")
        if beacon_match:
            passed.append("BLE beacon format")
        elif beacon_proof:
            failed.append("BLE beacon format")
        else:
            passed.append("BLE beacon not supplied")

        ac_age = None
        ble_age = None
        wifi_age = None
        if acoustic_match:
            if acm:
                ac_session = int(acm.group("session"), 36)
                ac_issued_epoch = int(acm.group("issued"), 36)
            else:
                ac_session = int(am.group("session"))
                ac_issued_epoch = int(am.group("issued"))
            ac_issued = datetime.fromtimestamp(ac_issued_epoch, tz=dt_timezone.utc)
            ac_age = int((proof.observed_at - ac_issued).total_seconds())
            if ac_session == proof.session_id:
                passed.append("Acoustic session match")
            else:
                failed.append("Acoustic session mismatch")
            passed.append("Acoustic freshness accepted at submission")
        if bm:
            ble_session = int(bm.group("session"))
            ble_issued = datetime.fromtimestamp(int(bm.group("issued")), tz=dt_timezone.utc)
            ble_age = int((proof.observed_at - ble_issued).total_seconds())
            if ble_session == proof.session_id:
                passed.append("BLE session match")
            else:
                failed.append("BLE session mismatch")
            passed.append("BLE freshness accepted at submission")
        if wm:
            wifi_session = int(wm.group("session"))
            wifi_issued = datetime.fromtimestamp(int(wm.group("issued")), tz=dt_timezone.utc)
            wifi_age = int((proof.observed_at - wifi_issued).total_seconds())
            if wifi_session == proof.session_id:
                passed.append("Wi-Fi/LAN session match")
            else:
                failed.append("Wi-Fi/LAN session mismatch")
            passed.append("Wi-Fi/LAN freshness accepted at submission")

        if acoustic_match and bm and wm and beacon_match:
            passed.append("Proof path: acoustic_ble_wifi_beacon")
        elif acoustic_match and bm and beacon_match:
            passed.append("Proof path: acoustic_ble_beacon")
        elif bm and beacon_match:
            passed.append("Proof path: lecturer_ble_beacon")
        elif acoustic_match and beacon_match:
            passed.append("Proof path: acoustic_beacon")
        elif beacon_match:
            passed.append("Proof path: ble_beacon")
        elif acoustic_match and bm and wm:
            passed.append("Proof path: acoustic_ble_wifi")
        elif acoustic_match and bm:
            passed.append("Proof path: acoustic_ble")
        elif acoustic_match and wm:
            passed.append("Proof path: acoustic_wifi")
        elif bm and wm:
            passed.append("Proof path: ble_wifi")
        elif acoustic_match:
            passed.append("Proof path: acoustic_only")
        elif bm:
            passed.append("Proof path: ble_only")
        elif wm:
            passed.append("Proof path: wifi_lan")
        else:
            failed.append("Proof path missing")

        return {
            "proof_id": proof.id,
            "session_id": proof.session_id,
            "student_id": proof.student_id,
            "student_name": student_name,
            "course_code": proof.session.course_code,
            "course_title": proof.session.course_title,
            "lecturer_name": proof.session.lecturer_name,
            "room": proof.session.room,
            "observed_at": proof.observed_at,
            "acoustic_age_seconds": ac_age,
            "ble_age_seconds": ble_age,
            "wifi_age_seconds": wifi_age,
            "wifi_client_ip": proof.wifi_client_ip,
            "beacon_proof": proof.beacon_proof,
            "beacon_type": proof.beacon_type,
            "beacon_namespace_id": proof.beacon_namespace_id,
            "beacon_instance_id": proof.beacon_instance_id,
            "beacon_uuid": proof.beacon_uuid,
            "beacon_major": proof.beacon_major,
            "beacon_minor": proof.beacon_minor,
            "beacon_rssi": proof.beacon_rssi,
            "registered_beacon_name": (
                proof.registered_beacon.name if proof.registered_beacon else ""
            ),
            "device_id": proof.device_id,
            "device_trust_status": proof.device_trust_status,
            "device_trust_detail": proof.device_trust_detail,
            "passed_checks": passed,
            "failed_checks": failed,
            "status": "pass" if not failed else "fail",
        }
