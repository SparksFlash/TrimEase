import 'package:workmanager/workmanager.dart';
import 'package:hive/hive.dart';

// Simple background callback. Keep minimal to avoid plugin issues.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (!Hive.isBoxOpen('owner_box')) {
        await Hive.openBox('owner_box');
      }
      final box = Hive.box('owner_box');
      // Mark last background tick; the foreground can interpret this as a sync ping.
      box.put('last_sync_millis', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Ignore errors to avoid failing the background task.
    }
    return Future.value(true);
  });
}

class BackgroundTasks {
  static const periodicOwnerSync = 'periodic_owner_sync';

  static Future<void> initialize() async {
    // isInDebugMode left as false to reduce noise in production.
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> ensurePeriodicOwnerSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        periodicOwnerSync,
        periodicOwnerSync,
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(minutes: 5),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {
      // Ignore scheduling errors
    }
  }
}
