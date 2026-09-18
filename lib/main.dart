import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'data/hive_service.dart';
import 'data/sync_service.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'state/providers.dart';

/// Background sync entry point — runs even when the app is closed (Android).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    await HiveService.init();
    await SyncService.backgroundSync();
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();
  SyncService.startWatching();
  unawaited(FcmService.init()); // no-op until Firebase config is dropped in

  // Periodic background sync (Android). iOS uses BGTaskScheduler via
  // workmanager — registered defensively.
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      AppConstants.syncTaskId,
      AppConstants.syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  } on Exception {
    // workmanager unavailable (e.g. iOS before plist config) — in-app sync
    // still works via connectivity listener.
  }

  runApp(const ProviderScope(child: DukaFlowApp()));
}

class DukaFlowApp extends ConsumerWidget {
  const DukaFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'DukaFlow',
      debugShowCheckedModeBanner: false,
      theme: DukaTheme.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: session.user == null
            ? const SplashScreen(key: ValueKey('splash'))
            : const HomeShell(key: ValueKey('home')),
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/pos': (_) => const HomeShell(initialTab: 1),
      },
    );
  }
}
