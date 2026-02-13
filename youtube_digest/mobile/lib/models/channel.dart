class Channel {
  final String url;
  final String name;
  final String thumbnailUrl;

  Channel({
    required this.url,
    required this.name,
    required this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
  };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    url: json['url'] ?? '',
    name: json['name'] ?? 'Unknown',
    thumbnailUrl: json['thumbnailUrl'] ?? '',
  );
}
