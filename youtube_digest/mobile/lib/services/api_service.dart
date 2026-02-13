import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_summary.dart';
import 'storage_service.dart';

class ApiService {
  // Update this to your local IP or production URL
  static const String baseUrl = 'http://10.0.2.2:8000'; // Special IP for Android emulator to access localhost

  Future<List<VideoSummary>> getDigest(List<String> channels) async {
    if (channels.isEmpty) return [];

    final queryParameters = {
      'channels': channels,
    };
    
    // Constructing query string for list of parameters
    String queryString = channels.map((c) => 'channels=${Uri.encodeComponent(c)}').join('&');
    final url = Uri.parse('$baseUrl/digest?$queryString');

    final storage = StorageService();
    final openaiKey = await storage.getOpenAiApiKey();
    final youtubeKey = await storage.getYoutubeApiKey();
    
    Map<String, String> headers = {};
    if (openaiKey != null && openaiKey.isNotEmpty) {
      headers['X-OpenAI-Key'] = openaiKey;
    }
    if (youtubeKey != null && youtubeKey.isNotEmpty) {
      headers['X-YouTube-Key'] = youtubeKey;
    }

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => VideoSummary.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load digest: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateChannel(String url) async {
    final uri = Uri.parse('$baseUrl/validate-channel?url=${Uri.encodeComponent(url)}');
    
    final storage = StorageService();
    final youtubeKey = await storage.getYoutubeApiKey();
    
    Map<String, String> headers = {};
    if (youtubeKey != null && youtubeKey.isNotEmpty) {
      headers['X-YouTube-Key'] = youtubeKey;
    }

    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'is_valid': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'is_valid': false, 'error': e.toString()};
    }
  }
}
