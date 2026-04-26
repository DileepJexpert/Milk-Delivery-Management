# Milk Delivery Management — Flutter App

Cross-platform Flutter app (Android-first, iOS-compatible) for milkmen to run
their daily routes and for subscribers (flat owners) to request pauses /
quantity changes. Offline-first with a Firebase-ready sync queue.

## Features at a glance

**Milkman**
- Manage societies and flats (owner, phone, default daily quantity, ₹/L).
- Today's route screen with one-tap "Delivered", swipe-style skip, and
  long-press to set a custom quantity at the door.
- Inbox of pending change requests from subscribers; one tap to apply, one tap
  to confirm via WhatsApp.
- **Absence / holiday mode** — single day, date range, or recurring weekly
  off. "I'm off today" big button on the home screen. App subscribers see
  "no delivery — milkman off" automatically; one-tap WhatsApp broadcast for
  non-app subscribers. Absent days never count toward the bill.
- Monthly billing per flat split into three categories — days delivered
  (billable), days subscriber paused (not billable), days milkman absent
  (not billable) — with PDF export and WhatsApp share.
- Per-flat detail page with full delivery history and an immutable audit log.

**Subscriber**
- OTP login auto-links to the flat the milkman registered under your phone
  number.
- Today's view shows scheduled quantity and current status.
- Big-button actions: Pause Today / Pause Tomorrow / Pause Range / Change
  Quantity. No nested menus.
- History and current month's running total.

**Across both**
- English + Hindi toggle (top-right `🌐`).
- Audit log records *who*, *what changed*, *when*, *why* for every quantity
  or status change.
- Hive-backed offline storage; mutations are queued and drained when
  connectivity returns.

## Tech stack

| Layer | Choice |
| --- | --- |
| UI | Flutter + Material 3 |
| State | `flutter_riverpod` |
| Local DB | `hive` / `hive_flutter` (JSON map storage — no codegen required) |
| Sync queue | Custom box drained on `connectivity_plus` events |
| Backend (suggested) | Firebase: Auth + Firestore + Cloud Messaging |
| PDF/Share | `pdf` + `printing` + `share_plus` |
| Deep links | `url_launcher` (WhatsApp `wa.me`) |
| Localisation | Hand-rolled (`lib/core/localization/app_localizations.dart`) — easy to swap for ARB/intl_utils |

## Project layout

```
lib/
  app.dart                       # MaterialApp, role-based home routing
  main.dart                      # Hive init + seed + ProviderScope
  core/
    theme/                       # Material 3 themes
    localization/                # en + hi strings, locale toggle
    utils/                       # date helpers, WhatsApp deep link
  data/
    models/                      # Plain Dart models with toJson/fromJson
    local/                       # LocalStore (Hive boxes) + SyncQueue
    remote/                      # RemoteSync skeleton (Noop sink by default)
    repositories/                # Society / Flat / Delivery / ChangeRequest / Audit
    seed/                        # First-run sample data
  features/
    auth/                        # Mock OTP login, session controller
    milkman/                     # Today's route, societies, inbox, billing
    subscriber/                  # Today, history, bill
  providers/                     # Riverpod wiring
```

## Run it

```bash
flutter pub get
flutter run                      # connect Android device or start an emulator
```

The app boots straight into the login screen — no Firebase keys required for
local development. A first-launch seed populates two societies, five flats,
and a week of historical deliveries so every screen has data immediately.

### Demo accounts

| Phone | Role | OTP |
| --- | --- | --- |
| `9000000001` | Milkman (Ramu) | `123456` |
| `9111111111` | Subscriber (Asha — Flat A-101) | `123456` |
| `9222222222` | Subscriber (Rajiv — Flat 12) | `123456` |

Any other phone number also works — sign in once, pick a role, and you'll get
a new account. Subscribers without a flat registered under their phone see a
prompt to ask their milkman to register them first.

### Build APK / IPA

```bash
flutter build apk --release      # Android
flutter build appbundle          # Play Store
flutter build ios --release      # iOS (run on macOS with Xcode installed)
```

## Backend wiring (Firebase)

The app ships with a `NoopSink` so it runs end-to-end offline. To turn on real
sync + push notifications:

1. **Create a Firebase project** at <https://console.firebase.google.com> and
   register Android (`com.example.milk_delivery`) and iOS bundle IDs.
2. Drop `google-services.json` into `android/app/` and
   `GoogleService-Info.plist` into `ios/Runner/` — both files are gitignored.
3. **Uncomment Firebase deps** in `pubspec.yaml` (`firebase_core`,
   `firebase_auth`, `cloud_firestore`, `firebase_messaging`) and re-run
   `flutter pub get`.
4. **Android Gradle:** uncomment the two `com.google.gms.google-services`
   lines in `android/settings.gradle` and `android/app/build.gradle`.
5. **Initialise Firebase in `main.dart`:**
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   await Firebase.initializeApp();
   ```
6. **Wire a real `RemoteSink`.** Replace `NoopSink` in
   `lib/data/remote/remote_sync.dart` with one that writes to Firestore:
   ```dart
   class FirestoreSink implements RemoteSink {
     final _db = FirebaseFirestore.instance;
     @override
     Future<void> apply(String op, String collection, Map<String, dynamic> data) {
       final id = data['id'] as String;
       return op == 'delete'
           ? _db.collection(collection).doc(id).delete()
           : _db.collection(collection).doc(id).set(data);
     }
   }
   ```
   Then construct `RemoteSync(sink: FirestoreSink())` in
   `repository_providers.dart`.
7. **Phone-OTP login.** Replace the mock `verifyOtp` in
   `lib/features/auth/session_controller.dart` with
   `FirebaseAuth.instance.verifyPhoneNumber` / `signInWithCredential`. The
   downstream session flow stays identical — keep persisting the resolved
   `AppUser` to the `users` Hive box so the rest of the app keeps working
   offline.
8. **Push notifications.** Initialise FCM:
   ```dart
   await FirebaseMessaging.instance.requestPermission();
   final token = await FirebaseMessaging.instance.getToken();
   ```
   Save the token on the user document and trigger a Cloud Function on every
   new `change_requests/*` write that sends a push to the milkman's token.

## Defaults / decisions worth knowing

- **No codegen.** Models are hand-rolled JSON ↔ Map; Hive stores plain maps.
  This keeps `flutter pub get && flutter run` enough to boot — no
  `build_runner` step.
- **Mock OTP `123456`.** Every phone is accepted offline so the app is
  demo-able without Firebase.
- **Subscriber → flat link is by phone.** The owner phone you enter when
  registering a flat is what the subscriber app matches against to find
  "their" flat.
- **Conflict resolution: last-write-wins by timestamp**, but every change is
  appended to the audit log so disputes can be reconstructed.
- **Currency** rendered as `₹`. Adjust in `bill_screen.dart`,
  `billing_screen.dart`, and `bill_pdf.dart` for other regions.

## Out of scope (v1, by design)

- Multiple milkmen per business
- Online payments
- Route optimisation / map navigation
