import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Standalone script to test the full flow:
// 1. Fetch transcript from YouTube (Local/Emulator)
// 2. Send to Render Backend for summarization

const String backendUrl = 'https://youtube-digest-api.onrender.com';
// You might need to supply your OpenAI key here if the server requires it 
// and doesn't have a default fallback, or if you want to test with a specific key.
const String? userOpenAiKey = null; 

void main() async {
  var yt = YoutubeExplode();
  try {
    print('--- Starting Integration Test ---');
    
    // 1. Find a video with captions (MKBHD usually has them)
    // var query = 'MKBHD';
    // var videoId = 'IhLaU4fn7YE'; // Known recent video, might change.
    // Better to search dynamically
    print('Searching for recent MKBHD video...');
    var channelId = 'UCBJycsmduvYEL83R_U4JriQ'; 
    var uploads = await yt.channels.getUploads(ChannelId(channelId)).take(1).toList();
    
    if (uploads.isEmpty) {
        print('No uploads found.');
        return;
    }
    
    var video = uploads.first;
    print('Found video: ${video.title} (${video.id})');
    
    // 2. Fetch Transcript
    print('Fetching transcript...');
    var manifest = await yt.videos.closedCaptions.getManifest(video.id);
    var trackInfo = manifest.getByLanguage('en').firstOrNull ?? manifest.tracks.firstOrNull;
    
    if (trackInfo == null) {
        print('No captions found for this video.');
        return;
    }
    
    var track = await yt.videos.closedCaptions.get(trackInfo);
    // Access usage: .captions property
    var transcriptText = track.captions.map((c) => c.text).join(' ');
    print('Transcript length: ${transcriptText.length} characters');
    print('Sample: ${transcriptText.substring(0, 100)}...');
    
    // 3. Send to Render
    print('Sending to Render backend: $backendUrl/summarize');
    
    var response = await http.post(
        Uri.parse('$backendUrl/summarize'),
        headers: {
            'Content-Type': 'application/json',
            if (userOpenAiKey != null) 'X-OpenAI-Key': userOpenAiKey!,
        },
        body: json.encode({'text': transcriptText})
    );
    
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
        print('SUCCESS: Summary received!');
    } else {
        print('FAILURE: Backend returned error.');
    }

  } catch (e) {
    print('FATAL ERROR: $e');
  } finally {
    yt.close();
  }
}
