import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'core/session_store.dart';
import 'core/api_config.dart';
import 'core/error_messages.dart';
import 'face/auto_face_capture_screen.dart';
import 'models/attendance_proof_model.dart';
import 'models/scan_result_model.dart';
import 'models/scan_test_log_model.dart';
import 'models/session_model.dart';
import 'models/validation_report_item_model.dart';
import 'services/attendance_api_service.dart';
import 'services/acoustic_scan_service.dart';
import 'services/ble_scan_service.dart';
import 'services/auth_service.dart';
import 'services/lecturer_broadcast_service.dart';
import 'services/scan_test_log_service.dart';
import 'services/signal_payload_codec.dart';
import 'services/signal_transport_service.dart';

void main() {
  runApp(const SaAcousticBleApp());
}

Future<AutoFaceCaptureResult?> _captureFaceImage(
  BuildContext context, {
  required String title,
  required String subtitle,
}) async {
  return Navigator.of(context).push<AutoFaceCaptureResult>(
    MaterialPageRoute(
      builder: (_) => AutoFaceCaptureScreen(
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
}

String _friendlyAcousticResult(ScanResultModel scan, bool trusted) {
  if (trusted) {
    return 'Acoustic signal captured.';
  }
  return switch (scan.source) {
    'microphone_no_decode' => 'No acoustic signal was decoded. Move closer, reduce noise, and scan again.',
    'platform_exception' => 'Microphone scan could not start. Check microphone permission.',
    'missing_plugin' => 'Acoustic scanning is only available on the Android app.',
    'native_no_result' => 'The microphone did not return a scan result.',
    'web_no_broadcast' => 'No web broadcast is active.',
    _ => 'Acoustic signal was not captured.',
  };
}

String _friendlyBleResult(ScanResultModel scan, bool trusted) {
  if (trusted) {
    return 'BLE signal captured.';
  }
  return switch (scan.source) {
    'ble_scan_not_ready' => 'Bluetooth permission is needed. Allow the prompt and scan again.',
    'ble_adapter_not_ready' => 'Bluetooth is off. Turn it on on both phones and scan again.',
    'ble_scan_empty' => 'No nearby BLE broadcast was found. Confirm the lecturer broadcast is running.',
    'ble_scan_unparsed_device' => 'BLE saw nearby devices, but not the lecturer broadcast yet.',
    'ble_scan_error' => 'BLE scan could not start. Check Bluetooth permissions and try again.',
    'ble_scan_beacon_eddystone_uid' => 'Lecturer BLE was not used; room beacon was captured.',
    'ble_scan_beacon_ibeacon' => 'Lecturer BLE was not used; room beacon was captured.',
    'web_no_ble' => 'Real BLE scanning is only available on Android.',
    _ => 'Lecturer BLE signal was not captured.',
  };
}

String _friendlyBeaconResult(ScanResultModel scan, bool trusted) {
  if (trusted) {
    return 'Registered beacon signal captured.';
  }
  return switch (scan.source) {
    'ble_scan_beacon_eddystone_uid' => 'Beacon was detected but is not ready for submission.',
    'ble_scan_beacon_ibeacon' => 'Beacon was detected but is not ready for submission.',
    _ => 'No registered BLE beacon was captured.',
  };
}

String _proofScanModeLabel({
  required String acousticToken,
  required String bleNonce,
  String wifiProof = '',
  String beaconProof = '',
}) {
  final hasAcoustic = acousticToken.trim().isNotEmpty;
  final hasBle = bleNonce.trim().isNotEmpty;
  final hasWifi = wifiProof.trim().isNotEmpty;
  final hasBeacon = beaconProof.trim().isNotEmpty;
  final modes = <String>[
    if (hasAcoustic) 'Acoustic',
    if (hasBle) 'BLE',
    if (hasWifi) 'Wi-Fi',
    if (hasBeacon) 'BLE Beacon',
  ];
  if (modes.isNotEmpty) {
    return modes.join(' + ');
  }
  return 'Unknown';
}

String _permissionPromptMessage(
  Object? missing, {
  required String fallback,
}) {
  final values = (missing is List ? missing : const [])
      .map((item) => item.toString())
      .toSet();
  if (values.isEmpty) {
    return fallback;
  }
  final labels = <String>[
    if (values.contains('microphone')) 'Microphone',
    if (values.contains('location')) 'Location',
    if (values.contains('nearby_devices')) 'Nearby Devices / Bluetooth',
  ];
  if (labels.isEmpty) {
    return fallback;
  }
  return 'Permission needed: ${labels.join(', ')}. Allow the permission prompt, then try again.';
}

String _readinessPromptMessage(
  Map<String, dynamic>? readiness, {
  required String fallback,
}) {
  if (readiness?['status'] == 'bluetooth_off') {
    return 'Bluetooth is off. Turn Bluetooth on, then try again.';
  }
  return _permissionPromptMessage(readiness?['missing'], fallback: fallback);
}

_ChipTone _proofScanModeTone(String mode) {
  if (mode == 'Unknown') {
    return _ChipTone.neutral;
  }
  return _ChipTone.success;
}

class _AppPalette {
  static const ink = Color(0xFF17242C);
  static const muted = Color(0xFF69767F);
  static const canvas = Color(0xFFF7F4ED);
  static const surface = Color(0xFFFFFCF7);
  static const surfaceAlt = Color(0xFFF0EAE0);
  static const line = Color(0xFFD9D0C3);
  static const navy = Color(0xFF0A3246);
  static const teal = Color(0xFF0B746C);
  static const tealSoft = Color(0xFFE2F1EC);
  static const amber = Color(0xFFB47A20);
  static const amberSoft = Color(0xFFF4E8D0);
  static const red = Color(0xFFB44535);
  static const redSoft = Color(0xFFF5DEDA);
  static const green = Color(0xFF237A52);
  static const greenSoft = Color(0xFFE1F1E8);
}

class _AppRadii {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 22.0;
  static const xlarge = 28.0;
}

class SaAcousticBleApp extends StatelessWidget {
  const SaAcousticBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _AppPalette.teal,
      brightness: Brightness.light,
    ).copyWith(
      primary: _AppPalette.teal,
      surface: _AppPalette.surface,
    );
    return MaterialApp(
      title: 'SA Acoustic BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _AppPalette.canvas,
        fontFamily: 'Roboto',
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: _AppPalette.ink,
              displayColor: _AppPalette.ink,
              fontFamily: 'Roboto',
            ),
        dividerTheme: DividerThemeData(
          color: _AppPalette.line.withOpacity(0.75),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _AppPalette.navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_AppRadii.medium),
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _AppPalette.canvas,
          foregroundColor: _AppPalette.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            color: _AppPalette.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _AppPalette.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_AppRadii.large),
            side: const BorderSide(color: _AppPalette.line),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _AppPalette.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          labelStyle: const TextStyle(
            color: _AppPalette.muted,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_AppRadii.medium),
            borderSide: const BorderSide(color: _AppPalette.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_AppRadii.medium),
            borderSide: const BorderSide(color: _AppPalette.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_AppRadii.medium),
            borderSide: const BorderSide(color: _AppPalette.teal, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _AppPalette.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_AppRadii.medium),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _AppPalette.ink,
            side: const BorderSide(color: _AppPalette.line),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_AppRadii.medium),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          backgroundColor: _AppPalette.surface,
          indicatorColor: _AppPalette.tealSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _AppPalette.teal
                  : _AppPalette.muted,
              size: states.contains(WidgetState.selected) ? 24 : 22,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
      home: const AuthGateScreen(),
    );
  }
}

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    await ApiConfig.load();
    await SessionStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  void _handleAuthenticated() {
    setState(() {});
  }

  Future<void> _logout() async {
    LecturerBroadcastService().stop();
    await AuthService().logout();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!SessionStore.isAuthenticated) {
      return AuthScreen(onAuthenticated: _handleAuthenticated);
    }

    if (SessionStore.role == 'lecturer') {
      return LecturerShell(onLogout: _logout);
    }
    return StudentShell(onLogout: _logout);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();

  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regMatricController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _role = 'student';
  String? _registrationFaceBase64;
  final bool _capturingRegistrationFace = false;

  bool _loading = false;

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regMatricController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await _auth.login(
        identifier: _loginIdentifierController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Login failed. Please check your details and try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_registerForm.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await _auth.register(
        fullName: _regNameController.text.trim(),
        matricNumber: _role == 'student' ? _regMatricController.text.trim() : null,
        username: _role == 'lecturer' ? _regUsernameController.text.trim() : null,
        role: _role,
        password: _regPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Registration failed. Please check the form and try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: _AppPalette.surface,
                borderRadius: BorderRadius.circular(_AppRadii.large),
                border: Border.all(color: _AppPalette.line),
              ),
              child: const TabBar(
                labelColor: _AppPalette.ink,
                unselectedLabelColor: _AppPalette.muted,
                labelStyle: TextStyle(fontWeight: FontWeight.w800),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: _AppPalette.tealSoft,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                tabs: [
                  Tab(text: 'Login'),
                  Tab(text: 'Register'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _AuthPane(
              title: 'Welcome Back',
              subtitle:
                  'Sign in to continue your attendance flow and access live session tools.',
              icon: Icons.verified_user_outlined,
              child: Form(
                key: _loginForm,
                child: Column(
                  children: [
                    _buildRequiredField(
                      _loginIdentifierController,
                      'Identifier (Matric or Username)',
                    ),
                    _buildRequiredField(
                      _loginPasswordController,
                      'Password',
                      obscure: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: Text(_loading ? 'Please wait...' : 'Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _AuthPane(
              title: 'Create Account',
              subtitle:
                  'Register as a student or lecturer to join the attendance system securely.',
              icon: Icons.app_registration_outlined,
              child: Form(
                key: _registerForm,
                child: Column(
                  children: [
                    _buildRequiredField(_regNameController, 'Full Name'),
                    if (_role == 'student')
                      _buildRequiredField(_regMatricController, 'Matric Number'),
                    if (_role == 'lecturer')
                      _buildRequiredField(_regUsernameController, 'Username'),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'lecturer', child: Text('Lecturer')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _role = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildRequiredField(
                      _regPasswordController,
                      'Password',
                      obscure: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        child: Text(_loading ? 'Please wait...' : 'Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SA Acoustic BLE')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select Role',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StudentShell(onLogout: () async {}),
                  ),
                );
              },
              icon: const Icon(Icons.person),
              label: const Text('Student'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LecturerShell(onLogout: () async {}),
                  ),
                );
              },
              icon: const Icon(Icons.school),
              label: const Text('Lecturer'),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    StudentScanPage(),
    StudentHistoryPage(),
    StudentProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Portal'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Capture a verified room signal, submit once, and track your attendance cleanly.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _AppPalette.muted,
                      height: 1.25,
                    ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LogoutButton(onPressed: () => widget.onLogout()),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering),
            label: 'Scan',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class LecturerShell extends StatefulWidget {
  const LecturerShell({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<LecturerShell> createState() => _LecturerShellState();
}

class _LecturerShellState extends State<LecturerShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    LecturerSessionPage(),
    // LecturerLivePage(), // handled conditionally
    LecturerReportsPage(),
    LecturerProfilePage(),
  ];

  void _loadSession(String sessionId) async {
    await SessionStore.setCurrentSessionId(sessionId);
    setState(() {
      _currentIndex = 0; // Switch to Start Session tab
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Portal'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create live sessions, broadcast proximity signals, and export attendance records.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _AppPalette.muted,
                      height: 1.25,
                    ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LogoutButton(onPressed: () => widget.onLogout()),
          ),
        ],
      ),
      body: _currentIndex == 1
          ? LecturerLivePage(onLoadSession: _loadSession)
          : _currentIndex == 0
              ? _pages[0]
              : _currentIndex == 2
                  ? _pages[1]
                  : _pages[2],
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            label: 'Session',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class StudentScanPage extends StatefulWidget {
  const StudentScanPage({super.key});

  @override
  State<StudentScanPage> createState() => _StudentScanPageState();
}

class _StudentScanPageState extends State<StudentScanPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = AttendanceApiService();
  final _acoustic = AcousticScanService();
  final _ble = BleScanService();
  final _transport = SignalTransportService();
  final _scanLogService = ScanTestLogService();
  final _acousticTokenController = TextEditingController();
  final _bleNonceController = TextEditingController();
  final _bleEvidenceController = TextEditingController();
  final _wifiProofController = TextEditingController();
  final _beaconProofController = TextEditingController();
  final _rssiController = TextEditingController(text: '-60');

  bool _submitting = false;
  bool _scanning = false;
  bool _clearingLogs = false;
  bool _scanEligibleForSubmit = false;
  String? _deviceId;
  String? _statusMessage;
  int? _decodedSessionId;
  int? _signalAgeSeconds;
  SessionModel? _scannedSession;
  AttendanceProofModel? _lastSubmittedProof;
  final Set<int> _submittedSessionIds = <int>{};
  List<String> _passedChecks = [];
  List<String> _failedChecks = [];
  List<ScanTestLogModel> _scanLogs = [];

  void _showFeedback(String message, {bool success = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initAutoFields();
  }

  @override
  void dispose() {
    _acousticTokenController.dispose();
    _bleNonceController.dispose();
    _bleEvidenceController.dispose();
    _wifiProofController.dispose();
    _beaconProofController.dispose();
    _rssiController.dispose();
    super.dispose();
  }

  Future<void> _initAutoFields() async {
    final id = await SessionStore.ensureDeviceId();
    final logs = await _scanLogService.loadLogs();
    final existingProofs = await _api.listProofs(
      studentId: SessionStore.currentIdentity().isEmpty
          ? null
          : SessionStore.currentIdentity(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = id;
      _scanLogs = logs;
      _submittedSessionIds
        ..clear()
        ..addAll(existingProofs.map((proof) => proof.sessionId));
    });
  }

  Future<void> _clearScanLogs() async {
    setState(() {
      _clearingLogs = true;
    });
    await _scanLogService.clearLogs();
    if (!mounted) {
      return;
    }
    setState(() {
      _scanLogs = [];
      _clearingLogs = false;
    });
  }

  Future<void> _submitProof() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final rssi = int.tryParse(_rssiController.text.trim());
    final sessionId = _decodedSessionId;
    if (sessionId == null || rssi == null) {
      _showFeedback('Run scan first to decode session and RSSI.');
      return;
    }
    if (!_scanEligibleForSubmit) {
      setState(() {
        _statusMessage =
            'No valid acoustic, BLE, beacon, or Wi-Fi/LAN attendance path is ready yet.';
      });
      _showFeedback('No valid attendance path is ready yet. Run a fresh scan.');
      return;
    }
    if (_submittedSessionIds.contains(sessionId)) {
      setState(() {
        _statusMessage =
            'Attendance has already been submitted for session $sessionId.';
      });
      _showFeedback('Attendance has already been submitted for this session.');
      return;
    }
    final hasSignalData = _acousticTokenController.text.trim().isNotEmpty ||
        _bleNonceController.text.trim().isNotEmpty ||
        _wifiProofController.text.trim().isNotEmpty ||
        _beaconProofController.text.trim().isNotEmpty;
    if (!hasSignalData) {
      setState(() {
        _statusMessage = 'No signal data from scan. Please scan again.';
      });
      _showFeedback('No signal data from the last scan. Please scan again.');
      return;
    }
    final studentId = SessionStore.currentIdentity();
    if (studentId.isEmpty) {
      setState(() {
        _statusMessage = 'No authenticated student identity found.';
      });
      _showFeedback('No authenticated student identity found.');
      return;
    }
    final deviceId = _deviceId ?? await SessionStore.ensureDeviceId();
    final observedAt = DateTime.now().toUtc();
    final signature = _buildSignature(
      sessionId: sessionId,
      studentId: studentId,
      deviceId: deviceId,
      acousticToken: _acousticTokenController.text.trim(),
      bleNonce: _bleNonceController.text.trim(),
      wifiProof: _wifiProofController.text.trim(),
      beaconProof: _beaconProofController.text.trim(),
      rssi: rssi,
      observedAt: observedAt,
    );

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final proof = AttendanceProofModel(
        sessionId: sessionId,
        studentId: studentId,
        deviceId: deviceId,
        acousticToken: _acousticTokenController.text.trim(),
        bleNonce: _bleNonceController.text.trim(),
        wifiProof: _wifiProofController.text.trim(),
        beaconProof: _beaconProofController.text.trim(),
        beaconRssi: _beaconProofController.text.trim().isEmpty ? null : rssi,
        rssi: rssi,
        observedAt: observedAt,
        signature: signature,
      );

      final created = await _api.submitProof(proof);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = [
          'Attendance proof submitted (id: ${created.id ?? '-'})',
          if ((created.deviceTrustDetail ?? '').isNotEmpty)
            created.deviceTrustDetail!,
        ].join('\n');
        _submittedSessionIds.add(sessionId);
        _scanEligibleForSubmit = false;
        _lastSubmittedProof = created;
      });
      if (created.deviceTrustStatus == 'bound_on_submit') {
        await SessionStore.setRegisteredDeviceId(deviceId);
      }
      _showFeedback('Attendance submitted successfully.', success: true);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submission Successful'),
          content: Text(
            'Your attendance proof for session $sessionId was submitted successfully.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Attendance could not be submitted. Please try again.',
      );
      setState(() {
        _statusMessage = message;
      });
      _showFeedback(message);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _buildSignature({
    required int sessionId,
    required String studentId,
    required String deviceId,
    required String acousticToken,
    required String bleNonce,
    required String wifiProof,
    required String beaconProof,
    required int rssi,
    required DateTime observedAt,
  }) {
    final payload = [
      sessionId,
      studentId,
      deviceId,
      acousticToken,
      bleNonce,
      wifiProof,
      beaconProof,
      rssi,
      observedAt.toIso8601String(),
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  String _buildTrustSummary({
    required ScanResultModel acoustic,
    required ScanResultModel ble,
    required bool acousticTrusted,
    required bool bleTrusted,
    required bool beaconTrusted,
    required bool sessionConsistent,
    required bool freshnessPassed,
  }) {
    if (beaconTrusted &&
        (acousticTrusted || bleTrusted) &&
        sessionConsistent &&
        freshnessPassed) {
      return 'Trusted multi-signal scan with room beacon';
    }
    if (acousticTrusted && bleTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted dual-signal scan';
    }
    if (acousticTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted acoustic-only scan';
    }
    if (bleTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted BLE-only scan';
    }
    if (beaconTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted BLE beacon room scan';
    }
    return 'Untrusted scan: no valid attendance path was confirmed';
  }

  bool _isTrustedAcousticSignal(
    ScanResultModel scan,
    dynamic acousticDecoded,
  ) {
    return acousticDecoded != null &&
        scan.acousticToken.trim().isNotEmpty &&
        (scan.source == 'microphone_decode' || scan.source == 'web_broadcast_cache');
  }

  bool _isTrustedBleSignal(
    ScanResultModel scan,
    dynamic bleDecoded,
  ) {
    return bleDecoded != null &&
        (scan.bleNonce?.trim().isNotEmpty ?? false) &&
        (scan.source == 'ble_scan_token' ||
            scan.source == 'ble_scan_manufacturer_data' ||
            scan.source == 'ble_scan_service_data' ||
            scan.source == 'ble_scan_lecturer_and_beacon' ||
            scan.source == 'web_broadcast_cache');
  }

  bool _isTrustedBeaconSignal(ScanResultModel scan) {
    return (scan.beaconProof?.trim().isNotEmpty ?? false) &&
        (scan.source == 'ble_scan_beacon_eddystone_uid' ||
            scan.source == 'ble_scan_beacon_ibeacon' ||
            scan.source == 'ble_scan_lecturer_and_beacon');
  }

  Future<SessionModel?> _resolveSessionForBeacon(ScanResultModel scan) async {
    final beaconProof = scan.beaconProof?.trim() ?? '';
    if (beaconProof.isEmpty) {
      return null;
    }
    return _api.resolveBeaconSession(
      beaconProof: beaconProof,
      beaconRssi: scan.rssi,
    );
  }

  String _bleEvidenceLabel({
    required bool lecturerBleTrusted,
    required bool beaconTrusted,
  }) {
    if (lecturerBleTrusted && beaconTrusted) {
      return 'Lecturer BLE + room beacon detected';
    }
    if (lecturerBleTrusted) {
      return 'Lecturer BLE detected';
    }
    if (beaconTrusted) {
      return 'BLE room beacon detected';
    }
    return '';
  }

  Future<bool> _ensureStudentScanPermissions() async {
    final readiness = await _transport.ensureStudentScanPermissions();
    if (readiness == null || readiness['ready'] == true) {
      return true;
    }
    final message = _readinessPromptMessage(
      readiness,
      fallback:
          'Allow microphone, location, and nearby-device permissions, then scan again.',
    );
    if (!mounted) {
      return false;
    }
    setState(() {
      _statusMessage = message;
      _failedChecks = [message];
      _passedChecks = [];
      _scanEligibleForSubmit = false;
    });
    _showFeedback(message);
    return false;
  }

  Future<void> _runSignalScan() async {
    final permissionsReady = await _ensureStudentScanPermissions();
    if (!permissionsReady) {
      return;
    }
    setState(() {
      _scanning = true;
      _statusMessage = null;
      _lastSubmittedProof = null;
    });
    try {
      final acoustic = await _acoustic.startAcousticScan();
      final ble = await _ble.scanForNonce();
      final acousticDecoded = SignalPayloadCodec.parseAcousticToken(
        acoustic.acousticToken,
      );
      final bleDecoded = SignalPayloadCodec.parseBleNonce(ble.bleNonce ?? '');
      final acousticTrusted = _isTrustedAcousticSignal(acoustic, acousticDecoded);
      final bleTrusted = _isTrustedBleSignal(ble, bleDecoded);
      final beaconTrusted = _isTrustedBeaconSignal(ble);
      var beaconAccepted = beaconTrusted;
      var beaconSessionConflict = false;
      final passed = <String>[];
      final failed = <String>[];

      if (acousticTrusted) {
        passed.add('Acoustic payload parsed');
        passed.add('Acoustic evidence came from a trusted broadcast path');
      } else if (!bleTrusted && !beaconTrusted) {
        failed.add(_friendlyAcousticResult(acoustic, false));
      } else {
        passed.add('Acoustic path was not used for this proof');
      }

      if (bleTrusted) {
        passed.add('BLE payload parsed');
        passed.add('BLE evidence came from a trusted advertisement path');
      } else if (!acousticTrusted && !beaconTrusted) {
        failed.add(_friendlyBleResult(ble, false));
      } else {
        passed.add('Lecturer BLE path was not used for this proof');
      }

      if (beaconTrusted) {
        passed.add('Registered beacon proof captured');
      } else if (!acousticTrusted && !bleTrusted) {
        failed.add(_friendlyBeaconResult(ble, false));
      }

      final sessionFromAc = acousticTrusted ? acousticDecoded?.sessionId : null;
      final sessionFromBle = bleTrusted ? bleDecoded?.sessionId : null;
      int? sessionFromBeacon;
      SessionModel? beaconSessionModel;
      if (beaconTrusted) {
        try {
          final beaconSession = await _resolveSessionForBeacon(ble);
          beaconSessionModel = beaconSession;
          sessionFromBeacon = beaconSession?.id;
          if (sessionFromBeacon != null) {
            passed.add('Beacon room resolved to an open attendance session');
            passed.add('Room proximity evidence accepted from BLE beacon');
          } else {
            beaconAccepted = false;
            failed.add('No open session could be resolved from the room beacon.');
          }
        } catch (error) {
          beaconAccepted = false;
          failed.add(
            friendlyErrorMessage(
              error,
              fallback: 'Could not match this beacon to an open room session.',
            ),
          );
        }
      }
      int? decodedSession;
      var sessionConsistent = false;
      if (sessionFromAc != null && sessionFromBle != null) {
        if (sessionFromAc == sessionFromBle) {
          decodedSession = sessionFromAc;
          sessionConsistent = true;
          passed.add('Session ID matches across acoustic + BLE');
        } else {
          failed.add('Session mismatch between acoustic and BLE');
        }
      } else {
        decodedSession = sessionFromAc ?? sessionFromBle ?? sessionFromBeacon;
        if (decodedSession != null) {
          sessionConsistent = true;
          if (decodedSession == sessionFromBeacon &&
              sessionFromAc == null &&
              sessionFromBle == null) {
            passed.add('Session resolved from the detected room beacon');
          } else {
            passed.add('Session ID decoded from one signal');
          }
        } else {
          failed.add('No session was decoded from the scan.');
        }
      }
      if (beaconAccepted &&
          sessionFromBeacon != null &&
          decodedSession != null &&
          sessionFromBeacon != decodedSession) {
        beaconAccepted = false;
        beaconSessionConflict = true;
        sessionConsistent = false;
        failed.add('Detected beacon belongs to a different open room session.');
      }

      final ages = <int>[];
      if (acousticTrusted && acousticDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(acousticDecoded.issuedAt));
      }
      if (bleTrusted && bleDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(bleDecoded.issuedAt));
      }
      final beaconOnlyFreshness = ages.isEmpty && beaconAccepted;
      final maxAge =
          ages.isEmpty ? (beaconAccepted ? 0 : null) : ages.reduce((a, b) => a > b ? a : b);
      final freshnessPassed =
          maxAge != null &&
          maxAge >= 0 &&
          maxAge <= SignalPayloadCodec.expirySeconds;
      if (freshnessPassed) {
        passed.add(
          beaconOnlyFreshness
              ? 'Beacon was observed during this scan'
              : 'Signal freshness within ${SignalPayloadCodec.expirySeconds}s',
        );
      } else {
        failed.add('The captured signal is too old. Please scan again.');
      }

      String? proofMode;
      if (acousticTrusted &&
          bleTrusted &&
          beaconAccepted &&
          sessionConsistent &&
          freshnessPassed) {
        proofMode = 'acoustic_ble_beacon';
        passed.add('Proof path ready: acoustic_ble_beacon');
      } else if (acousticTrusted && bleTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'dual_signal';
        passed.add('Proof path ready: dual_signal');
      } else if (bleTrusted && beaconAccepted && sessionConsistent && freshnessPassed) {
        proofMode = 'lecturer_ble_beacon';
        passed.add('Proof path ready: lecturer_ble_beacon');
      } else if (acousticTrusted && beaconAccepted && sessionConsistent && freshnessPassed) {
        proofMode = 'acoustic_beacon';
        passed.add('Proof path ready: acoustic_beacon');
      } else if (acousticTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'acoustic_only';
        passed.add('Proof path ready: acoustic_only');
      } else if (bleTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'ble_only';
        passed.add('Proof path ready: ble_only');
      } else if (beaconAccepted && sessionConsistent && freshnessPassed) {
        proofMode = 'ble_beacon';
        passed.add('Proof path ready: ble_beacon');
      } else {
        failed.add('No valid attendance signal is ready for submission.');
      }
      if (beaconSessionConflict) {
        proofMode = null;
      }

      if (decodedSession != null && _submittedSessionIds.contains(decodedSession)) {
        proofMode = null;
        failed.add('Attendance has already been submitted for this session');
      }

      SessionModel? scanSession = beaconSessionModel;
      if (decodedSession != null && scanSession?.id != decodedSession) {
        try {
          scanSession = await _api.getSession(decodedSession.toString());
        } catch (_) {
          scanSession = null;
        }
      }

      if (!mounted) {
        return;
      }
      final trustSummary = _buildTrustSummary(
        acoustic: acoustic,
        ble: ble,
        acousticTrusted: acousticTrusted,
        bleTrusted: bleTrusted,
        beaconTrusted: beaconAccepted,
        sessionConsistent: sessionConsistent,
        freshnessPassed: freshnessPassed,
      );
      final savedLogs = await _scanLogService.addLog(
        ScanTestLogModel(
          recordedAt: DateTime.now().toUtc(),
          trustSummary: trustSummary,
          acousticSource: acoustic.source ?? 'unknown',
          bleSource: ble.source ?? 'unknown',
          acousticDiagnostic: acoustic.diagnostic ?? '',
          bleDiagnostic: ble.diagnostic ?? '',
          decodedSessionId: decodedSession,
          signalAgeSeconds: maxAge,
          rssi: ble.rssi,
          passedChecks: passed,
          failedChecks: failed,
        ),
      );
      setState(() {
        _acousticTokenController.text = acoustic.acousticToken;
        _bleNonceController.text = ble.bleNonce ?? '';
        _bleEvidenceController.text = _bleEvidenceLabel(
          lecturerBleTrusted: bleTrusted,
          beaconTrusted: beaconAccepted,
        );
        _wifiProofController.clear();
        _beaconProofController.text = beaconAccepted ? (ble.beaconProof ?? '') : '';
        _rssiController.text = '${ble.rssi ?? -60}';
        _decodedSessionId = decodedSession;
        _scannedSession = scanSession;
        _signalAgeSeconds = maxAge;
        _passedChecks = passed;
        _failedChecks = failed;
        _scanEligibleForSubmit = proofMode != null;
        _scanLogs = savedLogs;
        _statusMessage = [
          trustSummary,
          if (proofMode != null) 'Proof path: $proofMode',
          'Acoustic: ${_friendlyAcousticResult(acoustic, acousticTrusted)}',
          'Lecturer BLE: ${_friendlyBleResult(ble, bleTrusted)}',
          'Beacon: ${_friendlyBeaconResult(ble, beaconAccepted)}',
        ].join('\n');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed.isEmpty
                ? 'Signal scan completed successfully.'
                : 'Signal scan completed with issues.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Signal scan could not be completed. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _failedChecks = [message];
        _passedChecks = [];
        _decodedSessionId = null;
        _scannedSession = null;
        _signalAgeSeconds = null;
        _scanEligibleForSubmit = false;
        _statusMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _runWifiVerification() async {
    setState(() {
      _scanning = true;
      _statusMessage = null;
      _lastSubmittedProof = null;
    });
    try {
      final sessions = await _api.listSessions();
      final activeSessions =
          sessions
              .where(
                (session) =>
                    session.active &&
                    session.attendanceOpen &&
                    session.id != null,
              )
              .toList();
      if (activeSessions.isEmpty) {
        throw Exception('No open attendance session is available for Wi-Fi/LAN verification.');
      }
      activeSessions.sort((a, b) => b.startsAt.compareTo(a.startsAt));
      final session = activeSessions.first;
      final sessionId = session.id!;
      if (_submittedSessionIds.contains(sessionId)) {
        throw Exception('Attendance has already been submitted for this session.');
      }
      final issuedAt = DateTime.now().toUtc();
      final epochSeconds = issuedAt.millisecondsSinceEpoch ~/ 1000;
      final wifiProof = 'wifi|$sessionId|$epochSeconds';
      final savedLogs = await _scanLogService.addLog(
        ScanTestLogModel(
          recordedAt: issuedAt,
          trustSummary: 'Trusted Wi-Fi/LAN verification',
          acousticSource: 'not_used',
          bleSource: 'not_used',
          acousticDiagnostic: '',
          bleDiagnostic: '',
          decodedSessionId: sessionId,
          signalAgeSeconds: 0,
          rssi: null,
          passedChecks: const [
            'Wi-Fi/LAN proof generated',
            'Session selected from active backend sessions',
            'Proof path ready: wifi_lan',
          ],
          failedChecks: const [],
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _acousticTokenController.clear();
        _bleNonceController.clear();
        _bleEvidenceController.clear();
        _wifiProofController.text = wifiProof;
        _beaconProofController.clear();
        _rssiController.text = '0';
        _decodedSessionId = sessionId;
        _scannedSession = session;
        _signalAgeSeconds = 0;
        _passedChecks = const [
          'Wi-Fi/LAN proof generated',
          'Session selected from active backend sessions',
          'Proof path ready: wifi_lan',
        ];
        _failedChecks = [];
        _scanEligibleForSubmit = true;
        _scanLogs = savedLogs;
        _statusMessage = [
          'Trusted Wi-Fi/LAN verification',
          'Proof path: wifi_lan',
          'Session: ${session.courseCode} - ${session.courseTitle}',
          'Room: ${session.room}',
        ].join('\n');
      });
      _showFeedback('Wi-Fi/LAN verification is ready. Submit proof now.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Wi-Fi/LAN verification could not be completed.',
      );
      setState(() {
        _failedChecks = [message];
        _passedChecks = [];
        _decodedSessionId = null;
        _scannedSession = null;
        _signalAgeSeconds = null;
        _scanEligibleForSubmit = false;
        _statusMessage = message;
      });
      _showFeedback(message);
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  bool get _hasSubmittedCurrentSession =>
      _decodedSessionId != null && _submittedSessionIds.contains(_decodedSessionId);

  String get _currentSignalMode => _proofScanModeLabel(
        acousticToken: _acousticTokenController.text,
        bleNonce: _bleNonceController.text,
        wifiProof: _wifiProofController.text,
        beaconProof: _beaconProofController.text,
      );

  _ChipTone get _attendanceTone {
    if (_lastSubmittedProof != null || _hasSubmittedCurrentSession) {
      return _ChipTone.success;
    }
    if (_scanEligibleForSubmit) {
      return _ChipTone.success;
    }
    if (_failedChecks.isNotEmpty) {
      return _ChipTone.danger;
    }
    return _ChipTone.neutral;
  }

  IconData get _attendanceIcon {
    if (_lastSubmittedProof != null || _hasSubmittedCurrentSession) {
      return Icons.verified_outlined;
    }
    if (_scanning) {
      return Icons.radar_outlined;
    }
    if (_failedChecks.isNotEmpty) {
      return Icons.troubleshoot_outlined;
    }
    if (_scanEligibleForSubmit) {
      return Icons.task_alt_outlined;
    }
    return Icons.sensors_outlined;
  }

  String get _attendanceTitle {
    if (_lastSubmittedProof != null || _hasSubmittedCurrentSession) {
      return 'Attendance submitted';
    }
    if (_scanning) {
      return 'Scanning the room';
    }
    if (_scanEligibleForSubmit) {
      return 'Signal verified';
    }
    if (_failedChecks.isNotEmpty) {
      return 'Scan needs attention';
    }
    return 'Ready to capture attendance';
  }

  String get _attendanceSubtitle {
    if (_lastSubmittedProof != null || _hasSubmittedCurrentSession) {
      return 'Your proof has been received for this session. No second submission is needed.';
    }
    if (_scanning) {
      return 'Keep your phone steady while the app checks acoustic, BLE, and room beacon signals.';
    }
    if (_scanEligibleForSubmit) {
      return 'The room signal is valid. Submit now to record your attendance.';
    }
    if (_failedChecks.isNotEmpty) {
      return 'Follow the guidance below, then scan again from inside the classroom.';
    }
    return 'Stand inside the classroom, keep Bluetooth and location on, then run one guided scan.';
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _lastSubmittedProof != null || _hasSubmittedCurrentSession;
    final canScan = !_scanning && !_submitting && !submitted;
    final canSubmit = _scanEligibleForSubmit && !_submitting && !submitted;
    final hasScanDetails = _passedChecks.isNotEmpty || _failedChecks.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StudentAttendanceHero(
              title: _attendanceTitle,
              subtitle: _attendanceSubtitle,
              icon: _attendanceIcon,
              tone: _attendanceTone,
              identity: SessionStore.currentIdentity().isEmpty
                  ? 'Student'
                  : SessionStore.currentIdentity(),
              device: SessionStore.displayDeviceId(_deviceId),
            ),
            const SizedBox(height: 14),
            _StudentScanActionCard(
              scanning: _scanning,
              submitting: _submitting,
              submitted: submitted,
              readyToSubmit: _scanEligibleForSubmit,
              onScan: canScan ? _runSignalScan : null,
              onWifi: (!_scanning && !_submitting && !submitted)
                  ? _runWifiVerification
                  : null,
              onSubmit: canSubmit ? _submitProof : null,
            ),
            const SizedBox(height: 16),
            _StudentSessionReceiptCard(
              session: _scannedSession,
              sessionId: _decodedSessionId,
              signalAgeSeconds: _signalAgeSeconds,
              signalMode: _currentSignalMode,
              submitted: submitted,
              readyToSubmit: _scanEligibleForSubmit,
              rssi: int.tryParse(_rssiController.text.trim()),
            ),
            if (hasScanDetails) ...[
              const SizedBox(height: 14),
              _StudentScanSummaryCard(
                tone: _attendanceTone,
                title: _attendanceTitle,
                passedChecks: _passedChecks,
                failedChecks: _failedChecks,
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              _GuidanceCard(
                icon: _scanEligibleForSubmit
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                title: _scanEligibleForSubmit
                    ? 'Ready for Submission'
                    : 'Scan Guidance',
                message: _statusMessage!,
                tone: _scanEligibleForSubmit
                    ? _ChipTone.success
                    : _failedChecks.isNotEmpty
                        ? _ChipTone.danger
                        : _ChipTone.neutral,
              ),
            ],
            const SizedBox(height: 12),
            _StudentTechnicalDetails(
              acousticTokenController: _acousticTokenController,
              bleEvidenceController: _bleEvidenceController,
              wifiProofController: _wifiProofController,
              beaconProofController: _beaconProofController,
              rssiController: _rssiController,
            ),
            const SizedBox(height: 12),
            _StudentLogsPanel(
              logs: _scanLogs,
              clearing: _clearingLogs,
              onClear: (_clearingLogs || _scanLogs.isEmpty)
                  ? null
                  : _clearScanLogs,
            ),
            const SizedBox(height: 10),
            _GuidanceCard(
              icon: Icons.lightbulb_outline,
              title: 'Best scan position',
              message:
                  'Stay inside the class, keep Bluetooth and Location enabled, and place the phone where it can receive the room beacon or lecturer broadcast clearly.',
              tone: _ChipTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceHero extends StatelessWidget {
  const _StudentAttendanceHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.identity,
    required this.device,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _ChipTone tone;
  final String identity;
  final String device;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      _ChipTone.success => _AppPalette.green,
      _ChipTone.danger => _AppPalette.amber,
      _ChipTone.neutral => _AppPalette.teal,
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppPalette.surface,
        border: Border.all(color: _AppPalette.line),
        borderRadius: BorderRadius.circular(_AppRadii.xlarge),
        boxShadow: [
          BoxShadow(
            color: _AppPalette.ink.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withOpacity(0.16)),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _AppPalette.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _AppPalette.muted,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassPill(icon: Icons.badge_outlined, label: identity, color: accent),
              _GlassPill(icon: Icons.phone_android_outlined, label: device, color: accent),
              _GlassPill(
                icon: Icons.verified_user_outlined,
                label: 'One submission only',
                color: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.icon,
    required this.label,
    this.color = _AppPalette.teal,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentScanActionCard extends StatelessWidget {
  const _StudentScanActionCard({
    required this.scanning,
    required this.submitting,
    required this.submitted,
    required this.readyToSubmit,
    required this.onScan,
    required this.onWifi,
    required this.onSubmit,
  });

  final bool scanning;
  final bool submitting;
  final bool submitted;
  final bool readyToSubmit;
  final VoidCallback? onScan;
  final VoidCallback? onWifi;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.radar_outlined, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Capture classroom signal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _StatusChip(
                  label: submitted
                      ? 'Submitted'
                      : readyToSubmit
                          ? 'Verified'
                          : 'Awaiting scan',
                  tone: submitted || readyToSubmit
                      ? _ChipTone.success
                      : _ChipTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sensors_outlined),
                label: Text(scanning ? 'Scanning room...' : 'Scan room signal'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWifi,
                    icon: const Icon(Icons.wifi_outlined),
                    label: const Text('Wi-Fi fallback'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.done_all_outlined),
                    label: Text(submitting ? 'Submitting...' : 'Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSessionReceiptCard extends StatelessWidget {
  const _StudentSessionReceiptCard({
    required this.session,
    required this.sessionId,
    required this.signalAgeSeconds,
    required this.signalMode,
    required this.submitted,
    required this.readyToSubmit,
    required this.rssi,
  });

  final SessionModel? session;
  final int? sessionId;
  final int? signalAgeSeconds;
  final String signalMode;
  final bool submitted;
  final bool readyToSubmit;
  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = submitted || readyToSubmit ? _ChipTone.success : _ChipTone.neutral;
    final title = session == null
        ? 'No session captured yet'
        : session!.courseTitle.trim().isEmpty
            ? session!.courseCode
            : '${session!.courseCode} - ${session!.courseTitle}';
    final signalAgeLabel =
        signalAgeSeconds == null ? '-' : '${signalAgeSeconds}s';
    final rssiLabel = rssi == null ? '-' : '$rssi';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (submitted || readyToSubmit
                            ? Colors.green
                            : colors.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    submitted || readyToSubmit
                        ? Icons.fact_check_outlined
                        : Icons.assignment_outlined,
                    color: submitted || readyToSubmit
                        ? Colors.green.shade700
                        : colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Session captured' : title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        submitted
                            ? 'Submission receipt is locked for this session.'
                            : readyToSubmit
                                ? 'Ready to submit your attendance proof.'
                                : 'Scan first to fill this attendance receipt.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: submitted
                      ? 'Submitted'
                      : readyToSubmit
                          ? 'Ready'
                          : 'Waiting',
                  tone: tone,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InlineInfoRows(
              items: [
                _ProfileDetailItem(
                  label: 'Session',
                  value: sessionId?.toString() ?? '-',
                ),
                _ProfileDetailItem(
                  label: 'Room',
                  value: session?.room.isNotEmpty == true ? session!.room : '-',
                ),
                _ProfileDetailItem(
                  label: 'Signal mode',
                  value: signalMode,
                ),
                _ProfileDetailItem(
                  label: 'Signal age / RSSI',
                  value: '$signalAgeLabel / $rssiLabel',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentScanSummaryCard extends StatelessWidget {
  const _StudentScanSummaryCard({
    required this.tone,
    required this.title,
    required this.passedChecks,
    required this.failedChecks,
  });

  final _ChipTone tone;
  final String title;
  final List<String> passedChecks;
  final List<String> failedChecks;

  @override
  Widget build(BuildContext context) {
    final isGood = tone == _ChipTone.success && failedChecks.isEmpty;
    final visibleChecks = failedChecks.isNotEmpty
        ? failedChecks.take(4).toList()
        : passedChecks.take(4).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGood ? Icons.check_circle_outline : Icons.info_outline,
                  color: isGood ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in visibleChecks)
                  _StatusChip(
                    label: item,
                    tone: failedChecks.isEmpty
                        ? _ChipTone.success
                        : _ChipTone.danger,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTechnicalDetails extends StatelessWidget {
  const _StudentTechnicalDetails({
    required this.acousticTokenController,
    required this.bleEvidenceController,
    required this.wifiProofController,
    required this.beaconProofController,
    required this.rssiController,
  });

  final TextEditingController acousticTokenController;
  final TextEditingController bleEvidenceController;
  final TextEditingController wifiProofController;
  final TextEditingController beaconProofController;
  final TextEditingController rssiController;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.tune_outlined),
        title: const Text('Technical proof details'),
        subtitle: const Text('Hidden by default for classroom use'),
        children: [
          _buildRequiredField(
            acousticTokenController,
            'Acoustic Token',
            readOnly: true,
            required: false,
          ),
          _buildRequiredField(
            bleEvidenceController,
            'BLE Evidence',
            readOnly: true,
            required: false,
          ),
          _buildRequiredField(
            wifiProofController,
            'Wi-Fi/LAN Proof',
            readOnly: true,
            required: false,
          ),
          _buildRequiredField(
            beaconProofController,
            'Beacon Proof',
            readOnly: true,
            required: false,
          ),
          _buildRequiredField(
            rssiController,
            'RSSI',
            numeric: true,
            readOnly: true,
          ),
        ],
      ),
    );
  }
}

class _StudentLogsPanel extends StatelessWidget {
  const _StudentLogsPanel({
    required this.logs,
    required this.clearing,
    required this.onClear,
  });

  final List<ScanTestLogModel> logs;
  final bool clearing;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.history_outlined),
        title: const Text('Recent scan history'),
        subtitle: Text(
          logs.isEmpty
              ? 'No local scan records yet'
              : '${logs.length} local scan record${logs.length == 1 ? '' : 's'}',
        ),
        trailing: TextButton(
          onPressed: onClear,
          child: Text(clearing ? 'Clearing...' : 'Clear'),
        ),
        children: [
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Run a scan to create a private local record for field testing.',
              ),
            )
          else
            for (final log in logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScanTestLogCard(log: log),
              ),
        ],
      ),
    );
  }
}

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({super.key});

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  final _api = AttendanceApiService();
  final _studentIdController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AttendanceProofModel> _proofs = [];

  @override
  void initState() {
    super.initState();
    _loadProofs();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProofs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final proofs = await _api.listProofs(
        studentId: _studentIdController.text.trim().isEmpty
            ? null
            : _studentIdController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _proofs = proofs;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = friendlyErrorMessage(
          error,
          fallback: 'Attendance history could not be loaded.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeroCard(
            title: 'Attendance History',
            subtitle:
                'Review your submitted attendance records clearly and verify what has already been captured.',
            icon: Icons.history_edu_outlined,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _studentIdController,
            decoration: const InputDecoration(
              labelText: 'Filter by Student ID (optional)',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadProofs,
            child: const Text('Load History'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(
                        message: _error!,
                        onRetry: _loadProofs,
                      )
                    : _proofs.isEmpty
                        ? const _EmptyState(
                            title: 'No attendance proofs found.',
                          )
                        : ListView.separated(
                            itemCount: _proofs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final proof = _proofs[index];
                              final displayName = proof.studentName?.isNotEmpty == true
                                  ? '${proof.studentName} (${proof.studentId})'
                                  : proof.studentId;
                              final mode = _proofScanModeLabel(
                                acousticToken: proof.acousticToken,
                                bleNonce: proof.bleNonce,
                                wifiProof: proof.wifiProof,
                                beaconProof: proof.beaconProof,
                              );
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              Icons.verified_outlined,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${proof.courseCode ?? 'Session'}${proof.courseTitle?.isNotEmpty == true ? " - ${proof.courseTitle}" : ""}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Submitted ${proof.observedAt.toLocal()}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey.shade700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _StatusChip(
                                            label: mode,
                                            tone: _proofScanModeTone(mode),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _InlineInfoRows(
                                        items: [
                                          _ProfileDetailItem(
                                            label: 'Student',
                                            value: displayName,
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Lecturer',
                                            value: proof.lecturerName ?? '-',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Room',
                                            value: proof.room ?? '-',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Session',
                                            value: '${proof.sessionId}',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'RSSI',
                                            value: '${proof.rssi}',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Device',
                                            value: SessionStore.displayDeviceId(
                                              proof.deviceId,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AccountProfilePage(
      title: 'Student Profile',
      roleLabel: 'Student',
    );
  }
}

class LecturerSessionPage extends StatefulWidget {
  const LecturerSessionPage({super.key});

  @override
  State<LecturerSessionPage> createState() => _LecturerSessionPageState();
}

class _LecturerSessionPageState extends State<LecturerSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = AttendanceApiService();
  final _broadcast = LecturerBroadcastService();
  final _transport = SignalTransportService();
  final _courseCodeController = TextEditingController();
  final _courseTitleController = TextEditingController();
  final _lecturerNameController = TextEditingController();
  final _roomController = TextEditingController();
  final _tokenVersionController = TextEditingController(text: 'v1');

  bool _submitting = false;
  bool _loadingRooms = false;
  List<String> _availableRooms = [];
  SessionModel? _lastSession;
  BroadcastSnapshot? _broadcastSnapshot;
  StreamSubscription<BroadcastSnapshot>? _broadcastSub;

  @override
  void initState() {
    super.initState();
    _attachBroadcastStream();
    _loadBeaconRooms();
    _loadCurrentSession();
  }

  void _attachBroadcastStream() {
    _broadcastSub?.cancel();
    _broadcastSnapshot = _broadcast.latest;
    _broadcastSub = _broadcast.stream.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _broadcastSnapshot = snapshot;
      });
    });
  }

  Future<void> _loadBeaconRooms() async {
    setState(() {
      _loadingRooms = true;
    });
    try {
      final rooms = await _api.listBeaconRooms();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableRooms = rooms;
        if (_roomController.text.trim().isEmpty && rooms.length == 1) {
          _roomController.text = rooms.first;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableRooms = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRooms = false;
        });
      }
    }
  }

  Future<void> _loadCurrentSession() async {
    final sessionId = SessionStore.currentSessionId;
    if (sessionId == null) {
      return;
    }
    try {
      final session = await _api.getSession(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSession = session;
        _courseCodeController.text = session.courseCode;
        _courseTitleController.text = session.courseTitle;
        _lecturerNameController.text = session.lecturerName;
        _roomController.text = session.room;
        _tokenVersionController.text = session.tokenVersion;
      });
    } catch (error) {
      // Ignore errors, session might be deleted
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final payload = SessionModel(
        courseCode: _courseCodeController.text.trim(),
        courseTitle: _courseTitleController.text.trim(),
        lecturerName: _lecturerNameController.text.trim(),
        room: _roomController.text.trim(),
        startsAt: DateTime.now(),
        tokenVersion: _tokenVersionController.text.trim(),
      );
      final created = await _api.createSession(payload);
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSession = created;
      });
      await SessionStore.setCurrentSessionId(created.id.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session created (id: ${created.id})')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Session could not be created. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _buildRoomSelector() {
    if (_availableRooms.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRequiredField(_roomController, 'Room'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loadingRooms
                        ? 'Loading registered beacon rooms...'
                        : 'No registered beacon rooms found yet. Type the room manually or add beacon rooms in Django admin.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _loadingRooms ? null : _loadBeaconRooms,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final currentRoom = _roomController.text.trim();
    final selectedRoom =
        _availableRooms.contains(currentRoom) ? currentRoom : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('${_availableRooms.join('|')}|$selectedRoom'),
        initialValue: selectedRoom,
        decoration: InputDecoration(
          labelText: 'Room',
          helperText: 'Rooms are loaded from active registered beacons.',
          border: const OutlineInputBorder(),
          suffixIcon: _loadingRooms
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Refresh rooms',
                  onPressed: _loadBeaconRooms,
                  icon: const Icon(Icons.refresh),
                ),
        ),
        hint: const Text('Select registered room'),
        items: _availableRooms
            .map(
              (room) => DropdownMenuItem<String>(
                value: room,
                child: Text(room),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _roomController.text = value;
          });
        },
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Room is required';
          }
          return null;
        },
      ),
    );
  }

  Future<bool> _ensureLecturerBroadcastPermissions() async {
    final readiness = await _transport.ensureLecturerBroadcastPermissions();
    if (readiness == null || readiness['ready'] == true) {
      return true;
    }
    final message = _readinessPromptMessage(
      readiness,
      fallback:
          'Allow Nearby Devices / Bluetooth permission, then start broadcast again.',
    );
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return false;
  }

  Future<void> _startBroadcast() async {
    final sessionId = _lastSession?.id;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a session before broadcasting.')),
      );
      return;
    }
    final permissionsReady = await _ensureLecturerBroadcastPermissions();
    if (!permissionsReady) {
      return;
    }
    try {
      final opened = await _api.openAttendance(sessionId.toString());
      if (!mounted) {
        return;
      }
      setState(() {
        _lastSession = opened;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Attendance could not be opened. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    _broadcast.start(
      sessionId: sessionId,
      tokenVersion: _tokenVersionController.text.trim(),
    );
    setState(() {
      _broadcastSnapshot = _broadcast.latest;
    });
  }

  Future<void> _stopBroadcast() async {
    final sessionId = _lastSession?.id;
    _broadcast.stop();
    if (sessionId != null) {
      try {
        final closed = await _api.closeAttendance(sessionId.toString());
        if (mounted) {
          setState(() {
            _lastSession = closed;
          });
        }
      } catch (_) {
        // The local broadcast still stops even if the backend is temporarily unreachable.
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopSession() async {
    final sessionId = _lastSession?.id;
    if (sessionId != null) {
      try {
        await _api.closeAttendance(sessionId.toString());
      } catch (_) {
        // The local session view can still be cleared if the network drops.
      }
    }
    await SessionStore.setCurrentSessionId(null);
    setState(() {
      _lastSession = null;
      _broadcastSnapshot = null;
      _courseCodeController.clear();
      _courseTitleController.clear();
      _lecturerNameController.clear();
      _roomController.clear();
      _tokenVersionController.text = 'v1';
    });
    _broadcast.stop();
  }

  @override
  void dispose() {
    _broadcastSub?.cancel();
    _courseCodeController.dispose();
    _courseTitleController.dispose();
    _lecturerNameController.dispose();
    _roomController.dispose();
    _tokenVersionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = _lastSession;
    final hasSession = activeSession != null;
    final attendanceOpen = activeSession?.attendanceOpen == true;
    final title = attendanceOpen
        ? 'Attendance is live'
        : hasSession
            ? 'Session ready'
            : 'Prepare class session';
    final subtitle = attendanceOpen
        ? 'Students can now scan acoustic, BLE, or room beacon proof for this class.'
        : hasSession
            ? 'Review the class details, then open attendance when the room is ready.'
            : 'Create a session, select the registered room, and control attendance from one place.';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LecturerCommandHero(
              title: title,
              subtitle: subtitle,
              isBroadcasting: _broadcast.isRunning,
              attendanceOpen: attendanceOpen,
            ),
            const SizedBox(height: 16),
            if (activeSession != null) ...[
              _LecturerActiveSessionCard(
                session: activeSession,
                broadcasting: _broadcast.isRunning,
                onOpenClose: _broadcast.isRunning ? _stopBroadcast : _startBroadcast,
                onStopSession: _stopSession,
              ),
              const SizedBox(height: 14),
            ],
            _LecturerCreateSessionPanel(
              submitting: _submitting,
              hasSession: hasSession,
              courseCodeController: _courseCodeController,
              courseTitleController: _courseTitleController,
              lecturerNameController: _lecturerNameController,
              tokenVersionController: _tokenVersionController,
              roomSelector: _buildRoomSelector(),
              onCreateSession: _submitting ? null : _createSession,
            ),
            if (_broadcastSnapshot != null) ...[
              const SizedBox(height: 14),
              _LecturerBroadcastPanel(snapshot: _broadcastSnapshot!),
            ],
            const SizedBox(height: 14),
            _GuidanceCard(
              icon: Icons.tips_and_updates_outlined,
              title: 'Classroom operation',
              message:
                  'Create the session before class starts, confirm the room, then open attendance only when students are physically present.',
              tone: _ChipTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _LecturerCommandHero extends StatelessWidget {
  const _LecturerCommandHero({
    required this.title,
    required this.subtitle,
    required this.isBroadcasting,
    required this.attendanceOpen,
  });

  final String title;
  final String subtitle;
  final bool isBroadcasting;
  final bool attendanceOpen;

  @override
  Widget build(BuildContext context) {
    final accent = attendanceOpen ? _AppPalette.green : _AppPalette.teal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppPalette.surface,
        border: Border.all(color: _AppPalette.line),
        borderRadius: BorderRadius.circular(_AppRadii.xlarge),
        boxShadow: [
          BoxShadow(
            color: _AppPalette.ink.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withOpacity(0.16)),
                ),
                child: Icon(
                  attendanceOpen
                      ? Icons.wifi_tethering_outlined
                      : Icons.dashboard_customize_outlined,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _AppPalette.ink,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _AppPalette.muted,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassPill(
                icon: Icons.sensors_outlined,
                label: isBroadcasting ? 'Broadcast running' : 'Broadcast idle',
                color: accent,
              ),
              _GlassPill(
                icon: Icons.lock_open_outlined,
                label: attendanceOpen ? 'Attendance open' : 'Attendance closed',
                color: accent,
              ),
              _GlassPill(
                icon: Icons.room_preferences_outlined,
                label: 'Room-aware beacon',
                color: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LecturerActiveSessionCard extends StatelessWidget {
  const _LecturerActiveSessionCard({
    required this.session,
    required this.broadcasting,
    required this.onOpenClose,
    required this.onStopSession,
  });

  final SessionModel session;
  final bool broadcasting;
  final VoidCallback onOpenClose;
  final VoidCallback onStopSession;

  @override
  Widget build(BuildContext context) {
    final attendanceOpen = session.attendanceOpen;
    final colors = Theme.of(context).colorScheme;
    final title = session.courseTitle.trim().isEmpty
        ? session.courseCode
        : '${session.courseCode} - ${session.courseTitle}';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: attendanceOpen
                        ? Colors.green.shade50
                        : colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    attendanceOpen
                        ? Icons.radio_button_checked
                        : Icons.event_available_outlined,
                    color: attendanceOpen ? Colors.green.shade700 : colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        attendanceOpen
                            ? 'Students can scan and submit attendance now.'
                            : 'Session created. Open attendance when ready.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: attendanceOpen ? 'Open' : 'Closed',
                  tone: attendanceOpen ? _ChipTone.success : _ChipTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InlineInfoRows(
              items: [
                _ProfileDetailItem(label: 'Session ID', value: '${session.id}'),
                _ProfileDetailItem(label: 'Lecturer', value: session.lecturerName),
                _ProfileDetailItem(label: 'Room', value: session.room),
                _ProfileDetailItem(
                  label: 'Started',
                  value: session.startsAt.toLocal().toString(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenClose,
                    icon: Icon(
                      broadcasting
                          ? Icons.wifi_tethering_off_outlined
                          : Icons.wifi_tethering_outlined,
                    ),
                    label: Text(
                      broadcasting ? 'Close Attendance' : 'Open Attendance',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onStopSession,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LecturerCreateSessionPanel extends StatelessWidget {
  const _LecturerCreateSessionPanel({
    required this.submitting,
    required this.hasSession,
    required this.courseCodeController,
    required this.courseTitleController,
    required this.lecturerNameController,
    required this.tokenVersionController,
    required this.roomSelector,
    required this.onCreateSession,
  });

  final bool submitting;
  final bool hasSession;
  final TextEditingController courseCodeController;
  final TextEditingController courseTitleController;
  final TextEditingController lecturerNameController;
  final TextEditingController tokenVersionController;
  final Widget roomSelector;
  final VoidCallback? onCreateSession;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ExpansionTile(
        initiallyExpanded: !hasSession,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.add_business_outlined),
        title: Text(hasSession ? 'Create another session' : 'Create session'),
        subtitle: Text(
          hasSession
              ? 'Open this only when you want to replace the current session.'
              : 'Enter course details and select the registered classroom.',
        ),
        children: [
          _buildRequiredField(courseCodeController, 'Course Code'),
          _buildRequiredField(courseTitleController, 'Course Title'),
          _buildRequiredField(lecturerNameController, 'Lecturer Name'),
          roomSelector,
          _buildRequiredField(tokenVersionController, 'Token Version'),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onCreateSession,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(submitting ? 'Creating...' : 'Create Session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LecturerBroadcastPanel extends StatelessWidget {
  const _LecturerBroadcastPanel({required this.snapshot});

  final BroadcastSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.monitor_heart_outlined),
        title: const Text('Broadcast diagnostics'),
        subtitle: const Text('Acoustic and BLE transmitter status'),
        children: [
          _BroadcastPayloadCard(snapshot: snapshot),
        ],
      ),
    );
  }
}

class LecturerLivePage extends StatefulWidget {
  const LecturerLivePage({super.key, required this.onLoadSession});

  final void Function(String sessionId) onLoadSession;

  @override
  State<LecturerLivePage> createState() => _LecturerLivePageState();
}

class _LecturerLivePageState extends State<LecturerLivePage> {
  final _api = AttendanceApiService();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<SessionModel> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SessionModel> get _filteredSessions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _sessions;
    }
    return _sessions.where((session) {
      final values = [
        session.id?.toString() ?? '',
        session.courseCode,
        session.courseTitle,
        session.lecturerName,
        session.room,
        session.attendanceOpen ? 'open attendance live' : 'closed ready',
        session.active ? 'active' : 'inactive',
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _api.listSessions();
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = friendlyErrorMessage(
          error,
          fallback: 'Live sessions could not be loaded.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteSession(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete ${session.courseCode} permanently? This will also remove its attendance proofs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _api.deleteSession(session.id.toString());
      if (!mounted) {
        return;
      }
      if (SessionStore.currentSessionId == session.id.toString()) {
        await SessionStore.setCurrentSessionId(null);
      }
      await _loadSessions();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session ${session.courseCode} deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Session could not be deleted. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _sessions.where((session) => session.attendanceOpen).length;
    final activeCount = _sessions.where((session) => session.active).length;
    final filteredSessions = _filteredSessions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LecturerLiveHero(
            totalSessions: _sessions.length,
            activeSessions: activeCount,
            openSessions: openCount,
          ),
          const SizedBox(height: 12),
          _CompactSearchField(
            controller: _searchController,
            hint: 'Search course, room, lecturer, session ID or status',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Session Register (${filteredSessions.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadSessions,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(
                        message: _error!,
                        onRetry: _loadSessions,
                      )
                    : _sessions.isEmpty
                        ? const _EmptyState(title: 'No sessions available.')
                        : filteredSessions.isEmpty
                            ? const _EmptyState(title: 'No matching sessions found.')
                        : ListView.separated(
                            itemCount: filteredSessions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final session = filteredSessions[index];
                              return _LecturerSessionListCard(
                                session: session,
                                selected:
                                    SessionStore.currentSessionId == session.id.toString(),
                                onLoad: () => widget.onLoadSession(
                                  session.id.toString(),
                                ),
                                onDelete: () => _deleteSession(session),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _LecturerLiveHero extends StatelessWidget {
  const _LecturerLiveHero({
    required this.totalSessions,
    required this.activeSessions,
    required this.openSessions,
  });

  final int totalSessions;
  final int activeSessions;
  final int openSessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.65),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.groups_2_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Sessions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalSessions total | $activeSessions active | $openSessions open',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _AppPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSearchField extends StatelessWidget {
  const _CompactSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: hint,
        filled: true,
        fillColor: _AppPalette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _AppPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _AppPalette.line),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _LecturerSessionListCard extends StatelessWidget {
  const _LecturerSessionListCard({
    required this.session,
    required this.selected,
    required this.onLoad,
    required this.onDelete,
  });

  final SessionModel session;
  final bool selected;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = session.courseTitle.trim().isEmpty
        ? session.courseCode
        : '${session.courseCode} - ${session.courseTitle}';
    final tone = session.attendanceOpen
        ? _ChipTone.success
        : session.active
            ? _ChipTone.neutral
            : _ChipTone.danger;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onLoad,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: session.attendanceOpen
                          ? Colors.green.shade50
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      session.attendanceOpen
                          ? Icons.wifi_tethering_outlined
                          : Icons.event_note_outlined,
                      color: session.attendanceOpen
                          ? Colors.green.shade700
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Room ${session.room} - ${session.startsAt.toLocal()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete session',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: session.attendanceOpen
                        ? 'Attendance Open'
                        : session.active
                            ? 'Session Ready'
                            : 'Inactive',
                    tone: tone,
                  ),
                  if (selected)
                    const _StatusChip(
                      label: 'Current',
                      tone: _ChipTone.success,
                    ),
                  _StatusChip(
                    label: 'Session ${session.id ?? '-'}',
                    tone: _ChipTone.neutral,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LecturerReportsPage extends StatefulWidget {
  const LecturerReportsPage({super.key});

  @override
  State<LecturerReportsPage> createState() => _LecturerReportsPageState();
}

class _LecturerReportsPageState extends State<LecturerReportsPage> {
  final _api = AttendanceApiService();
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<ValidationReportItemModel> _items = [];
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _currentSessionId = SessionStore.currentSessionId;
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ValidationReportItemModel> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _items;
    }
    return _items.where((row) {
      final values = [
        row.proofId.toString(),
        row.sessionId.toString(),
        row.studentId,
        row.studentName ?? '',
        row.courseCode ?? '',
        row.courseTitle ?? '',
        row.lecturerName ?? '',
        row.room ?? '',
        row.status,
        _detectReportMode(row),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentSessionId = SessionStore.currentSessionId;
    });
    try {
      if (_currentSessionId == null || _currentSessionId!.trim().isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _items = [];
        });
        return;
      }
      final report = await _api.getValidationReport(sessionId: _currentSessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = report;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = friendlyErrorMessage(
          error,
          fallback: 'Validation report could not be loaded.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _detectScanMode(AttendanceProofModel proof) {
    return _proofScanModeLabel(
      acousticToken: proof.acousticToken,
      bleNonce: proof.bleNonce,
      wifiProof: proof.wifiProof,
      beaconProof: proof.beaconProof,
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _exportCurrentSessionCsv() async {
    final sessionIdText = _currentSessionId?.trim() ?? '';
    if (sessionIdText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or load a current session first.')),
      );
      return;
    }

    final sessionId = int.tryParse(sessionIdText);
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current session id is not valid for export.')),
      );
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final proofs = await _api.listProofs(sessionId: sessionId);
      if (proofs.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance rows found for this session.')),
        );
        return;
      }

      final buffer = StringBuffer()
        ..writeln('SN,Student Name,Matric Number,Device ID,Mode of Scan');
      for (var i = 0; i < proofs.length; i++) {
        final proof = proofs[i];
        final studentName = (proof.studentName ?? '').trim().isEmpty
            ? 'Unknown'
            : proof.studentName!.trim();
        buffer.writeln([
          '${i + 1}',
          _csvCell(studentName),
          _csvCell(proof.studentId),
          _csvCell(proof.deviceId),
          _csvCell(_detectScanMode(proof)),
        ].join(','));
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}attendance_report_session_${sessionId}_$timestamp.csv',
      );
      await file.writeAsString(buffer.toString());

      if (!mounted) {
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance report for session $sessionId',
        subject: 'Attendance Report Session $sessionId',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported for session $sessionId.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'CSV export could not be completed.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionLabel = (_currentSessionId == null || _currentSessionId!.trim().isEmpty)
        ? 'No session selected'
        : 'Session $_currentSessionId';
    final rooms = _items
        .map((item) => (item.room ?? '').trim())
        .where((room) => room.isNotEmpty)
        .toSet()
        .length;
    final modes = _items.map(_detectReportMode).toSet().length;
    final filteredItems = _filteredItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LecturerReportHero(
            sessionLabel: sessionLabel,
            totalRows: _items.length,
            roomCount: rooms,
            modeCount: modes,
          ),
          const SizedBox(height: 12),
          _CompactSearchField(
            controller: _searchController,
            hint: 'Search student, matric, course, room, mode or session',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _loadReport,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_loading || _exporting) ? null : _exportCurrentSessionCsv,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadReport)
                    : _items.isEmpty
                        ? _EmptyState(
                            title: _currentSessionId == null
                                ? 'Select a session before loading reports.'
                                : 'No attendance rows for this session yet.',
                          )
                        : filteredItems.isEmpty
                            ? const _EmptyState(title: 'No matching students found.')
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              final row = filteredItems[index];
                              return _LecturerReportRowCard(
                                index: index + 1,
                                row: row,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _detectReportMode(ValidationReportItemModel row) {
    final beacon = (row.beaconProof ?? '').trim().isNotEmpty;
    final wifi = (row.wifiClientIp ?? '').trim().isNotEmpty;
    final hasBle = (row.bleAgeSeconds != null) || beacon;
    final hasAcoustic = row.acousticAgeSeconds != null;
    return _proofScanModeLabel(
      acousticToken: hasAcoustic ? 'acoustic' : '',
      bleNonce: hasBle ? 'ble' : '',
      wifiProof: wifi ? 'wifi' : '',
      beaconProof: beacon ? 'beacon' : '',
    );
  }
}

class _LecturerReportHero extends StatelessWidget {
  const _LecturerReportHero({
    required this.sessionLabel,
    required this.totalRows,
    required this.roomCount,
    required this.modeCount,
  });

  final String sessionLabel;
  final int totalRows;
  final int roomCount;
  final int modeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppPalette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _AppPalette.tealSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.analytics_outlined, color: _AppPalette.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation Report',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sessionLabel | $totalRows students | $roomCount rooms | $modeCount modes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _AppPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LecturerReportRowCard extends StatelessWidget {
  const _LecturerReportRowCard({
    required this.index,
    required this.row,
  });

  final int index;
  final ValidationReportItemModel row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final courseLabel =
        '${row.courseCode ?? ''}${(row.courseTitle ?? '').isNotEmpty ? " - ${row.courseTitle}" : ""}'
            .trim();
    final studentName = (row.studentName ?? '').trim().isEmpty
        ? 'Unknown Student'
        : row.studentName!.trim();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$index',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        children: [
          _InlineInfoRows(
            items: [
              _ProfileDetailItem(label: 'Matric Number', value: row.studentId),
              _ProfileDetailItem(
                label: 'Course',
                value: courseLabel.isEmpty ? '-' : courseLabel,
              ),
              _ProfileDetailItem(label: 'Room', value: row.room ?? '-'),
            ],
          ),
        ],
      ),
    );
  }
}

class LecturerProfilePage extends StatelessWidget {
  const LecturerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AccountProfilePage(
      title: 'Lecturer Profile',
      roleLabel: 'Lecturer',
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout, size: 17),
      label: const Text('Logout'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
        side: BorderSide(color: colorScheme.outlineVariant),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AccountProfilePage extends StatefulWidget {
  const _AccountProfilePage({
    required this.title,
    required this.roleLabel,
  });

  final String title;
  final String roleLabel;

  @override
  State<_AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<_AccountProfilePage> {
  String? _deviceId;
  final _auth = AuthService();
  final _apiBaseUrlController = TextEditingController();
  bool _enrollingFace = false;
  String? _latestEnrolledFaceBase64;
  bool _savingApiUrl = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController.text = ApiConfig.currentBaseUrl;
    _loadDeviceId();
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final deviceId = await SessionStore.ensureDeviceId();
    try {
      final profile = await _auth.getCurrentProfile();
      await SessionStore.setRegisteredDeviceId(
        profile['registered_device_id']?.toString() ?? '',
      );
    } catch (_) {
      // Profile details remain useful even when the backend is temporarily offline.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = deviceId;
    });
  }

  Future<void> _enrollFaceFromProfile() async {
    setState(() {
      _enrollingFace = true;
    });
    try {
      final result = await _captureFaceImage(
        context,
        title: 'Complete Face Enrollment',
        subtitle:
            'This will capture your enrollment face automatically once the camera sees a centered, well-lit face.',
      );
      if (!mounted || result == null) {
        return;
      }
      await _auth.enrollFace(result.base64Image);
      if (!mounted) {
        return;
      }
      setState(() {
        _latestEnrolledFaceBase64 = result.base64Image;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face enrollment saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = friendlyErrorMessage(
        error,
        fallback: 'Face enrollment could not be saved.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enrollingFace = false;
        });
      }
    }
  }

  Future<void> _saveApiBaseUrl() async {
    final value = _apiBaseUrlController.text.trim();
    if (value.isEmpty ||
        (!value.startsWith('http://') && !value.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a backend URL starting with http:// or https://'),
        ),
      );
      return;
    }
    setState(() {
      _savingApiUrl = true;
    });
    await ApiConfig.setRuntimeBaseUrl(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _apiBaseUrlController.text = ApiConfig.currentBaseUrl;
      _savingApiUrl = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend URL saved: ${ApiConfig.currentBaseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = SessionStore.currentIdentity();
    final matric = SessionStore.matricNumber?.trim() ?? '';
    final username = SessionStore.username?.trim() ?? '';
    final fullName = SessionStore.fullName?.trim() ?? '';
    final accent = widget.roleLabel == 'Lecturer'
        ? _AppPalette.navy
        : _AppPalette.teal;
    final roleIcon = widget.roleLabel == 'Lecturer' ? Icons.school : Icons.badge;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _AppPalette.surface,
              border: Border.all(color: _AppPalette.line),
              borderRadius: BorderRadius.circular(_AppRadii.xlarge),
              boxShadow: [
                BoxShadow(
                  color: _AppPalette.ink.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withOpacity(0.1),
                  child: Icon(roleIcon, color: accent, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName.isEmpty ? widget.title : fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _AppPalette.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.roleLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _AppPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileChip(
                      label: identity.isEmpty ? 'No primary ID' : identity,
                      color: accent,
                    ),
                    _ProfileChip(
                      label: SessionStore.displayDeviceId(_deviceId),
                      color: accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Account Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _ProfileDetailCard(
            items: [
              _ProfileDetailItem(label: 'Full Name', value: fullName.isEmpty ? '(not available)' : fullName),
              _ProfileDetailItem(label: 'Primary ID', value: identity.isEmpty ? '(not available)' : identity),
              if (matric.isNotEmpty) _ProfileDetailItem(label: 'Matric Number', value: matric),
              if (username.isNotEmpty) _ProfileDetailItem(label: 'Username', value: username),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Device',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _ProfileDetailCard(
            items: [
              _ProfileDetailItem(
                label: 'Readable Device ID',
                value: SessionStore.displayDeviceId(_deviceId),
              ),
              _ProfileDetailItem(
                label: 'Registered Device',
                value: SessionStore.displayDeviceId(
                  SessionStore.registeredDeviceId,
                ),
              ),
              _ProfileDetailItem(
                label: 'Stored Device ID',
                value: _deviceId ?? 'Generating...',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Advanced Connection Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Only change this if you need to switch away from the hosted server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            children: [
              const SizedBox(height: 10),
              _BackendUrlCard(
                controller: _apiBaseUrlController,
                saving: _savingApiUrl,
                onSave: _saveApiBaseUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaceCaptureCard extends StatelessWidget {
  const _FaceCaptureCard({
    required this.title,
    required this.subtitle,
    required this.imageBase64,
    required this.busy,
    required this.actionLabel,
    required this.onCapture,
  });

  final String title;
  final String subtitle;
  final String? imageBase64;
  final bool busy;
  final String actionLabel;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBase64 != null && imageBase64!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 12),
            Center(
              child: _FacePreviewAvatar(
                imageBase64: imageBase64,
                radius: 42,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCapture,
                icon: Icon(hasImage ? Icons.cameraswitch : Icons.camera_alt),
                label: Text(busy ? 'Opening Camera...' : actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacePreviewTile extends StatelessWidget {
  const _FacePreviewTile({
    required this.label,
    required this.imageBase64,
  });

  final String label;
  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          _FacePreviewAvatar(
            imageBase64: imageBase64,
            radius: 34,
          ),
        ],
      ),
    );
  }
}

class _FacePreviewAvatar extends StatelessWidget {
  const _FacePreviewAvatar({
    required this.imageBase64,
    required this.radius,
  });

  final String? imageBase64;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cleaned = imageBase64?.trim() ?? '';
    if (cleaned.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.face_retouching_natural, size: radius * 0.9),
      );
    }

    Uint8List? bytes;
    try {
      bytes = base64Decode(cleaned);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.broken_image_outlined, size: radius * 0.9),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(bytes),
      backgroundColor: Colors.grey.shade200,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 34),
              const SizedBox(height: 10),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendUrlCard extends StatelessWidget {
  const _BackendUrlCard({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Backend URL',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Change this when your laptop IP changes. Example: http://10.73.208.158:8000',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: saving ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save URL'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPane extends StatelessWidget {
  const _AuthPane({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _AppPalette.surface,
            border: Border.all(color: _AppPalette.line),
            borderRadius: BorderRadius.circular(_AppRadii.xlarge),
            boxShadow: [
              BoxShadow(
                color: _AppPalette.ink.withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _AppPalette.tealSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: _AppPalette.teal),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _AppPalette.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _AppPalette.muted,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 14),
              const _HostedConnectionPill(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _HostedConnectionPill extends StatelessWidget {
  const _HostedConnectionPill();

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(ApiConfig.currentBaseUrl);
    final host = uri?.host.isNotEmpty == true ? uri!.host : 'Hosted backend';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _AppPalette.tealSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _AppPalette.teal.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _AppPalette.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              host,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppPalette.teal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeroCard extends StatelessWidget {
  const _ScreenHeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AppPalette.surface,
        border: Border.all(color: _AppPalette.line),
        borderRadius: BorderRadius.circular(_AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _AppPalette.tealSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _AppPalette.teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: _AppPalette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleBar extends StatelessWidget {
  const _SectionTitleBar({
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        final tileWidth = isWide
            ? (constraints.maxWidth - 30) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: _AppPalette.surface,
                      border: Border.all(color: _AppPalette.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _AppPalette.muted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({
    required this.label,
    this.color = _AppPalette.teal,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProfileDetailCard extends StatelessWidget {
  const _ProfileDetailCard({required this.items});

  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      items[i].label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _AppPalette.muted,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      items[i].value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _AppPalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailItem {
  const _ProfileDetailItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _InlineInfoRows extends StatelessWidget {
  const _InlineInfoRows({required this.items});

  final List<_ProfileDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  items[i].label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _AppPalette.muted,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  items[i].value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _AppPalette.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (i != items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _ChipTone.success => _AppPalette.greenSoft,
      _ChipTone.danger => _AppPalette.redSoft,
      _ChipTone.neutral => _AppPalette.surfaceAlt,
    };
    final foreground = switch (tone) {
      _ChipTone.success => _AppPalette.green,
      _ChipTone.danger => _AppPalette.red,
      _ChipTone.neutral => _AppPalette.muted,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _AppPalette.ink,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastPayloadCard extends StatelessWidget {
  const _BroadcastPayloadCard({required this.snapshot});

  final BroadcastSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final acoustic = snapshot.acousticPayload;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_outlined),
                const SizedBox(width: 8),
                Text(
                  'Live Broadcast',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label:
                      'Acoustic: ${_friendlyNativeStatus(snapshot.nativeStatus.acousticStatus)}',
                  tone: _ChipTone.success,
                ),
                _StatusChip(
                  label: 'BLE: ${_friendlyNativeStatus(snapshot.nativeStatus.bleStatus)}',
                  tone: _bleStatusTone(snapshot.nativeStatus.bleStatus),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InlineInfoRows(
              items: [
                _ProfileDetailItem(
                  label: 'Session',
                  value: '${acoustic.sessionId}',
                ),
                _ProfileDetailItem(
                  label: 'Token Version',
                  value: acoustic.tokenVersion,
                ),
                _ProfileDetailItem(
                  label: 'Started',
                  value: acoustic.issuedAt.toLocal().toString(),
                ),
                _ProfileDetailItem(
                  label: 'Refresh Window',
                  value: '60 seconds',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _ChipTone _bleStatusTone(String status) {
    if (status.contains('started') || status.contains('requested')) {
      return _ChipTone.success;
    }
    if (status.contains('pending')) {
      return _ChipTone.neutral;
    }
    return _ChipTone.danger;
  }

  String _friendlyNativeStatus(String status) {
    switch (status) {
      case 'native_broadcast_pending':
        return 'starting';
      case 'acoustic_broadcast_started':
        return 'started';
      case 'ble_advertising_start_requested':
        return 'start requested';
      case 'ble_advertising_started':
        return 'started';
      case 'ble_advertising_stopped':
        return 'stopped';
      case 'bluetooth_off':
      case 'ble_bluetooth_off':
        return 'Bluetooth is off';
      case 'ble_advertise_permission_missing':
        return 'advertise permission missing';
      case 'ble_connect_permission_missing':
        return 'connect permission missing';
      case 'ble_advertising_unsupported':
        return 'advertising unsupported on this phone';
      case 'ble_adapter_unavailable':
      case 'ble_advertiser_unavailable':
        return 'BLE advertiser unavailable';
      case 'native_plugin_unavailable':
        return 'native plugin unavailable';
      default:
        if (status.startsWith('ble_advertising_failed_code_')) {
          return 'failed (${status.replaceFirst('ble_advertising_failed_code_', 'code ')})';
        }
        return status.replaceAll('_', ' ');
    }
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.decodedSessionId,
    required this.signalAgeSeconds,
    required this.passedChecks,
    required this.failedChecks,
  });

  final int? decodedSessionId;
  final int? signalAgeSeconds;
  final List<String> passedChecks;
  final List<String> failedChecks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  failedChecks.isEmpty
                      ? Icons.verified_outlined
                      : Icons.report_problem_outlined,
                  color: failedChecks.isEmpty
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  failedChecks.isEmpty ? 'Signal Accepted' : 'Scan Needs Attention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: 'Session ${decodedSessionId ?? '-'}',
                  tone: _ChipTone.neutral,
                ),
                _StatusChip(
                  label: 'Age ${signalAgeSeconds ?? '-'}s',
                  tone: _ChipTone.neutral,
                ),
              ],
            ),
            if (failedChecks.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final item in failedChecks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _StatusChip(label: item, tone: _ChipTone.danger),
                ),
            ] else if (passedChecks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Scan checks completed successfully.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _buildRequiredField(
  TextEditingController controller,
  String label, {
  bool numeric = false,
  bool readOnly = false,
  bool obscure = false,
  bool required = true,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }
        return null;
      },
    ),
  );
}

class _ScanTestLogCard extends StatelessWidget {
  const _ScanTestLogCard({required this.log});

  final ScanTestLogModel log;

  @override
  Widget build(BuildContext context) {
    final statusColor = log.isSuccessful ? Colors.green.shade700 : Colors.red.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  log.isSuccessful
                      ? Icons.check_circle_outline
                      : Icons.troubleshoot_outlined,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.isSuccessful ? 'Reliable scan captured' : 'Signal not ready',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (log.trustSummary.isNotEmpty)
              Text(
                log.trustSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: 'Session ${log.decodedSessionId ?? '-'}',
                  tone: _ChipTone.neutral,
                ),
                _StatusChip(
                  label: 'Age ${log.signalAgeSeconds ?? '-'}s',
                  tone: _ChipTone.neutral,
                ),
                _StatusChip(
                  label: 'RSSI ${log.rssi ?? '-'}',
                  tone: _ChipTone.neutral,
                ),
                _StatusChip(
                  label: 'Acoustic ${_friendlyLogAcoustic(log)}',
                  tone: _friendlyLogAcoustic(log) == 'captured'
                      ? _ChipTone.success
                      : _ChipTone.neutral,
                ),
                _StatusChip(
                  label: 'BLE ${_friendlyLogBle(log)}',
                  tone: _friendlyLogBle(log) == 'captured'
                      ? _ChipTone.success
                      : _ChipTone.neutral,
                ),
                if (_isWifiLog(log))
                  const _StatusChip(
                    label: 'Wi-Fi/LAN ready',
                    tone: _ChipTone.success,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recorded ${log.recordedAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            if (log.failedChecks.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in log.failedChecks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _StatusChip(label: item, tone: _ChipTone.danger),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _friendlyLogAcoustic(ScanTestLogModel log) {
    if (log.acousticSource == 'microphone_decode' ||
        log.acousticSource == 'web_broadcast_cache') {
      return 'captured';
    }
    return 'not captured';
  }

  String _friendlyLogBle(ScanTestLogModel log) {
    if (log.bleSource == 'ble_scan_token' ||
        log.bleSource == 'ble_scan_manufacturer_data' ||
        log.bleSource == 'ble_scan_service_data' ||
        log.bleSource == 'web_broadcast_cache') {
      return 'captured';
    }
    if (log.bleSource == 'ble_scan_not_ready') {
      return 'permission needed';
    }
    if (log.bleSource == 'ble_adapter_not_ready') {
      return 'Bluetooth off';
    }
    return 'not captured';
  }

  bool _isWifiLog(ScanTestLogModel log) {
    final summary = log.trustSummary.toLowerCase();
    return summary.contains('wi-fi') || summary.contains('wifi');
  }
}

enum _ChipTone { neutral, success, danger }

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final background = switch (tone) {
      _ChipTone.neutral => _AppPalette.surfaceAlt,
      _ChipTone.success => _AppPalette.greenSoft,
      _ChipTone.danger => _AppPalette.redSoft,
    };
    final foreground = switch (tone) {
      _ChipTone.neutral => _AppPalette.muted,
      _ChipTone.success => _AppPalette.green,
      _ChipTone.danger => _AppPalette.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
