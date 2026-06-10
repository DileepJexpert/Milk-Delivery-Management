import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_utils.dart';
import '../data/local/local_store.dart';
import '../data/models/audit_log.dart';
import '../data/models/change_request.dart';
import '../data/models/daily_delivery.dart';
import '../data/models/flat.dart';
import '../data/models/milkman_absence.dart';
import '../data/models/category.dart';
import '../data/models/product.dart';
import '../data/models/society.dart';
import '../data/models/subscription.dart';
import '../data/models/user.dart';
import '../data/models/wallet_transaction.dart';
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

// NOTE: these providers deliberately fall back to `const []` when the
// parent provider is still loading. Returning `Stream.empty()` here would
// leave the StreamProvider permanently in `loading` state (an empty stream
// completes without emitting), and Riverpod would still call this builder
// again when the parent emits — but the screen would hang on a spinner in
// the meantime. Using an empty list keeps the provider in `data: []` state
// and lets ref.watch reactively rebuild with real data once it arrives.

final flatsForCurrentMilkmanProvider = StreamProvider<List<Flat>>((ref) {
  final societies =
      ref.watch(societiesForCurrentMilkmanProvider).valueOrNull ?? const [];
  final ids = societies.map((s) => s.id).toList();
  return ref.watch(flatRepositoryProvider).watchAllForMilkman(ids);
});

/// Today's planned + actual delivery rows across the whole route.
final todaysRouteProvider = StreamProvider<List<DailyDelivery>>((ref) {
  final flats =
      ref.watch(flatsForCurrentMilkmanProvider).valueOrNull ?? const [];
  final repo = ref.watch(deliveryRepositoryProvider);
  // Fire-and-forget: ensureForToday writes to the in-memory Hive cache
  // synchronously; the watch stream below will emit the rows immediately.
  repo.ensureRouteForToday(flats);
  return repo.watchForDate(
    AppDates.dateKey(AppDates.today()),
    flats.map((f) => f.id),
  );
});

final pendingChangeRequestsProvider = StreamProvider<List<ChangeRequest>>((ref) {
  final flats =
      ref.watch(flatsForCurrentMilkmanProvider).valueOrNull ?? const [];
  return ref
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

// ───────── Catalog / Subscriptions / Wallet ─────────

final categoriesProvider = StreamProvider<List<ProductCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

final activeProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchActive();
});

final subscriptionsForFlatProvider =
    StreamProvider.family<List<Subscription>, String>((ref, flatId) {
  return ref.watch(subscriptionRepositoryProvider).watchForFlat(flatId);
});

final walletTxnsForFlatProvider =
    StreamProvider.family<List<WalletTxn>, String>((ref, flatId) {
  return ref.watch(walletRepositoryProvider).watchForFlat(flatId);
});

/// Subscriber's own subscriptions (matched via myFlatProvider).
final mySubscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final flat = ref.watch(myFlatProvider);
  if (flat == null) return const Stream.empty();
  return ref.watch(subscriptionRepositoryProvider).watchForFlat(flat.id);
});

/// Subscriber's own wallet history.
final myWalletTxnsProvider = StreamProvider<List<WalletTxn>>((ref) {
  final flat = ref.watch(myFlatProvider);
  if (flat == null) return const Stream.empty();
  return ref.watch(walletRepositoryProvider).watchForFlat(flat.id);
});
