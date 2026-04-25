import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/local/local_store.dart';
import 'data/seed/seed_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStore.instance.open();
  await SeedData.ensureSeeded();
  runApp(const ProviderScope(child: MilkDeliveryApp()));
}
