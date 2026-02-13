import 'package:yt_digest/services/api_service.dart';

void main() async {
  final api = ApiService();
  print('--- Testing ApiService.getDigest with problematic channels ---');
  
  // Test with one of the channels the user provided
  var channels = ['DAY TRADER తెలుగు'];
  
  try {
    var summaries = await api.getDigest(channels);
    print('\nResults:');
    for (var s in summaries) {
       print('Channel: ${s.channelName}');
       print('Video: ${s.title}');
       print('Summary Length: ${s.summary.length}');
       print('Summary Start: ${s.summary.substring(0, (s.summary.length > 100 ? 100 : s.summary.length))}');
    }
  } catch (e) {
    print('ApiService call failed: $e');
  }
}
