import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_store.dart';
import '../../data/models/user.dart';

class SessionState {
  const SessionState({this.user});
  final AppUser? user;

  SessionState copyWith({AppUser? user, bool clear = false}) =>
      SessionState(user: clear ? null : (user ?? this.user));
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController();
});

/// Mock OTP-based auth.
///
/// Behaviour:
/// * Any phone is accepted.
/// * Valid OTP is `123456` for any number (matches the OTP placeholder in UI).
/// * If a user with that phone already exists locally (e.g. seeded), it is
///   re-used. Otherwise a new user is created — the role is whatever the
///   caller supplied during sign-up.
///
/// To swap in real Firebase Auth, replace [verifyOtp] with a call to
/// `FirebaseAuth.instance.signInWithCredential(...)` and persist the resulting
/// user the same way.
class SessionController extends StateNotifier<SessionState> {
  SessionController() : super(const SessionState()) {
    _restore();
  }

  static const _activeUserKey = 'active_user_id';
  static const _uuid = Uuid();

  void _restore() {
    final id = LocalStore.instance.settings.get(_activeUserKey);
    if (id is String) {
      final raw = LocalStore.instance.users.get(id);
      if (raw is Map) {
        state = SessionState(user: AppUser.fromJson(raw));
      }
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required String name,
    required UserRole role,
  }) async {
    if (otp.trim() != '123456') return false;
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    AppUser? existing;
    for (final raw in LocalStore.instance.users.values.whereType<Map>()) {
      final u = AppUser.fromJson(raw);
      if (u.phone == cleaned) {
        existing = u;
        break;
      }
    }

    final user = existing != null
        ? existing.copyWith(
            name: name.trim().isEmpty ? existing.name : name.trim(),
            role: role,
          )
        : AppUser(
            id: _uuid.v4(),
            phone: cleaned,
            name: name.trim().isEmpty ? 'User' : name.trim(),
            role: role,
          );
    await LocalStore.instance.users.put(user.id, user.toJson());
    await LocalStore.instance.settings.put(_activeUserKey, user.id);
    state = SessionState(user: user);
    return true;
  }

  Future<void> signOut() async {
    await LocalStore.instance.settings.delete(_activeUserKey);
    state = const SessionState(user: null);
  }
}
