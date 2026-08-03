import 'package:my_shrine/data/state_notifiers.dart';

/// Returns the current user's email (used as the Firestore document ID).
///
/// Throws a [StateError] if no user is signed in or the user has no email.
String requireUserId() {
  final user = StateNotifiers.user.value;
  if (user == null || user.email == null) {
    throw StateError('No signed-in user or user has no email');
  }
  return user.email!;
}
