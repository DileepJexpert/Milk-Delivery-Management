import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/command_parser.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/flat.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

/// Combined text + voice command entry. The milkman types or speaks something
/// like "skip A-102" and the app fuzzy-matches the flat and applies the
/// intent. Falls back to "didn't understand" if the parser can't classify.
Future<void> showQuickCommand(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  final speech = stt.SpeechToText();
  bool listening = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInner) {
        Future<void> startListening() async {
          final ok = await speech.initialize(onStatus: (s) {
            if (s == 'done' || s == 'notListening') {
              setInner(() => listening = false);
            }
          });
          if (!ok) return;
          setInner(() => listening = true);
          await speech.listen(
            onResult: (r) {
              ctrl.text = r.recognizedWords;
            },
            listenFor: const Duration(seconds: 10),
          );
        }

        Future<void> stopListening() async {
          await speech.stop();
          setInner(() => listening = false);
        }

        return AlertDialog(
          title: Text(t.t('quick_command')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.t('quick_command_hint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: t.t('voice_command'),
                      icon: Icon(
                        listening ? Icons.mic : Icons.mic_none,
                        color: listening ? Colors.red : null,
                      ),
                      onPressed:
                          listening ? stopListening : startListening,
                    ),
                  ),
                ),
                if (listening) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(t.t('listening')),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  t.t('tip_voice_skip'),
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await _apply(ctx, ref, ctrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(t.t('apply')),
            ),
          ],
        );
      },
    ),
  );
  await speech.cancel();
}

Future<void> _apply(BuildContext ctx, WidgetRef ref, String input) async {
  final t = AppLocalizations.of(ctx);
  final parsed = CommandParser.parse(input);
  if (parsed == null) {
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text(t.t('unknown_command'))));
    return;
  }

  final flats = ref.read(flatsForCurrentMilkmanProvider).valueOrNull ?? const [];
  final flat = _matchFlat(flats, parsed.target);
  if (flat == null) {
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text(t.t('unknown_command'))));
    return;
  }

  final actor = ref.read(sessionControllerProvider).user;
  if (actor == null) return;
  final date = AppDates.today().add(Duration(days: parsed.dateOffset));
  final deliveryRepo = ref.read(deliveryRepositoryProvider);

  switch (parsed.intent) {
    case CommandIntent.skip:
      final subs = deliveryRepo.subscriptionsForFlat(flat.id);
      for (final s in subs) {
        final row = deliveryRepo.ensureForSubscription(flat, s, when: date);
        await deliveryRepo.markPaused(row, actor,
            reason: 'quick command: ${parsed.raw}');
      }
      break;
    case CommandIntent.extraOrder:
      final subs = deliveryRepo.subscriptionsForFlat(flat.id);
      if (subs.isEmpty) return;
      final defaultSub = subs.first;
      await deliveryRepo.createOneTime(
        flat: flat,
        productId: defaultSub.productId,
        quantity: parsed.quantity ?? defaultSub.quantity,
        unitPrice: defaultSub.unitPrice,
        when: date,
        actor: actor,
      );
      break;
  }

  if (ctx.mounted) {
    ScaffoldMessenger.of(ctx)
        .showSnackBar(SnackBar(content: Text(t.t('command_applied'))));
  }
}

/// Fuzzy-matches the target against flat number + owner name (case-insensitive
/// substring match). Returns the first hit — good enough for a 100-customer
/// route where collisions are rare.
Flat? _matchFlat(List<Flat> flats, String target) {
  final t = target.toLowerCase().trim();
  if (t.isEmpty) return null;
  for (final f in flats) {
    if (f.flatNumber.toLowerCase() == t) return f;
  }
  for (final f in flats) {
    if (f.ownerName.toLowerCase().contains(t)) return f;
    if (f.flatNumber.toLowerCase().contains(t)) return f;
  }
  return null;
}
