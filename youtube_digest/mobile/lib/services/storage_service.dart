import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_summary.dart';
import '../models/channel.dart';

class StorageService {
  static const String _channelsKey = 'youtube_channels';
  static const String _summariesKey = 'latest_summaries';
  static const String _autoDigestKey = 'auto_digest_enabled';
  static const String _youtubeKey = 'youtube_api_key';
  static const String _openaiKey = 'openai_api_key';

  Future<List<Channel>> getChannels() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> data = prefs.getStringList(_channelsKey) ?? [];
    return data.map((item) {
      try {
        final decoded = json.decode(item);
        if (decoded is Map<String, dynamic>) {
          return Channel.fromJson(decoded);
        } else {
          // It's probably an old URL string
          return Channel(url: item, name: 'Legacy Channel', thumbnailUrl: '');
        }
      } catch (e) {
        // Fallback for raw strings that aren't even JSON encoded
        return Channel(url: item, name: 'Legacy Channel', thumbnailUrl: '');
      }
    }).toList();
  }

  Future<void> addChannel(Channel channel) async {
    final prefs = await SharedPreferences.getInstance();
    List<Channel> channels = await getChannels();
    if (!channels.any((c) => c.url == channel.url)) {
      channels.add(channel);
      List<String> data = channels.map((c) => json.encode(c.toJson())).toList();
      await prefs.setStringList(_channelsKey, data);
    }
  }

  Future<void> removeChannel(String url) async {
    final prefs = await SharedPreferences.getInstance();
    List<Channel> channels = await getChannels();
    channels.removeWhere((c) => c.url == url);
    List<String> data = channels.map((c) => json.encode(c.toJson())).toList();
    await prefs.setStringList(_channelsKey, data);
  }

  Future<void> saveSummaries(List<VideoSummary> summaries) async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = json.encode(summaries.map((s) => s.toJson()).toList());
    await prefs.setString(_summariesKey, encoded);
  }

  Future<List<VideoSummary>> getSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    String? encoded = prefs.getString(_summariesKey);
    if (encoded == null) return [];
    List<dynamic> data = json.decode(encoded);
    return data.map((json) => VideoSummary.fromJson(json)).toList();
  }

  Future<bool> isAutoDigestEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDigestKey) ?? true; // Default to true
  }

  Future<void> setAutoDigestEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDigestKey, enabled);
  }

  Future<String?> getYoutubeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_youtubeKey);
  }

  Future<void> setYoutubeApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_youtubeKey);
    } else {
      await prefs.setString(_youtubeKey, key);
    }
  }

  Future<String?> getOpenAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openaiKey);
  }

  Future<void> setOpenAiApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_openaiKey);
    } else {
      await prefs.setString(_openaiKey, key);
    }
  }
}
