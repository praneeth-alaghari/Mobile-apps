import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_summary.dart';
import 'storage_service.dart';

class ApiService {
  // Update this to your local IP or production URL
  static const String baseUrl = 'https://youtube-digest-api.onrender.com'; // Production URL

  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<VideoSummary>> getDigest(List<String> channels) async {
    if (channels.isEmpty) return [];

    List<VideoSummary> summaries = [];
    final storage = StorageService();
    final openaiKey = await storage.getOpenAiApiKey();

    for (String channelInput in channels) {
      try {
        Channel? channel;
        // 1. Resolve Channel
        String query = channelInput;
        // Basic cleanup
        if (query.contains('youtube.com/')) {
           if (query.contains('/channel/')) {
             query = query.split('/channel/').last;
           } else if (query.contains('/@')) {
             query = query.split('/@').last;
             if (!query.startsWith('@')) query = '@' + query;
           }
        }

        if (query.startsWith('UC') && query.length >= 24) {
             try {
                channel = await _yt.channels.get(ChannelId(query));
             } catch (_) {
                // Ignore, fallback to search
             }
        } 
        
        if (channel == null) {
            // Search
             var results = await _yt.search(channelInput);
             if (results.isNotEmpty) {
                 var searchChannel = results.whereType<SearchChannel>().firstOrNull;
                 if (searchChannel != null) {
                     channel = await _yt.channels.get(searchChannel.id);
                 } else {
                     var video = results.whereType<Video>().firstOrNull;
                     if (video != null) {
                         channel = await _yt.channels.get(video.channelId);
                     }
                 }
             }
        }

        if (channel == null) {
           print('[YT-DEBUG] Channel not found after search: $channelInput');
           continue;
        }
        
        print('[YT-DEBUG] Found channel: ${channel.title}');

        // 2. Get Uploads (Latest Video)
        var uploads = await _yt.channels.getUploads(channel.id).take(1).toList();
        if (uploads.isEmpty) {
            print('[YT-DEBUG] No videos found for ${channel.title}');
            continue;
        }
        
        var video = uploads.first;
        print('[YT-DEBUG] Using video: ${video.title} (${video.id})');
        
        // 3. Get Transcript
        String transcriptText = "";
        try {
           var manifest = await _yt.videos.closedCaptions.getManifest(video.id);
           var tracks = manifest.getByLanguage('en'); 
           
           ClosedCaptionTrackInfo? trackToUse;
           if (tracks.isNotEmpty) {
              trackToUse = tracks.first;
              print('[YT-DEBUG] Found English captions.');
           } else if (manifest.tracks.isNotEmpty) {
              trackToUse = manifest.tracks.first;
              print('[YT-DEBUG] Found non-English captions (using first available).');
           }

           if (trackToUse != null) {
              var track = await _yt.videos.closedCaptions.get(trackToUse);
              transcriptText = track.captions.map((c) => c.text).join(' ');
              print('[YT-DEBUG] Transcript fetched successfully. Length: ${transcriptText.length}');
           } else {
              print('[YT-DEBUG] No caption tracks found.');
           }
        } catch (e) {
           print("[YT-DEBUG] Error fetching transcript for ${video.id}: $e");
        }

        // 4. Summarize (Backend call)
        String summary = "No transcript available.";
        if (transcriptText.isNotEmpty) {
            print('[YT-DEBUG] Sending transcript to backend for summarization...');
            try {
                final summaryResult = await _summarizeText(transcriptText, openaiKey);
                if (summaryResult != null) {
                    summary = summaryResult;
                    print('[YT-DEBUG] Summary received successfully.');
                } else {
                    summary = "Summary generation failed server-side.";
                    print('[YT-DEBUG] Summary generation failed on server.');
                }
            } catch (e) {
                summary = "Error contacting summarization service.";
                print('[YT-DEBUG] Exception calling _summarizeText: $e');
            }
        } else {
            print('[YT-DEBUG] No transcript found. Skipping summarization.');
            summary = "Cannot summarize video without captions/transcript.";
        }

        summaries.add(VideoSummary(
            videoId: video.id.value,
            title: video.title,
            channelName: channel.title,
            publishedAt: video.publishDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
            summary: summary,
            thumbnailUrl: video.thumbnails.highResUrl,
        ));

      } catch (e) {
        print('Error processing $channelInput: $e');
      }
    }
    return summaries;
  }

  Future<String?> _summarizeText(String text, String? openaiKey) async {
    final url = Uri.parse('$baseUrl/summarize');
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (openaiKey != null && openaiKey.isNotEmpty) {
      headers['X-OpenAI-Key'] = openaiKey;
    }

    try {
      final response = await http.post(
        url, 
        headers: headers, 
        body: json.encode({'text': text})
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['summary'];
      } else {
        print('Backend summarization failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
       print('Error calling summarize endpoint: $e');
       return null;
    }
  }

  Future<Map<String, dynamic>> validateChannel(String url) async {
      try {
          Channel? channel;
          
          if (url.startsWith('UC') && url.length >= 24) {
             try {
                channel = await _yt.channels.get(ChannelId(url));
             } catch (_) {}
          }

          if (channel == null) {
             var results = await _yt.search(url);
             if (results.isNotEmpty) {
                 var searchChannel = results.whereType<SearchChannel>().firstOrNull;
                 if (searchChannel != null) {
                     channel = await _yt.channels.get(searchChannel.id);
                 } else {
                     var video = results.whereType<Video>().firstOrNull;
                     if (video != null) {
                         channel = await _yt.channels.get(video.channelId);
                     }
                 }
             }
          }
          
          if (channel != null) {
             return {
                  'is_valid': true,
                  'channel_name': channel.title,
                  'channel_thumbnail': channel.logoUrl
             };
          }
          return {'is_valid': false, 'error': 'Channel not found'};
      } catch (e) {
          return {'is_valid': false, 'error': e.toString()};
      }
  }
}
