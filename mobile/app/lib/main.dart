import 'package:flutter/material.dart';

import 'models/attendance_proof_model.dart';
import 'models/session_model.dart';
import 'services/attendance_api_service.dart';
import 'services/acoustic_scan_service.dart';
import 'services/ble_scan_service.dart';

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
      home: const RoleSelectionScreen(),
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
                    builder: (_) => const StudentShell(),
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
                    builder: (_) => const LecturerShell(),
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
  const StudentShell({super.key});

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
      appBar: AppBar(title: const Text('Student')),
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
  const LecturerShell({super.key});

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
      appBar: AppBar(title: const Text('Lecturer')),
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
  final _sessionIdController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _acousticTokenController = TextEditingController();
  final _bleNonceController = TextEditingController();
  final _rssiController = TextEditingController(text: '-60');
  final _signatureController = TextEditingController();

  bool _submitting = false;
  bool _scanning = false;

  @override
  void dispose() {
    _sessionIdController.dispose();
    _studentIdController.dispose();
    _deviceIdController.dispose();
    _acousticTokenController.dispose();
    _bleNonceController.dispose();
    _rssiController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _submitProof() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sessionId = int.tryParse(_sessionIdController.text.trim());
    final rssi = int.tryParse(_rssiController.text.trim());
    if (sessionId == null || rssi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ID and RSSI must be valid numbers.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final proof = AttendanceProofModel(
        sessionId: sessionId,
        studentId: _studentIdController.text.trim(),
        deviceId: _deviceIdController.text.trim(),
        acousticToken: _acousticTokenController.text.trim(),
        bleNonce: _bleNonceController.text.trim(),
        rssi: rssi,
        observedAt: DateTime.now(),
        signature: _signatureController.text.trim(),
      );

      final created = await _api.submitProof(proof);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance proof submitted (id: ${created.id ?? '-'})')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _runSignalScan() async {
    setState(() {
      _scanning = true;
    });
    try {
      final acoustic = await _acoustic.startAcousticScan();
      final ble = await _ble.scanForNonce();
      if (!mounted) {
        return;
      }
      setState(() {
        _acousticTokenController.text = acoustic.acousticToken;
        _bleNonceController.text = ble.bleNonce ?? '';
        _rssiController.text = '${ble.rssi ?? -60}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signal scan completed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signal scan failed: $error')),
      );
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
            _buildRequiredField(_sessionIdController, 'Session ID', numeric: true),
            _buildRequiredField(_studentIdController, 'Student ID'),
            _buildRequiredField(_deviceIdController, 'Device ID'),
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
            _buildRequiredField(_signatureController, 'Signature'),
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
  final _courseCodeController = TextEditingController();
  final _courseTitleController = TextEditingController();
  final _lecturerNameController = TextEditingController();
  final _roomController = TextEditingController();
  final _tokenVersionController = TextEditingController(text: 'v1');

  bool _submitting = false;
  SessionModel? _lastSession;

  @override
  void dispose() {
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

class LecturerReportsPage extends StatelessWidget {
  const LecturerReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
      title: 'Reports',
      subtitle: 'Session summaries and export actions will be here.',
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

Widget _buildRequiredField(
  TextEditingController controller,
  String label, {
  bool numeric = false,
  bool readOnly = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
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
