import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  var videoId = 'PnJPBiVvVX4'; // DAY TRADER తెలుగు
  // Try a few public instances
  var instances = [
    'https://invidious.jing.rocks',
    'https://invidious.nerdvpn.de',
    'https://invidious.flokinet.to',
    'https://inv.vern.cc'
  ];

  for (var instance in instances) {
    print('Trying instance: $instance');
    try {
      // First, get caption list to see available labels
      var response = await http.get(Uri.parse('$instance/api/v1/captions/$videoId'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        var captions = data['captions'];
        print('Found ${captions.length} captions.');
        
        if (captions.isNotEmpty) {
          // Take the first one or search for English
          var best = captions.first;
          for (var c in captions) {
            if (c['label'].toString().toLowerCase().contains('english')) {
              best = c;
              break;
            }
          }
          
          print('Best caption: ${best['label']} (type: ${best['type']})');
          
          // Download the actual transcript
          // The API returns the content directly if you use ?label= and ?type=
          // Wait, Invidious API docs say: get /api/v1/captions/<video_id>?label=<label>
          var label = best['label'];
          var type = best['type'] ?? 'vtt'; // fallback
          
          var transcriptResp = await http.get(Uri.parse('$instance/api/v1/captions/$videoId?label=${Uri.encodeComponent(label)}'));
          if (transcriptResp.statusCode == 200) {
            print('SUCCESS! Transcript length: ${transcriptResp.body.length}');
            // print('Sample: ${transcriptResp.body.substring(0, 100).replaceAll('\n', ' ')}');
            return;
          } else {
            print('Failed to fetch transcript: ${transcriptResp.statusCode}');
          }
        }
      } else {
        print('Failed to get caption list: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
    print('---');
  }
}
