import 'dart:convert';

class MediaLink {
  const MediaLink(
    this.label,
    this.url,
    this.filename, {
    this.details = 'MP4',
    this.estimatedBytes,
    this.sourceUrl,
    this.attachmentUrl,
  });
  final String label;
  final Uri url;
  final String filename;
  final String details;
  final int? estimatedBytes;
  final Uri? sourceUrl;
  final Uri? attachmentUrl;
}

enum VideoService { youtube, twitter }

VideoService detectService(String value) {
  final uri = httpsUri(value);
  if ({
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  }.contains(uri.host)) {
    if (uri.path.isEmpty || uri.path == '/') {
      throw const FormatException('Вставьте ссылку на конкретное видео.');
    }
    return VideoService.youtube;
  }
  if (!{
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
    'mobile.twitter.com',
  }.contains(uri.host)) {
    throw const FormatException('Поддерживаются ссылки YouTube и Twitter / X.');
  }
  twitterApi(value);
  return VideoService.twitter;
}

String resolutionLabel(String url) {
  final match = RegExp(r'/(\d+)x(\d+)/').firstMatch(url);
  if (match == null) return 'Исходное качество';
  return '${match[1]} × ${match[2]}';
}

String cobaltQuality(String filename) {
  return RegExp(r'\((\d{2,4}p)').firstMatch(filename)?.group(1) ??
      'Исходное качество';
}

Uri httpsUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Нужна корректная ссылка HTTPS.');
  }
  return uri;
}

Uri twitterApi(String input) {
  final uri = httpsUri(input);
  if (!{
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
    'mobile.twitter.com',
  }.contains(uri.host)) {
    throw const FormatException('FxEmbed принимает только Twitter/X.');
  }
  final match = RegExp(r'^/([^/]+)/status/(\d+)(?:/|$)').firstMatch(uri.path);
  if (match == null) {
    throw const FormatException('Нужна ссылка на публикацию /status/…');
  }
  return Uri.https('api.fxtwitter.com', '/${match[1]}/status/${match[2]}');
}

List<MediaLink> parseLinks(String body, bool fx) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  if (fx) return fxLinks(data);
  if (data['error'] != null) {
    throw FormatException('API: ${jsonEncode(data['error'])}');
  }
  if (data['status'] == 'local-processing') {
    throw const FormatException(
      'Требуется объединение потоков. Эта версия его не выполняет.',
    );
  }
  if (data['url'] is String) {
    return [
      MediaLink(
        cobaltQuality(data['filename'] as String? ?? ''),
        httpsUri(data['url']),
        data['filename'] as String? ?? 'video.mp4',
        attachmentUrl: data['status'] == 'tunnel'
            ? httpsUri(data['url'])
            : null,
      ),
    ];
  }
  final picker = data['picker'] as List? ?? [];
  return [
    for (final item in picker)
      MediaLink(
        'Файл ${item['type'] ?? ''}',
        httpsUri(item['url'] as String),
        'media.mp4',
      ),
  ];
}

List<MediaLink> fxLinks(Map<String, dynamic> data) {
  if (data['code'] != 200) throw FormatException('FxEmbed: ${data['message']}');
  final videos = data['tweet']?['media']?['videos'] as List? ?? [];
  final links = <MediaLink>[];
  for (var i = 0; i < videos.length; i++) {
    final video = videos[i];
    final formats = (video['formats'] as List? ?? [])
        .where((f) => f['container'] == 'mp4')
        .toList();
    if (formats.isEmpty && video['url'] is String) {
      links.add(
        MediaLink(
          'Видео ${i + 1}',
          httpsUri(video['url']),
          'twitter-${i + 1}.mp4',
        ),
      );
    }
    for (final format in formats) {
      links.add(
        MediaLink(
          resolutionLabel(format['url'] as String),
          httpsUri(format['url']),
          'twitter-${i + 1}.mp4',
          details: 'MP4 · Видео ${i + 1}',
          estimatedBytes: estimatedSize(format['bitrate'], video['duration']),
        ),
      );
    }
  }
  return links;
}

int? estimatedSize(dynamic bitrate, dynamic duration) {
  if (bitrate is! num || duration is! num) return null;
  return (bitrate * duration / 8).round();
}

List<MediaLink> twitterDownloadChoices(String body, String input) {
  final data = jsonDecode(body) as Map<String, dynamic>;
  if (data['code'] != 200) throw FormatException('FxEmbed: ${data['message']}');
  final videos = data['tweet']?['media']?['videos'] as List? ?? [];
  final all = data['tweet']?['media']?['all'] as List? ?? [];
  final post = twitterApi(input);
  final result = <MediaLink>[];
  for (var i = 0; i < videos.length; i++) {
    final video = videos[i];
    final format = _bestTwitterFormat(video);
    if (format == null) continue;
    final url = httpsUri(format['url'] as String);
    final index = _twitterMediaIndex(video, all, i);
    result.add(
      MediaLink(
        resolutionLabel(url.toString()),
        url,
        'twitter-${i + 1}.mp4',
        details: 'MP4 · Видео ${i + 1} · исходное',
        estimatedBytes: estimatedSize(format['bitrate'], video['duration']),
        sourceUrl: Uri.https('x.com', '${post.path}/video/${index + 1}'),
      ),
    );
  }
  return result;
}

Map<String, dynamic>? _bestTwitterFormat(dynamic video) {
  final formats = (video['formats'] as List? ?? [])
      .where((f) => f['container'] == 'mp4')
      .toList();
  formats.sort(
    (a, b) =>
        ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0),
  );
  if (formats.isNotEmpty) {
    return Map<String, dynamic>.from(formats.first as Map);
  }
  if (video['url'] is String) return {'url': video['url']};
  return null;
}

int _twitterMediaIndex(dynamic video, List all, int fallback) {
  if (video['id'] == null) return fallback;
  final index = all.indexWhere((item) => item['id'] == video['id']);
  return index < 0 ? fallback : index;
}
