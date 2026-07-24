import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('authentication screen renders for a signed-out user', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SaAcousticBleApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsWidgets);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('student portal fits a typical phone viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_role': 'student',
      'auth_matric': '21/52HP071',
      'auth_username': '21/52HP071',
      'auth_full_name': 'Test Student',
      'device_id': 'dev_test_student',
    });

    await tester.pumpWidget(const SaAcousticBleApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Student Portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lecturer portal fits a typical phone viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_role': 'lecturer',
      'auth_matric': '',
      'auth_username': 'lecturer',
      'auth_full_name': 'Test Lecturer',
      'device_id': 'dev_test_lecturer',
    });

    await tester.pumpWidget(const SaAcousticBleApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Lecturer Portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
