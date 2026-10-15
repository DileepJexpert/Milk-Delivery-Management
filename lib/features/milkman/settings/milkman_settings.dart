import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_store.dart';

/// Milkman-side persistent settings (UPI ID, future preferences). Stored in
/// the existing `settings` Hive box so nothing new is needed at the storage
/// layer.
class MilkmanSettings {
  const MilkmanSettings({this.upiId, this.upiPayeeName});

  final String? upiId;
  final String? upiPayeeName;

  bool get hasUpi => upiId != null && upiId!.trim().isNotEmpty;

  MilkmanSettings copyWith({String? upiId, String? upiPayeeName}) =>
      MilkmanSettings(
        upiId: upiId ?? this.upiId,
        upiPayeeName: upiPayeeName ?? this.upiPayeeName,
      );
}

class MilkmanSettingsController extends StateNotifier<MilkmanSettings> {
  MilkmanSettingsController() : super(const MilkmanSettings()) {
    _load();
  }

  static const _kUpi = 'milkman_upi_id';
  static const _kPayee = 'milkman_upi_name';

  void _load() {
    final upi = LocalStore.instance.settings.get(_kUpi);
    final name = LocalStore.instance.settings.get(_kPayee);
    state = MilkmanSettings(
      upiId: upi is String ? upi : null,
      upiPayeeName: name is String ? name : null,
    );
  }

  Future<void> setUpi(String upiId, String payeeName) async {
    await LocalStore.instance.settings.put(_kUpi, upiId.trim());
    await LocalStore.instance.settings.put(_kPayee, payeeName.trim());
    state = MilkmanSettings(
      upiId: upiId.trim(),
      upiPayeeName: payeeName.trim(),
    );
  }

  Future<void> clearUpi() async {
    await LocalStore.instance.settings.delete(_kUpi);
    await LocalStore.instance.settings.delete(_kPayee);
    state = const MilkmanSettings();
  }
}

final milkmanSettingsProvider =
    StateNotifierProvider<MilkmanSettingsController, MilkmanSettings>(
        (ref) => MilkmanSettingsController());
