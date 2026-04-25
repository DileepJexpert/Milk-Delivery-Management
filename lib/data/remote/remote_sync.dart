import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../local/sync_queue.dart';

/// Abstract sink for queued mutations. Wire a Firestore implementation here
/// (see README "Backend wiring") to push the offline queue to the cloud.
abstract class RemoteSink {
  Future<void> apply(String op, String collection, Map<String, dynamic> data);
}

/// Default no-op sink: keeps changes local only. Replace with a Firestore-
/// backed implementation in production; this lets the app run end-to-end with
/// no Firebase configuration required for local development.
class NoopSink implements RemoteSink {
  const NoopSink();
  @override
  Future<void> apply(String op, String collection, Map<String, dynamic> data) async {}
}

class RemoteSync {
  RemoteSync({RemoteSink sink = const NoopSink()}) : _sink = sink;

  final RemoteSink _sink;
  StreamSubscription<dynamic>? _sub;

  void start() {
    _sub ??= Connectivity().onConnectivityChanged.listen((_) => drain());
    drain();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> drain() async {
    for (final entry in SyncQueue.instance.pending()) {
      try {
        await _sink.apply(
          entry['op'] as String,
          entry['collection'] as String,
          Map<String, dynamic>.from(entry['data'] as Map),
        );
        await SyncQueue.instance.ack(entry['id'] as String);
      } catch (_) {
        // leave in queue for next retry
      }
    }
  }
}
