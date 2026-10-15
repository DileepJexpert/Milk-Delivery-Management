import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_store.dart';
import '../../data/models/user.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/sync_service.dart';

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
        final user = AppUser.fromJson(raw);
        state = SessionState(user: user);
        // Sync fresh data in background
        SyncService.instance.syncDown(userId: user.id);
      }
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required String name,
    required UserRole role,
  }) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    AppUser user;
    try {
      // 1. Try real authentication with Cloudflare Worker D1 backend
      final res = await ApiClient.instance.login(
        phone: cleaned,
        otp: otp,
        name: name,
        role: role.name,
      );

      final userMap = res['user'] as Map<String, dynamic>;
      user = AppUser.fromJson(userMap);
    } catch (_) {
      // 2. Offline fallback: accept demo OTP 123456 with local Hive user
      if (otp.trim() != '123456') return false;

      AppUser? existing;
      for (final raw in LocalStore.instance.users.values.whereType<Map>()) {
        final u = AppUser.fromJson(raw);
        if (u.phone == cleaned) {
          existing = u;
          break;
        }
      }

      user = existing != null
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
    }

    // Persist locally
    await LocalStore.instance.users.put(user.id, user.toJson());
    await LocalStore.instance.settings.put(_activeUserKey, user.id);
    state = SessionState(user: user);

    // Hydrate data from cloud
    await SyncService.instance.syncDown(userId: user.id);
    return true;
  }

  Future<void> signOut() async {
    await LocalStore.instance.settings.delete(_activeUserKey);
    ApiClient.instance.token = null;
    state = const SessionState(user: null);
  }
}
