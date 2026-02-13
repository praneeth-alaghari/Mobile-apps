import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import '../models/video_summary.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final storage = StorageService();
      final api = ApiService();
      final notifications = NotificationService();
      
      await notifications.init();
      
      final channels = await storage.getChannels();
      if (channels.isEmpty) return true;

      final urls = channels.map((c) => c.url).toList();
      List<VideoSummary> summaries = await api.getDigest(urls);
      
      if (summaries.isNotEmpty) {
        await storage.saveSummaries(summaries);
        await notifications.showNotification(
          id: 1,
          title: 'Daily YouTube Digest Ready!',
          body: 'Check out ${summaries.length} new video summaries from your favorite channels.',
        );
      }
      return true;
    } catch (e) {
      print('Background Task Error: $e');
      return false;
    }
  });
}

class BackgroundService {
  void init() {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false for production
    );
  }

  Future<void> scheduleDailyJob() async {
    final storage = StorageService();
    bool enabled = await storage.isAutoDigestEnabled();
    if (!enabled) return;

    Workmanager().registerPeriodicTask(
      "daily-digest-task",
      "fetchAndSummarize",
      frequency: const Duration(hours: 24),
      initialDelay: _calculateDelayUntil9AM(),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  void cancelDailyJob() {
    Workmanager().cancelByUniqueName("daily-digest-task");
  }

  Duration _calculateDelayUntil9AM() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 9, 0, 0);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    return scheduledTime.difference(now);
  }
}
