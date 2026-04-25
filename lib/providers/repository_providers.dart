import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/remote_sync.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/change_request_repository.dart';
import '../data/repositories/delivery_repository.dart';
import '../data/repositories/flat_repository.dart';
import '../data/repositories/society_repository.dart';

final societyRepositoryProvider =
    Provider<SocietyRepository>((_) => SocietyRepository());

final flatRepositoryProvider =
    Provider<FlatRepository>((_) => FlatRepository());

final auditRepositoryProvider =
    Provider<AuditRepository>((_) => AuditRepository());

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(
    ref.read(flatRepositoryProvider),
    ref.read(auditRepositoryProvider),
  ),
);

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>(
  (ref) => ChangeRequestRepository(
    ref.read(flatRepositoryProvider),
    ref.read(deliveryRepositoryProvider),
    ref.read(auditRepositoryProvider),
  ),
);

final remoteSyncProvider = Provider<RemoteSync>((ref) {
  final sync = RemoteSync();
  sync.start();
  ref.onDispose(sync.dispose);
  return sync;
});
