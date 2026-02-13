class VideoSummary {
  final String videoId;
  final String title;
  final String channelName;
  final String publishedAt;
  final String summary;
  final String thumbnailUrl;

  VideoSummary({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.publishedAt,
    required this.summary,
    required this.thumbnailUrl,
  });

  factory VideoSummary.fromJson(Map<String, dynamic> json) {
    return VideoSummary(
      videoId: json['video_id'],
      title: json['title'],
      channelName: json['channel_name'],
      publishedAt: json['published_at'],
      summary: json['summary'],
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'title': title,
      'channel_name': channelName,
      'published_at': publishedAt,
      'summary': summary,
      'thumbnail_url': thumbnailUrl,
    };
  }
}
