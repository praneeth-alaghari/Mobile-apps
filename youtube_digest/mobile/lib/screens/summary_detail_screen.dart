import 'package:flutter/material.dart';
import '../models/video_summary.dart';
import 'package:url_launcher/url_launcher.dart';

class SummaryDetailScreen extends StatelessWidget {
  final VideoSummary summary;

  const SummaryDetailScreen({super.key, required this.summary});

  Future<void> _openVideo(String videoId) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                summary.thumbnailUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              summary.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.channelName} • ${summary.publishedAt}',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const Divider(height: 32),
            const Text(
              'AI Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              summary.summary, // The prompt now ensures bullet points
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('WATCH ON YOUTUBE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openVideo(summary.videoId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
