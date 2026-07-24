String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString().trim();
  final message = raw
      .replaceFirst('Exception: ', '')
      .replaceFirst('ApiException: ', '')
      .trim();
  final lower = message.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('connection timed out') ||
      lower.contains('software caused connection abort') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused')) {
    return 'Cannot connect to the attendance service. Check your internet connection and try again in a minute.';
  }

  if (lower.contains('timeout')) {
    return 'The request took too long. Check your connection and try again.';
  }

  if (lower.contains('invalid credentials')) {
    return 'The login details are incorrect.';
  }

  if (lower.contains('already submitted') ||
      lower.contains('attendance already submitted')) {
    return 'Attendance has already been submitted for this session.';
  }

  if (lower.contains('wi-fi') || lower.contains('wifi')) {
    return 'Wi-Fi attendance is no longer available. Use acoustic, lecturer Bluetooth, or the room beacon.';
  }

  if (lower.contains('already registered') ||
      lower.contains('already exists')) {
    return 'This account already exists. Try logging in instead.';
  }

  if (lower.contains('already linked to another student account')) {
    return 'This phone is already linked to another student account.';
  }

  if (lower.contains('already linked to another phone')) {
    return 'This account is already linked to another phone.';
  }

  if (lower.contains('use the registered phone') ||
      lower.contains('request a device reset')) {
    return 'Use the registered phone for this account, or request a device reset.';
  }

  if (lower.contains('permission')) {
    return 'A required permission is missing. Allow the permission and try again.';
  }

  if (lower.contains('unexpected html response') ||
      lower.contains('server returned an unexpected page')) {
    return 'The attendance service returned an invalid response. Please try again shortly.';
  }

  if (lower.contains('request failed (500)') ||
      lower.contains('server error')) {
    return 'The attendance service could not complete the request. Please try again.';
  }

  if (lower.contains('request failed (401)') ||
      lower.contains('unauthorized')) {
    return 'Your session has expired. Please log in again.';
  }

  if (lower.contains('request failed (403)') || lower.contains('forbidden')) {
    return 'You do not have permission to perform this action.';
  }

  if (lower.contains('request failed (404)') || lower.contains('not found')) {
    return 'The requested record could not be found.';
  }

  if (message.isEmpty || message.length > 180 || message.contains(' at ')) {
    return fallback;
  }
  return message;
}
