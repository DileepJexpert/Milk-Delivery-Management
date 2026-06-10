import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/remote_sync.dart';
import '../data/repositories/absence_repository.dart';
import '../data/repositories/audit_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/change_request_repository.dart';
import '../data/repositories/delivery_repository.dart';
import '../data/repositories/flat_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/society_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/repositories/wallet_repository.dart';

final societyRepositoryProvider =
    Provider<SocietyRepository>((_) => SocietyRepository());

final auditRepositoryProvider =
    Provider<AuditRepository>((_) => AuditRepository());

final flatRepositoryProvider = Provider<FlatRepository>(
  (ref) => FlatRepository(ref.read(auditRepositoryProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.read(auditRepositoryProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.read(auditRepositoryProvider)),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.read(auditRepositoryProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(
    ref.read(flatRepositoryProvider),
    ref.read(auditRepositoryProvider),
  ),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(
    ref.read(flatRepositoryProvider),
    ref.read(auditRepositoryProvider),
    ref.read(subscriptionRepositoryProvider),
    ref.read(walletRepositoryProvider),
  ),
);

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>(
  (ref) => ChangeRequestRepository(
    ref.read(flatRepositoryProvider),
    ref.read(deliveryRepositoryProvider),
    ref.read(auditRepositoryProvider),
  ),
);

final absenceRepositoryProvider = Provider<AbsenceRepository>(
  (ref) => AbsenceRepository(
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
