import 'dart:convert';

class MediaLink {
  const MediaLink(this.label, this.url, this.filename);
  final String label;
  final Uri url;
  final String filename;
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
        'Готовый файл · ${data['status']}',
        httpsUri(data['url']),
        data['filename'] as String? ?? 'video.mp4',
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
          'Видео ${i + 1} · ${format['bitrate'] ?? '?'} бит/с',
          httpsUri(format['url']),
          'twitter-${i + 1}.mp4',
        ),
      );
    }
  }
  return links;
}
