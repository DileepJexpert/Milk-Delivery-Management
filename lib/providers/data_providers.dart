import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/local/local_store.dart';
import '../data/models/audit_log.dart';
import '../data/models/change_request.dart';
import '../data/models/daily_delivery.dart';
import '../data/models/flat.dart';
import '../data/models/milkman_absence.dart';
import '../data/models/society.dart';
import '../data/models/user.dart';
import '../features/auth/session_controller.dart';
import 'repository_providers.dart';

final societiesForCurrentMilkmanProvider =
    StreamProvider<List<Society>>((ref) {
  final user = ref.watch(sessionControllerProvider).user;
  if (user == null) return const Stream.empty();
  return ref.watch(societyRepositoryProvider).watchForMilkman(user.id);
});

final flatsForSocietyProvider =
    StreamProvider.family<List<Flat>, String>((ref, societyId) {
  return ref.watch(flatRepositoryProvider).watchForSociety(societyId);
});

final flatsForCurrentMilkmanProvider = StreamProvider<List<Flat>>((ref) async* {
  final societies =
      await ref.watch(societiesForCurrentMilkmanProvider.future);
  final ids = societies.map((s) => s.id).toList();
  yield* ref.watch(flatRepositoryProvider).watchAllForMilkman(ids);
});

/// Today's planned + actual delivery rows across the whole route.
final todaysRouteProvider = StreamProvider<List<DailyDelivery>>((ref) async* {
  final flats = await ref.watch(flatsForCurrentMilkmanProvider.future);
  final repo = ref.watch(deliveryRepositoryProvider);
  await repo.ensureRouteForToday(flats);
  yield* repo.watchForDate(
    AppDates.dateKey(AppDates.today()),
    flats.map((f) => f.id),
  );
});

final pendingChangeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((ref) async* {
  final flats = await ref.watch(flatsForCurrentMilkmanProvider.future);
  yield* ref
      .watch(changeRequestRepositoryProvider)
      .watchAllForMilkman(flats.map((f) => f.id))
      .map((rows) =>
          rows.where((r) => r.status == ChangeRequestStatus.pending).toList());
});

final auditForFlatProvider =
    StreamProvider.family<List<AuditLog>, String>((ref, flatId) {
  return ref.watch(auditRepositoryProvider).watchForFlat(flatId);
});

final deliveriesForFlatProvider =
    StreamProvider.family<List<DailyDelivery>, String>((ref, flatId) {
  return ref.watch(deliveryRepositoryProvider).watchForFlat(flatId);
});

final changeRequestsForFlatProvider =
    StreamProvider.family<List<ChangeRequest>, String>((ref, flatId) {
  return ref.watch(changeRequestRepositoryProvider).watchForFlat(flatId);
});

/// Subscriber's linked flat (matched by phone number).
final myFlatProvider = Provider<Flat?>((ref) {
  final user = ref.watch(sessionControllerProvider).user;
  if (user == null) return null;
  return ref.watch(flatRepositoryProvider).byPhone(user.phone);
});

/// Absences for any milkman by id — used both by the milkman's own dashboard
/// and by subscribers checking if their milkman is off.
final absencesByMilkmanProvider =
    StreamProvider.family<List<MilkmanAbsence>, String>((ref, milkmanId) {
  return ref.watch(absenceRepositoryProvider).watchForMilkman(milkmanId);
});

final absencesForCurrentMilkmanProvider =
    StreamProvider<List<MilkmanAbsence>>((ref) {
  final user = ref.watch(sessionControllerProvider).user;
  if (user == null) return const Stream.empty();
  return ref.watch(absenceRepositoryProvider).watchForMilkman(user.id);
});

/// True if the currently signed-in milkman is off today.
final isMilkmanAbsentTodayProvider = Provider<bool>((ref) {
  // Subscribe to the absence box so this re-evaluates on writes.
  ref.watch(absencesForCurrentMilkmanProvider);
  final user = ref.watch(sessionControllerProvider).user;
  if (user == null) return false;
  return ref
      .watch(absenceRepositoryProvider)
      .isAbsentOn(AppDates.today(), user.id);
});

/// For a subscriber: who is the milkman that owns my flat's society?
final milkmanForSubscriberProvider = Provider<AppUser?>((ref) {
  final flat = ref.watch(myFlatProvider);
  if (flat == null) return null;
  final raw = LocalStore.instance.societies.get(flat.societyId);
  if (raw is! Map) return null;
  final society = Society.fromJson(raw);
  final userRaw = LocalStore.instance.users.get(society.milkmanId);
  if (userRaw is! Map) return null;
  return AppUser.fromJson(userRaw);
});

/// Is *the subscriber's* milkman off today?
final isMyMilkmanAbsentTodayProvider = Provider<bool>((ref) {
  final milkman = ref.watch(milkmanForSubscriberProvider);
  if (milkman == null) return false;
  // Subscribe to that specific milkman's absence stream so we rebuild on writes.
  ref.watch(absencesByMilkmanProvider(milkman.id));
  return ref
      .watch(absenceRepositoryProvider)
      .isAbsentOn(AppDates.today(), milkman.id);
});
