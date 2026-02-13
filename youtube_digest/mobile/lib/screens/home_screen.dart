import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../models/channel.dart';
import 'digest_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _api = ApiService();
  final _bgService = BackgroundService();
  final _urlController = TextEditingController();
  List<Channel> _channels = [];
  bool _isAutoDigestEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final channels = await _storage.getChannels();
    final isEnabled = await _storage.isAutoDigestEnabled();
    setState(() {
      _channels = channels;
      _isAutoDigestEnabled = isEnabled;
    });
  }

  Future<void> _toggleAutoDigest(bool value) async {
    await _storage.setAutoDigestEnabled(value);
    setState(() => _isAutoDigestEnabled = value);
    if (value) {
      await _bgService.scheduleDailyJob();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-Digest scheduled for 9:00 AM')),
      );
    } else {
      _bgService.cancelDailyJob();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-Digest disabled')),
      );
    }
  }

  Future<void> _manualFetch() async {
    if (_channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some channels first!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final channelUrls = _channels.map((c) => c.url).toList();
      final summaries = await _api.getDigest(channelUrls);
      if (summaries.isNotEmpty) {
        await _storage.saveSummaries(summaries);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DigestScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new videos found for the last 24h.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addChannel() async {
    String input = _urlController.text.trim();
    if (input.isEmpty) return;

    setState(() => _isLoading = true);
    
    final validation = await _api.validateChannel(input);
    
    if (mounted) setState(() => _isLoading = false);

    if (validation['is_valid'] == true) {
      final name = validation['channel_name'] ?? 'Channel';
      final thumb = validation['channel_thumbnail'] ?? '';
      
      await _storage.addChannel(Channel(
        url: validation['is_valid'] == true ? input : input, // We'll store what user typed or normalized
        name: name,
        thumbnailUrl: thumb,
      ));
      
      _urlController.clear();
      _loadChannels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully added: $name')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation failed: ${validation['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeChannel(String url) async {
    await _storage.removeChannel(url);
    _loadChannels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Digest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DigestScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              "Waking up server... this may take a few seconds ☕",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Auto-Digest (9:00 AM)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _isAutoDigestEnabled,
                      onChanged: _isLoading ? null : _toggleAutoDigest,
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          hintText: 'Enter YouTube Channel URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addChannel,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return ListTile(
                  leading: channel.thumbnailUrl.isNotEmpty 
                    ? CircleAvatar(backgroundImage: NetworkImage(channel.thumbnailUrl))
                    : const CircleAvatar(child: Icon(Icons.play_arrow)),
                  title: Text(channel.name),
                  subtitle: Text(channel.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _isLoading ? null : () => _removeChannel(channel.url),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('FETCH NOW (MANUAL)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _manualFetch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
