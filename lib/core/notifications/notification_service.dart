/// Stub for Firebase Cloud Messaging push notifications.
///
/// To wire up real pushes:
///
///   1. Create a Firebase project at https://console.firebase.google.com
///   2. Download the `google-services.json` (Android) and
///      `GoogleService-Info.plist` (iOS) and drop them into
///      `android/app/` and `ios/Runner/` respectively.
///   3. In `pubspec.yaml`, uncomment the `firebase_core`,
///      `firebase_messaging`, and `flutter_local_notifications` deps.
///   4. In `main.dart`, call `await Firebase.initializeApp()` before
///      `runApp` and `await NotificationService.instance.init();`.
///   5. Replace the stub methods below with the SDK calls (the topic
///      structure is already designed — milkman subscribes to
///      `milkman_{id}`, subscriber subscribes to `flat_{id}`).
///
/// The stub keeps the rest of the codebase compile-clean today so each call
/// site can be wired up incrementally.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    // TODO(firebase): FirebaseMessaging.instance.requestPermission(...)
    // TODO(firebase): FirebaseMessaging.onMessage.listen(_onForeground)
  }

  /// Subscribe to per-flat events (bill ready, payment received, milkman
  /// absent tomorrow).
  Future<void> subscribeFlat(String flatId) async {
    // TODO(firebase): FirebaseMessaging.instance.subscribeToTopic('flat_$flatId');
  }

  /// Subscribe to per-milkman events (new change request, low balance alert
  /// from any flat).
  Future<void> subscribeMilkman(String milkmanId) async {
    // TODO(firebase): FirebaseMessaging.instance.subscribeToTopic('milkman_$milkmanId');
  }

  /// Triggered from the milkman side when a bill is finalised.
  Future<void> notifyBillReady({
    required String flatId,
    required double amount,
  }) async {
    // TODO(firebase): send via server endpoint or callable cloud function.
  }

  /// Triggered from the milkman side after recording a wallet top-up.
  Future<void> notifyPaymentReceived({
    required String flatId,
    required double amount,
  }) async {
    // TODO(firebase): server-side fanout.
  }
}
