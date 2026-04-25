import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/models/audit_log.dart';
import '../data/models/change_request.dart';
import '../data/models/daily_delivery.dart';
import '../data/models/flat.dart';
import '../data/models/society.dart';
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
