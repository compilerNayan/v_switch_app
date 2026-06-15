import 'package:amplify_flutter/amplify_flutter.dart' hide ApiException, NetworkException;

import '../api/api_exceptions.dart';

String formatAuthError(Object error) {
  if (error is AuthException) {
    return _friendlyAuthMessage(error.message);
  }
  if (error is ApiException) {
    return error.error.message;
  }
  if (error is NetworkException) {
    return error.message;
  }

  final text = error.toString();
  if (text.contains('CodeMismatchException')) {
    return 'Invalid verification code. Check the email and try again.';
  }
  if (text.contains('ExpiredCodeException')) {
    return 'Verification code expired. Tap Resend code and try again.';
  }
  if (text.contains('LimitExceededException')) {
    return 'Too many attempts. Wait a few minutes and try again.';
  }
  if (text.contains('NotAuthorizedException')) {
    return 'Sign-in failed. Check your password or contact support.';
  }
  if (text.contains('UserNotConfirmedException')) {
    return 'Email is not verified yet. Enter the latest verification code.';
  }
  if (text.contains('UserNotFoundException')) {
    return 'No account found for this email. Sign up again.';
  }
  if (text.contains('UsernameExistsException') ||
      text.contains('AliasExistsException')) {
    return 'An account with this email already exists. Try signing in.';
  }

  return text.startsWith('Exception: ')
      ? text.substring('Exception: '.length)
      : text;
}

String _friendlyAuthMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('incorrect username or password')) {
    return 'Incorrect email or password.';
  }
  if (lower.contains('invalid verification code')) {
    return 'Invalid verification code. Check the email and try again.';
  }
  if (lower.contains('expired')) {
    return 'Verification code expired. Tap Resend code and try again.';
  }
  return message;
}
