import 'package:flutter/material.dart';

import 'models/attendance_proof_model.dart';
import 'models/session_model.dart';
import 'services/attendance_api_service.dart';

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
  final _sessionIdController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _acousticTokenController = TextEditingController();
  final _bleNonceController = TextEditingController();
  final _rssiController = TextEditingController(text: '-60');
  final _signatureController = TextEditingController();

  bool _submitting = false;

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
              'Mock Scan Submit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildRequiredField(_sessionIdController, 'Session ID', numeric: true),
            _buildRequiredField(_studentIdController, 'Student ID'),
            _buildRequiredField(_deviceIdController, 'Device ID'),
            _buildRequiredField(_acousticTokenController, 'Acoustic Token'),
            _buildRequiredField(_bleNonceController, 'BLE Nonce'),
            _buildRequiredField(_rssiController, 'RSSI', numeric: true),
            _buildRequiredField(_signatureController, 'Signature'),
            const SizedBox(height: 16),
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

class StudentHistoryPage extends StatelessWidget {
  const StudentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
      title: 'Attendance History',
      subtitle: 'Past attendance proofs and sync status will show here.',
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

class LecturerLivePage extends StatelessWidget {
  const LecturerLivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
      title: 'Live Attendance',
      subtitle: 'Live counts and recent check-ins will show here.',
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

Widget _buildRequiredField(
  TextEditingController controller,
  String label, {
  bool numeric = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
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
