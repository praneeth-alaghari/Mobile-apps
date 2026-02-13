import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  var videoId = 'PnJPBiVvVX4'; // Day Trader Telugu
  // videoId = 'IhLaU4fn7YE'; // MKBHD

  var instances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.privacy.com.de',
      'https://pipedapi.invidious.lacontrevoie.fr',
      'https://api.piped.otbea.org',
  ];
  
  for (var base in instances) {
      print('--- Trying $base ---');
      try {
         var apiUrl = '$base/streams/$videoId';
         var response = await http.get(Uri.parse(apiUrl)).timeout(Duration(seconds: 5));
         if (response.statusCode == 200) {
            var data = json.decode(response.body);
            var subtitles = data['subtitles']; 
            
            if (subtitles != null && (subtitles as List).isNotEmpty) {
                print('SUCCESS on $base! Found ${subtitles.length} subtitles.');
                var first = subtitles.first;
                print('First sub URL: ${first['url']}');
                
                // Fetch content
                var subResp = await http.get(Uri.parse(first['url']));
                if (subResp.statusCode == 200) {
                    print('Sub content length: ${subResp.body.length}');
                    print('Start: ${subResp.body.substring(0, 50).replaceAll('\n', ' ')}');
                    return;
                }
            } else {
                print('No subtitles found in response.');
            }
         } else {
            print('Failed: ${response.statusCode}');
         }
      } catch (e) {
         print('Error: $e');
      }
  }
}
