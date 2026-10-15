import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../local/sync_queue.dart';
import 'api_client.dart';
import 'sync_service.dart';

/// Abstract sink for queued mutations.
abstract class RemoteSink {
  Future<void> apply(String op, String collection, Map<String, dynamic> data);
}

/// HTTP-backed remote sink pushing queued mutations to the Cloudflare Worker API.
class HttpRemoteSink implements RemoteSink {
  const HttpRemoteSink();

  @override
  Future<void> apply(String op, String collection, Map<String, dynamic> data) async {
    await ApiClient.instance.drainQueue([
      {
        'op': op,
        'collection': collection,
        'data': data,
      }
    ]);
  }
}

class RemoteSync {
  RemoteSync({RemoteSink sink = const HttpRemoteSink()}) : _sink = sink;

  final RemoteSink _sink;
  StreamSubscription<dynamic>? _sub;

  void start() {
    SyncQueue.onEnqueue = drain;
    _sub ??= Connectivity().onConnectivityChanged.listen((_) {
      drain();
      SyncService.instance.syncDown();
    });
    drain();
  }

  void dispose() {
    SyncQueue.onEnqueue = null;
    _sub?.cancel();
    _sub = null;
  }

  Future<void> drain() async {
    final pending = SyncQueue.instance.pending().toList();
    if (pending.isEmpty) return;

    // Send in bulk to save HTTP roundtrips
    try {
      final items = pending.map((entry) => {
        'op': entry['op'] as String,
        'collection': entry['collection'] as String,
        'data': Map<String, dynamic>.from(entry['data'] as Map),
      }).toList();

      final count = await ApiClient.instance.drainQueue(items);
      if (count > 0) {
        for (final entry in pending) {
          await SyncQueue.instance.ack(entry['id'] as String);
        }
      }
    } catch (_) {
      // Fallback: try individual entries or leave in queue for next retry
      for (final entry in pending) {
        try {
          await _sink.apply(
            entry['op'] as String,
            entry['collection'] as String,
            Map<String, dynamic>.from(entry['data'] as Map),
          );
          await SyncQueue.instance.ack(entry['id'] as String);
        } catch (_) {
          // Leave in queue for next retry
        }
      }
    }
  }
}
