import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/session_store.dart';

void main() {
  test(
    'logout clears account data but preserves the installation device ID',
    () async {
      SharedPreferences.setMockInitialValues({});
      await SessionStore.load();
      final originalDeviceId = await SessionStore.ensureDeviceId();
      await SessionStore.save(
        tokenValue: 'token',
        roleValue: 'student',
        matricValue: '21/52HP071',
        usernameValue: '21/52HP071',
        fullNameValue: 'Test Student',
      );

      await SessionStore.clear();
      final deviceIdAfterLogout = await SessionStore.ensureDeviceId();

      expect(SessionStore.isAuthenticated, isFalse);
      expect(deviceIdAfterLogout, originalDeviceId);
    },
  );
}
