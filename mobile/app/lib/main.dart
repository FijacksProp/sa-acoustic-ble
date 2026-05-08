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
    'web_no_ble' => 'Real BLE scanning is only available on Android.',
    _ => 'BLE signal was not captured.',
  };
}

String _proofScanModeLabel({
  required String acousticToken,
  required String bleNonce,
  String wifiProof = '',
}) {
  final hasAcoustic = acousticToken.trim().isNotEmpty;
  final hasBle = bleNonce.trim().isNotEmpty;
  final hasWifi = wifiProof.trim().isNotEmpty;
  final modes = <String>[
    if (hasAcoustic) 'Acoustic',
    if (hasBle) 'BLE',
    if (hasWifi) 'Wi-Fi',
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

_ChipTone _proofScanModeTone(String mode) {
  if (mode == 'Unknown') {
    return _ChipTone.neutral;
  }
  return _ChipTone.success;
}

class SaAcousticBleApp extends StatelessWidget {
  const SaAcousticBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5D7A),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'SA Acoustic BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant.withOpacity(0.7),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.55)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 60,
          backgroundColor: Colors.white,
          indicatorColor: colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
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
  final _apiBaseUrlController = TextEditingController();

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
  bool _savingApiUrl = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController.text = ApiConfig.currentBaseUrl;
  }

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regMatricController.dispose();
    _regPasswordController.dispose();
    _apiBaseUrlController.dispose();
    super.dispose();
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
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
                    _BackendUrlCard(
                      controller: _apiBaseUrlController,
                      saving: _savingApiUrl,
                      onSave: _saveApiBaseUrl,
                    ),
                    const SizedBox(height: 12),
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
                    _BackendUrlCard(
                      controller: _apiBaseUrlController,
                      saving: _savingApiUrl,
                      onSave: _saveApiBaseUrl,
                    ),
                    const SizedBox(height: 12),
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
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Capture a verified room signal, submit once, and track your attendance cleanly.',
                style: Theme.of(context).textTheme.bodyMedium,
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
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create live sessions, broadcast proximity signals, and export attendance records.',
                style: Theme.of(context).textTheme.bodyMedium,
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
  final _wifiProofController = TextEditingController();
  final _rssiController = TextEditingController(text: '-60');

  bool _submitting = false;
  bool _scanning = false;
  bool _clearingLogs = false;
  bool _scanEligibleForSubmit = false;
  String? _deviceId;
  String? _statusMessage;
  int? _decodedSessionId;
  int? _signalAgeSeconds;
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
    _wifiProofController.dispose();
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
            'No valid acoustic, BLE, or Wi-Fi/LAN attendance path is ready yet.';
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
        _wifiProofController.text.trim().isNotEmpty;
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
    required bool sessionConsistent,
    required bool freshnessPassed,
  }) {
    if (acousticTrusted && bleTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted dual-signal scan';
    }
    if (acousticTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted acoustic-only scan';
    }
    if (bleTrusted && sessionConsistent && freshnessPassed) {
      return 'Trusted BLE-only scan';
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
            scan.source == 'web_broadcast_cache');
  }

  Future<bool> _ensureStudentScanPermissions() async {
    final readiness = await _transport.ensureStudentScanPermissions();
    if (readiness == null || readiness['ready'] == true) {
      return true;
    }
    final message = _permissionPromptMessage(
      readiness['missing'],
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
      final passed = <String>[];
      final failed = <String>[];

      if (acousticTrusted) {
        passed.add('Acoustic payload parsed');
        passed.add('Acoustic evidence came from a trusted broadcast path');
      } else if (!bleTrusted) {
        failed.add(_friendlyAcousticResult(acoustic, false));
      } else {
        passed.add('Acoustic path was not used for this proof');
      }

      if (bleTrusted) {
        passed.add('BLE payload parsed');
        passed.add('BLE evidence came from a trusted advertisement path');
      } else if (!acousticTrusted) {
        failed.add(_friendlyBleResult(ble, false));
      } else {
        passed.add('BLE path was not used for this proof');
      }

      final sessionFromAc = acousticTrusted ? acousticDecoded?.sessionId : null;
      final sessionFromBle = bleTrusted ? bleDecoded?.sessionId : null;
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
        decodedSession = sessionFromAc ?? sessionFromBle;
        if (decodedSession != null) {
          sessionConsistent = true;
          passed.add('Session ID decoded from one signal');
        } else {
          failed.add('No session was decoded from the scan.');
        }
      }

      final ages = <int>[];
      if (acousticTrusted && acousticDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(acousticDecoded.issuedAt));
      }
      if (bleTrusted && bleDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(bleDecoded.issuedAt));
      }
      final maxAge = ages.isEmpty ? null : ages.reduce((a, b) => a > b ? a : b);
      final freshnessPassed =
          maxAge != null &&
          maxAge >= 0 &&
          maxAge <= SignalPayloadCodec.expirySeconds;
      if (freshnessPassed) {
        passed.add('Signal freshness within ${SignalPayloadCodec.expirySeconds}s');
      } else {
        failed.add('The captured signal is too old. Please scan again.');
      }

      String? proofMode;
      if (acousticTrusted && bleTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'dual_signal';
        passed.add('Proof path ready: dual_signal');
      } else if (acousticTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'acoustic_only';
        passed.add('Proof path ready: acoustic_only');
      } else if (bleTrusted && sessionConsistent && freshnessPassed) {
        proofMode = 'ble_only';
        passed.add('Proof path ready: ble_only');
      } else {
        failed.add('No valid attendance signal is ready for submission.');
      }

      if (decodedSession != null && _submittedSessionIds.contains(decodedSession)) {
        proofMode = null;
        failed.add('Attendance has already been submitted for this session');
      }

      if (!mounted) {
        return;
      }
      final trustSummary = _buildTrustSummary(
        acoustic: acoustic,
        ble: ble,
        acousticTrusted: acousticTrusted,
        bleTrusted: bleTrusted,
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
        _wifiProofController.clear();
        _rssiController.text = '${ble.rssi ?? -60}';
        _decodedSessionId = decodedSession;
        _signalAgeSeconds = maxAge;
        _passedChecks = passed;
        _failedChecks = failed;
        _scanEligibleForSubmit = proofMode != null;
        _scanLogs = savedLogs;
        _statusMessage = [
          trustSummary,
          if (proofMode != null) 'Proof path: $proofMode',
          'Acoustic: ${_friendlyAcousticResult(acoustic, acousticTrusted)}',
          'BLE: ${_friendlyBleResult(ble, bleTrusted)}',
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
    });
    try {
      final sessions = await _api.listSessions();
      final activeSessions =
          sessions.where((session) => session.active && session.id != null).toList();
      if (activeSessions.isEmpty) {
        throw Exception('No active session is available for Wi-Fi/LAN verification.');
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
        _wifiProofController.text = wifiProof;
        _rssiController.text = '0';
        _decodedSessionId = sessionId;
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScreenHeroCard(
              title: 'Signal Scan Submit',
              subtitle:
                  'Use one guided scan to capture the best available attendance signal, review the result, and submit confidently.',
              icon: Icons.radar_outlined,
            ),
            const SizedBox(height: 12),
            _MetricsStrip(
              items: [
                _MetricItem(
                  label: 'Session',
                  value: _decodedSessionId?.toString() ?? '--',
                ),
                _MetricItem(
                  label: 'Signal Age',
                  value: _signalAgeSeconds == null ? '--' : '${_signalAgeSeconds}s',
                ),
                _MetricItem(
                  label: 'Student',
                  value: SessionStore.currentIdentity().isEmpty
                      ? '--'
                      : SessionStore.currentIdentity(),
                ),
                _MetricItem(
                  label: 'Device',
                  value: SessionStore.displayDeviceId(_deviceId),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildRequiredField(
              _acousticTokenController,
              'Acoustic Token',
              readOnly: true,
              required: false,
            ),
            _buildRequiredField(
              _bleNonceController,
              'BLE Nonce',
              readOnly: true,
              required: false,
            ),
            _buildRequiredField(
              _wifiProofController,
              'Wi-Fi/LAN Proof',
              readOnly: true,
              required: false,
            ),
            _buildRequiredField(
              _rssiController,
              'RSSI',
              numeric: true,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: (_scanning ||
                          (_decodedSessionId != null &&
                              _submittedSessionIds.contains(_decodedSessionId)))
                      ? null
                      : _runSignalScan,
                  icon: const Icon(Icons.radar_outlined),
                  label: Text(_scanning ? 'Scanning...' : 'Scan Acoustic/BLE'),
                ),
                OutlinedButton.icon(
                  onPressed: (_scanning || _submitting) ? null : _runWifiVerification,
                  icon: const Icon(Icons.wifi_outlined),
                  label: const Text('Verify Wi-Fi/LAN'),
                ),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submitProof,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Proof'),
                ),
              ],
            ),
            if (_passedChecks.isNotEmpty || _failedChecks.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ScanResultCard(
                decodedSessionId: _decodedSessionId,
                signalAgeSeconds: _signalAgeSeconds,
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
            _SectionTitleBar(
              title: 'Recent Field-Test Logs',
              action: TextButton(
                onPressed: (_clearingLogs || _scanLogs.isEmpty)
                    ? null
                    : _clearScanLogs,
                child: Text(_clearingLogs ? 'Clearing...' : 'Clear Logs'),
              ),
            ),
            if (_scanLogs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No scan logs yet. Run phone tests to build a local history of outcomes.',
                  ),
                ),
              )
            else
              ..._scanLogs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ScanTestLogCard(log: log),
                ),
              ),
          ],
        ),
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
  SessionModel? _lastSession;
  BroadcastSnapshot? _broadcastSnapshot;
  StreamSubscription<BroadcastSnapshot>? _broadcastSub;

  @override
  void initState() {
    super.initState();
    _loadCurrentSession();
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
      });
      // Populate form fields
      _courseCodeController.text = session.courseCode;
      _courseTitleController.text = session.courseTitle;
      _lecturerNameController.text = session.lecturerName;
      _roomController.text = session.room;
      _tokenVersionController.text = session.tokenVersion;
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

  Future<bool> _ensureLecturerBroadcastPermissions() async {
    final readiness = await _transport.ensureLecturerBroadcastPermissions();
    if (readiness == null || readiness['ready'] == true) {
      return true;
    }
    final message = _permissionPromptMessage(
      readiness['missing'],
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
    _broadcast.start(
      sessionId: sessionId,
      tokenVersion: _tokenVersionController.text.trim(),
    );
    _broadcastSub?.cancel();
    _broadcastSub = _broadcast.stream.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _broadcastSnapshot = snapshot;
      });
    });
    setState(() {
      _broadcastSnapshot = _broadcast.latest;
    });
  }

  void _stopBroadcast() {
    _broadcast.stop();
    setState(() {});
  }

  Future<void> _stopSession() async {
    await SessionStore.setCurrentSessionId(null);
    setState(() {
      _lastSession = null;
      _broadcastSnapshot = null;
    });
    _broadcast.stop();
    // Clear form
    _courseCodeController.clear();
    _courseTitleController.clear();
    _lecturerNameController.clear();
    _roomController.clear();
    _tokenVersionController.text = 'v1';
  }

  @override
  void dispose() {
    _broadcast.dispose();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScreenHeroCard(
              title: 'Start Session',
              subtitle:
                  'Create a session, confirm the class details, and begin broadcasting attendance signals with less friction.',
              icon: Icons.play_circle_outline,
            ),
            const SizedBox(height: 12),
            _buildRequiredField(_courseCodeController, 'Course Code'),
            _buildRequiredField(_courseTitleController, 'Course Title'),
            _buildRequiredField(_lecturerNameController, 'Lecturer Name'),
            _buildRequiredField(_roomController, 'Room'),
            _buildRequiredField(_tokenVersionController, 'Token Version'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _submitting ? null : _createSession,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(_submitting ? 'Creating...' : 'Create Session'),
                ),
                if (_lastSession != null)
                  OutlinedButton.icon(
                    onPressed: _stopSession,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop Session'),
                  ),
                OutlinedButton.icon(
                  onPressed: _broadcast.isRunning ? _stopBroadcast : _startBroadcast,
                  icon: Icon(
                    _broadcast.isRunning
                        ? Icons.wifi_tethering_off_outlined
                        : Icons.wifi_tethering_outlined,
                  ),
                  label: Text(
                    _broadcast.isRunning ? 'Stop Broadcast' : 'Start Broadcast',
                  ),
                ),
              ],
            ),
            if (_lastSession != null) ...[
              const SizedBox(height: 16),
              _MetricsStrip(
                items: [
                  _MetricItem(label: 'Session ID', value: '${_lastSession!.id}'),
                  _MetricItem(label: 'Course', value: _lastSession!.courseCode),
                  _MetricItem(label: 'Room', value: _lastSession!.room),
                ],
              ),
            ],
            if (_broadcastSnapshot != null) ...[
              const SizedBox(height: 12),
              _BroadcastPayloadCard(snapshot: _broadcastSnapshot!),
            ],
          ],
        ),
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

  bool _loading = true;
  String? _error;
  List<SessionModel> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeroCard(
            title: 'Live Sessions',
            subtitle:
                'Switch between active sessions quickly, keep the right one in focus, and tidy up old entries easily.',
            icon: Icons.groups_2_outlined,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadSessions,
            child: const Text('Refresh Sessions'),
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
                        : ListView.separated(
                            itemCount: _sessions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => widget.onLoadSession(
                                    session.id.toString(),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: session.active
                                                ? Colors.green.shade50
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            session.active
                                                ? Icons.radio_button_checked
                                                : Icons.event_note_outlined,
                                            color: session.active
                                                ? Colors.green.shade700
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${session.courseCode} - ${session.courseTitle}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                  ),
                                                  if (session.active)
                                                    const _StatusChip(
                                                      label: 'Active',
                                                      tone: _ChipTone.success,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              _InlineInfoRows(
                                                items: [
                                                  _ProfileDetailItem(
                                                    label: 'Room',
                                                    value: session.room,
                                                  ),
                                                  _ProfileDetailItem(
                                                    label: 'Started',
                                                    value:
                                                        '${session.startsAt.toLocal()}',
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteSession(session),
                                          icon: const Icon(Icons.delete_outline),
                                          tooltip: 'Delete session',
                                        ),
                                      ],
                                    ),
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

class LecturerReportsPage extends StatefulWidget {
  const LecturerReportsPage({super.key});

  @override
  State<LecturerReportsPage> createState() => _LecturerReportsPageState();
}

class _LecturerReportsPageState extends State<LecturerReportsPage> {
  final _api = AttendanceApiService();
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScreenHeroCard(
            title: 'Validation Report',
            subtitle:
                'See the current session attendance at a glance and export a clean class list instantly.',
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 6),
          Text(
            _currentSessionId == null
                ? 'No current session selected. Showing none until a session is selected.'
                : 'Current session: $_currentSessionId',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _loadReport,
                  child: const Text('Refresh Report'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: (_loading || _exporting) ? null : _exportCurrentSessionCsv,
                  child: Text(_exporting ? 'Exporting...' : 'Export CSV'),
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
                        ? const _EmptyState(title: 'No validation report rows for the current session.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final row = _items[index];
                              final courseLabel =
                                  '${row.courseCode ?? ''}${(row.courseTitle ?? '').isNotEmpty ? " - ${row.courseTitle}" : ""}'
                                      .trim();
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              row.studentName ?? 'Unknown Student',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _InlineInfoRows(
                                        items: [
                                          _ProfileDetailItem(
                                            label: 'Matric Number',
                                            value: row.studentId,
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Course',
                                            value: courseLabel.isEmpty
                                                ? '-'
                                                : courseLabel,
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Lecturer',
                                            value: row.lecturerName ?? '-',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Room',
                                            value: row.room ?? '-',
                                          ),
                                          _ProfileDetailItem(
                                            label: 'Proof',
                                            value:
                                                '#${row.proofId} / Session ${row.sessionId}',
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
        ? Colors.indigo.shade700
        : Colors.green.shade700;
    final roleIcon = widget.roleLabel == 'Lecturer' ? Icons.school : Icons.badge;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(roleIcon, color: accent, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName.isEmpty ? widget.title : fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.roleLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileChip(
                      label: identity.isEmpty ? 'No primary ID' : identity,
                    ),
                    _ProfileChip(
                      label: SessionStore.displayDeviceId(_deviceId),
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
          Text(
            'Backend Connection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _BackendUrlCard(
            controller: _apiBaseUrlController,
            saving: _savingApiUrl,
            onSave: _saveApiBaseUrl,
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF073B4C),
                colorScheme.primary,
                const Color(0xFF118AB2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.95),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.65),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: colorScheme.primary),
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
                Text(subtitle),
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
                      color: Colors.white,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.65),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade700,
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
  const _ProfileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
        padding: const EdgeInsets.all(18),
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
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w700,
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
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  items[i].value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _ChipTone.success => Colors.green.shade50,
      _ChipTone.danger => Colors.red.shade50,
      _ChipTone.neutral => colorScheme.surfaceContainerHighest,
    };
    final foreground = switch (tone) {
      _ChipTone.success => Colors.green.shade700,
      _ChipTone.danger => Colors.red.shade700,
      _ChipTone.neutral => colorScheme.onSurfaceVariant,
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
                        color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _ChipTone.neutral => colorScheme.surfaceContainerHighest,
      _ChipTone.success => Colors.green.shade50,
      _ChipTone.danger => Colors.red.shade50,
    };
    final foreground = switch (tone) {
      _ChipTone.neutral => colorScheme.onSurfaceVariant,
      _ChipTone.success => Colors.green.shade700,
      _ChipTone.danger => Colors.red.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
