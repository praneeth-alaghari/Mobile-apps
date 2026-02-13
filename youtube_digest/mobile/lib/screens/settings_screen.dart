import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _youtubeController = TextEditingController();
  final _openaiController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final yt = await _storage.getYoutubeApiKey();
    final openai = await _storage.getOpenAiApiKey();
    setState(() {
      _youtubeController.text = yt ?? '';
      _openaiController.text = openai ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    await _storage.setYoutubeApiKey(_youtubeController.text.trim());
    await _storage.setOpenAiApiKey(_openaiController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Keys saved locally!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal API Keys')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customize Your Experience',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Optional: Provide your own keys to use your personal YouTube and OpenAI quotas. If left empty, the app will use the default shared keys.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _youtubeController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube Data API Key',
                      border: OutlineInputBorder(),
                      hintText: 'AIzaSy...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _openaiController,
                    decoration: const InputDecoration(
                      labelText: 'OpenAI API Key',
                      border: OutlineInputBorder(),
                      hintText: 'sk-proj-...',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveKeys,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('SAVE KEYS'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _youtubeController.clear();
                      _openaiController.clear();
                    },
                    child: const Text('Clear and use defaults'),
                  ),
                ],
              ),
            ),
    );
  }
}
