import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'core/session_store.dart';
import 'models/attendance_proof_model.dart';
import 'models/session_model.dart';
import 'models/signal_payload_model.dart';
import 'models/validation_report_item_model.dart';
import 'services/attendance_api_service.dart';
import 'services/acoustic_scan_service.dart';
import 'services/ble_scan_service.dart';
import 'services/auth_service.dart';
import 'services/lecturer_broadcast_service.dart';
import 'services/signal_payload_codec.dart';

void main() {
  runApp(const SaAcousticBleApp());
}

class SaAcousticBleApp extends StatelessWidget {
  const SaAcousticBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SA Acoustic BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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

  final _loginIdentifierController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regMatricController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _role = 'student';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $error')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $error')),
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
          title: const Text('Sign In'),
          bottom: const TabBar(tabs: [Tab(text: 'Login'), Tab(text: 'Register')]),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: Text(_loading ? 'Please wait...' : 'Login'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _registerForm,
                child: ListView(
                  children: [
                    _buildRequiredField(_regNameController, 'Full Name'),
                    if (_role == 'student')
                      _buildRequiredField(_regMatricController, 'Matric Number'),
                    if (_role == 'lecturer')
                      _buildRequiredField(_regUsernameController, 'Username'),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
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
                    FilledButton(
                      onPressed: _loading ? null : _register,
                      child: Text(_loading ? 'Please wait...' : 'Register'),
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
        title: const Text('Student'),
        actions: [
          IconButton(
            onPressed: () => widget.onLogout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering),
            label: 'Scan Session',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
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
    LecturerLivePage(),
    LecturerReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer'),
        actions: [
          IconButton(
            onPressed: () => widget.onLogout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            label: 'Start Session',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Reports',
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
  final _acousticTokenController = TextEditingController();
  final _bleNonceController = TextEditingController();
  final _rssiController = TextEditingController(text: '-60');

  bool _submitting = false;
  bool _scanning = false;
  String? _deviceId;
  String? _statusMessage;
  int? _decodedSessionId;
  int? _signalAgeSeconds;
  List<String> _passedChecks = [];
  List<String> _failedChecks = [];

  @override
  void initState() {
    super.initState();
    _initAutoFields();
  }

  @override
  void dispose() {
    _acousticTokenController.dispose();
    _bleNonceController.dispose();
    _rssiController.dispose();
    super.dispose();
  }

  Future<void> _initAutoFields() async {
    final id = await SessionStore.ensureDeviceId();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = id;
    });
  }

  Future<void> _submitProof() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final rssi = int.tryParse(_rssiController.text.trim());
    final sessionId = _decodedSessionId;
    if (sessionId == null || rssi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run scan first to decode session and RSSI.')),
      );
      return;
    }
    if (_failedChecks.isNotEmpty) {
      setState(() {
        _statusMessage = 'Scan checks failed. Resolve scan issues before submit.';
      });
      return;
    }
    final studentId = SessionStore.currentIdentity();
    if (studentId.isEmpty) {
      setState(() {
        _statusMessage = 'No authenticated student identity found.';
      });
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
        rssi: rssi,
        observedAt: observedAt,
        signature: signature,
      );

      final created = await _api.submitProof(proof);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Attendance proof submitted (id: ${created.id ?? '-'})';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Submit failed: $error';
      });
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
    required int rssi,
    required DateTime observedAt,
  }) {
    final payload = [
      sessionId,
      studentId,
      deviceId,
      acousticToken,
      bleNonce,
      rssi,
      observedAt.toIso8601String(),
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<void> _runSignalScan() async {
    setState(() {
      _scanning = true;
    });
    try {
      final acoustic = await _acoustic.startAcousticScan();
      final ble = await _ble.scanForNonce();
      final acousticDecoded = SignalPayloadCodec.parseAcousticToken(
        acoustic.acousticToken,
      );
      final bleDecoded = SignalPayloadCodec.parseBleNonce(ble.bleNonce ?? '');
      final passed = <String>[];
      final failed = <String>[];

      if (acousticDecoded != null) {
        passed.add('Acoustic payload parsed');
      } else {
        failed.add('Acoustic payload parse failed');
      }
      if (bleDecoded != null) {
        passed.add('BLE payload parsed');
      } else {
        failed.add('BLE payload parse failed');
      }

      final sessionFromAc = acousticDecoded?.sessionId;
      final sessionFromBle = bleDecoded?.sessionId;
      int? decodedSession;
      if (sessionFromAc != null && sessionFromBle != null) {
        if (sessionFromAc == sessionFromBle) {
          decodedSession = sessionFromAc;
          passed.add('Session ID matches across acoustic + BLE');
        } else {
          failed.add('Session mismatch between acoustic and BLE');
        }
      } else {
        decodedSession = sessionFromAc ?? sessionFromBle;
        if (decodedSession != null) {
          passed.add('Session ID decoded from one signal');
        } else {
          failed.add('Session ID not decoded');
        }
      }

      final ages = <int>[];
      if (acousticDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(acousticDecoded.issuedAt));
      }
      if (bleDecoded != null) {
        ages.add(SignalPayloadCodec.signalAgeSeconds(bleDecoded.issuedAt));
      }
      final maxAge = ages.isEmpty ? null : ages.reduce((a, b) => a > b ? a : b);
      if (maxAge != null && maxAge >= 0 && maxAge <= SignalPayloadCodec.expirySeconds) {
        passed.add('Signal freshness within ${SignalPayloadCodec.expirySeconds}s');
      } else {
        failed.add('Signal freshness failed');
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _acousticTokenController.text = acoustic.acousticToken;
        _bleNonceController.text = ble.bleNonce ?? '';
        _rssiController.text = '${ble.rssi ?? -60}';
        _decodedSessionId = decodedSession;
        _signalAgeSeconds = maxAge;
        _passedChecks = passed;
        _failedChecks = failed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signal scan completed and decoded.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signal scan failed: $error')),
      );
      setState(() {
        _failedChecks = ['Signal scan execution failed'];
        _passedChecks = [];
        _decodedSessionId = null;
        _signalAgeSeconds = null;
      });
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
            Text(
              'Signal Scan Submit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Decoded Session ID',
              value: _decodedSessionId?.toString() ?? '(run scan to decode)',
            ),
            _InfoRow(
              label: 'Signal Age',
              value: _signalAgeSeconds == null ? '-' : '$_signalAgeSeconds s',
            ),
            _InfoRow(
              label: 'Student ID',
              value: SessionStore.currentIdentity().isEmpty
                  ? '(not available)'
                  : SessionStore.currentIdentity(),
            ),
            _InfoRow(
              label: 'Device ID',
              value: _deviceId ?? 'Generating...',
            ),
            _buildRequiredField(
              _acousticTokenController,
              'Acoustic Token',
              readOnly: true,
            ),
            _buildRequiredField(
              _bleNonceController,
              'BLE Nonce',
              readOnly: true,
            ),
            _buildRequiredField(
              _rssiController,
              'RSSI',
              numeric: true,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _scanning ? null : _runSignalScan,
              child: Text(_scanning ? 'Scanning...' : 'Run Signal Scan'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _submitting ? null : _submitProof,
              child: Text(_submitting ? 'Submitting...' : 'Submit Proof'),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_statusMessage!),
                ),
              ),
            ],
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
        _error = error.toString();
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
          Text('Attendance History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: _studentIdController,
            decoration: const InputDecoration(
              labelText: 'Filter by Student ID (optional)',
              border: OutlineInputBorder(),
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
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final proof = _proofs[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    'Student: ${proof.studentId} | Session: ${proof.sessionId}',
                                  ),
                                  subtitle: Text(
                                    'RSSI ${proof.rssi} at ${proof.observedAt.toLocal()}',
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
    return const _PlaceholderPage(
      title: 'Student Profile',
      subtitle: 'Student ID, device ID, and settings will be managed here.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session created (id: ${created.id})')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _startBroadcast() {
    final sessionId = _lastSession?.id;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a session before broadcasting.')),
      );
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start Session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildRequiredField(_courseCodeController, 'Course Code'),
            _buildRequiredField(_courseTitleController, 'Course Title'),
            _buildRequiredField(_lecturerNameController, 'Lecturer Name'),
            _buildRequiredField(_roomController, 'Room'),
            _buildRequiredField(_tokenVersionController, 'Token Version'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _createSession,
              child: Text(_submitting ? 'Creating...' : 'Create Session'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _broadcast.isRunning ? _stopBroadcast : _startBroadcast,
              child: Text(_broadcast.isRunning ? 'Stop Broadcast' : 'Start Broadcast'),
            ),
            if (_lastSession != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last session id: ${_lastSession!.id}'),
                      Text('Course: ${_lastSession!.courseCode}'),
                      Text('Room: ${_lastSession!.room}'),
                    ],
                  ),
                ),
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
  const LecturerLivePage({super.key});

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
        _error = error.toString();
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
          Text('Live Sessions', style: Theme.of(context).textTheme.titleLarge),
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
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    '${session.courseCode} - ${session.courseTitle}',
                                  ),
                                  subtitle: Text(
                                    'Room ${session.room} | ${session.startsAt.toLocal()}',
                                  ),
                                  trailing: session.active
                                      ? const Chip(label: Text('Active'))
                                      : const Chip(label: Text('Closed')),
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
  String? _error;
  List<ValidationReportItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _api.getValidationReport();
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
        _error = error.toString();
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
          Text('Validation Report', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loadReport,
            child: const Text('Refresh Report'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadReport)
                    : _items.isEmpty
                        ? const _EmptyState(title: 'No validation report rows yet.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final row = _items[index];
                              final isPass = row.status == 'pass';
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proof ${row.proofId} | Session ${row.sessionId} | Student ${row.studentId}',
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isPass ? 'Status: PASS' : 'Status: FAIL',
                                        style: TextStyle(
                                          color: isPass ? Colors.green.shade700 : Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Ages: Acoustic ${row.acousticAgeSeconds ?? '-'}s, BLE ${row.bleAgeSeconds ?? '-'}s',
                                      ),
                                      for (final p in row.passedChecks)
                                        Text('PASS: $p', style: TextStyle(color: Colors.green.shade700)),
                                      for (final f in row.failedChecks)
                                        Text('FAIL: $f', style: TextStyle(color: Colors.red.shade700)),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
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
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
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
    final ble = snapshot.blePayload;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Broadcast Payload (Mock)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Acoustic.session_id: ${acoustic.sessionId}'),
            Text('Acoustic.token_version: ${acoustic.tokenVersion}'),
            Text('Acoustic.challenge_token: ${acoustic.challengeToken}'),
            Text('Acoustic.issued_at: ${acoustic.issuedAt.toIso8601String()}'),
            Text('Acoustic.encoded: ${snapshot.acousticToken}'),
            const SizedBox(height: 8),
            Text('BLE.session_id: ${ble.sessionId}'),
            Text('BLE.ble_nonce: ${ble.bleNonce}'),
            Text('BLE.issued_at: ${ble.issuedAt.toIso8601String()}'),
            Text('BLE.encoded: ${snapshot.bleNonce}'),
            const SizedBox(height: 8),
            const Text('Expiry window: 60 seconds'),
          ],
        ),
      ),
    );
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
    final passColor = Colors.green.shade700;
    final failColor = Colors.red.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Decoded session: ${decodedSessionId ?? '-'}'),
            Text('Signal age: ${signalAgeSeconds ?? '-'}s'),
            const SizedBox(height: 8),
            for (final item in passedChecks)
              Text('PASS: $item', style: TextStyle(color: passColor)),
            for (final item in failedChecks)
              Text('FAIL: $item', style: TextStyle(color: failColor)),
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
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    ),
  );
}
