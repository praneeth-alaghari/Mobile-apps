import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  var videoId = '7rVeDSHb6lw';
  var watchUrl = 'https://www.youtube.com/watch?v=$videoId';
  
  print('Fetching watch page...');
  try {
    var response = await http.get(Uri.parse(watchUrl), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    });
    
    if (response.statusCode == 200) {
      var html = response.body;
      
      // 1. Extract INNERTUBE_API_KEY
      var apiKeyMatch = RegExp(r'"INNERTUBE_API_KEY":"([^"]+)"').firstMatch(html);
      if (apiKeyMatch != null) {
        var apiKey = apiKeyMatch.group(1);
        print('Found API KEY: $apiKey');
        
        // 2. Call InnerTube player API to get captions
        var apiUrl = 'https://www.youtube.com/youtubei/v1/player?key=$apiKey';
        var context = {
          "context": {
            "client": {
              "clientName": "ANDROID",
              "clientVersion": "20.10.38"
            }
          },
          "videoId": videoId
        };
        
        print('Calling InnerTube API...');
        var apiResp = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(context)
        );
        
        if (apiResp.statusCode == 200) {
          var data = json.decode(apiResp.body);
          var captions = data['captions']?['playerCaptionsTracklistRenderer'];
          if (captions != null && captions['captionTracks'] != null) {
            print('Found ${captions['captionTracks'].length} caption tracks in InnerTube JSON!');
            for (var track in captions['captionTracks']) {
              print(' - [${track['languageCode']}] ${track['baseUrl']}');
              
              // Try fetching one
              var transcriptResp = await http.get(Uri.parse(track['baseUrl']));
              if (transcriptResp.statusCode == 200 && transcriptResp.body.isNotEmpty) {
                 print('   -> FETCH SUCCESS! length: ${transcriptResp.body.length}');
                 return;
              }
            }
          } else {
            print('No captions found in InnerTube response.');
          }
        } else {
          print('InnerTube API failed: ${apiResp.statusCode}');
        }
      } else {
        print('Could not find INNERTUBE_API_KEY in HTML.');
      }
    } else {
      print('Failed to fetch watch page: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
