import '../local/local_store.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart';
import '../models/milkman_absence.dart';
import '../models/society.dart';
import '../models/change_request.dart';
import 'api_client.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Pulls the latest cloud data from Cloudflare D1 and hydrates local Hive boxes.
  Future<void> syncDown({String? dateKey, String? userId}) async {
    try {
      final res = await ApiClient.instance.syncData(dateKey: dateKey, userId: userId);
      if (res['success'] != true) return;

      final store = LocalStore.instance;

      if (res['societies'] is List) {
        for (final s in res['societies'] as List) {
          if (s is Map) {
            final soc = Society.fromJson(s);
            await store.societies.put(soc.id, soc.toJson());
          }
        }
      }

      if (res['flats'] is List) {
        for (final f in res['flats'] as List) {
          if (f is Map) {
            final flat = Flat.fromJson(f);
            await store.flats.put(flat.id, flat.toJson());
          }
        }
      }

      if (res['flat'] is Map) {
        final flat = Flat.fromJson(res['flat'] as Map);
        await store.flats.put(flat.id, flat.toJson());
      }

      if (res['society'] is Map) {
        final soc = Society.fromJson(res['society'] as Map);
        await store.societies.put(soc.id, soc.toJson());
      }

      if (res['deliveries'] is List) {
        for (final d in res['deliveries'] as List) {
          if (d is Map) {
            final deliv = DailyDelivery.fromJson(d);
            await store.deliveries.put(deliv.id, deliv.toJson());
          }
        }
      }

      if (res['change_requests'] is List) {
        for (final cr in res['change_requests'] as List) {
          if (cr is Map) {
            final req = ChangeRequest.fromJson(cr);
            await store.changeRequests.put(req.id, req.toJson());
          }
        }
      }

      if (res['absences'] is List) {
        for (final a in res['absences'] as List) {
          if (a is Map) {
            final abs = MilkmanAbsence.fromJson(a);
            await store.absences.put(abs.id, abs.toJson());
          }
        }
      }
    } catch (_) {
      // Offline resilience: keep using existing cached Hive data.
    }
  }
}
