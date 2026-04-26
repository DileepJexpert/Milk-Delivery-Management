import 'package:hive_flutter/hive_flutter.dart';

/// Single entry point to all Hive boxes. Storing JSON-compatible Maps keeps the
/// app build-friendly (no codegen) and trivially serialisable to Firestore.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const _users = 'users';
  static const _societies = 'societies';
  static const _flats = 'flats';
  static const _deliveries = 'deliveries';
  static const _requests = 'change_requests';
  static const _audit = 'audit_logs';
  static const _settings = 'settings';
  static const _syncQueue = 'sync_queue';
  static const _absences = 'milkman_absences';

  late final Box users;
  late final Box societies;
  late final Box flats;
  late final Box deliveries;
  late final Box changeRequests;
  late final Box auditLogs;
  late final Box settings;
  late final Box syncQueue;
  late final Box absences;

  bool _opened = false;

  Future<void> open() async {
    if (_opened) return;
    users = await Hive.openBox(_users);
    societies = await Hive.openBox(_societies);
    flats = await Hive.openBox(_flats);
    deliveries = await Hive.openBox(_deliveries);
    changeRequests = await Hive.openBox(_requests);
    auditLogs = await Hive.openBox(_audit);
    settings = await Hive.openBox(_settings);
    syncQueue = await Hive.openBox(_syncQueue);
    absences = await Hive.openBox(_absences);
    _opened = true;
  }

  Future<void> wipe() async {
    await Future.wait([
      users.clear(),
      societies.clear(),
      flats.clear(),
      deliveries.clear(),
      changeRequests.clear(),
      auditLogs.clear(),
      syncQueue.clear(),
      absences.clear(),
    ]);
  }
}
