import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:downloader_lab/api.dart';
import 'package:downloader_lab/probe_cubit.dart';

void main() {
  test('Сервис определяется по домену, поддельные домены отклоняются', () {
    for (final url in [
      'https://youtu.be/abc',
      'https://www.youtube.com/shorts/abc',
      'https://m.youtube.com/watch?v=abc',
    ]) {
      expect(detectService(url), VideoService.youtube);
    }
    expect(
      detectService('https://x.com/user/status/123'),
      VideoService.twitter,
    );
    expect(
      () => detectService('https://youtube.com.evil.org/watch?v=abc'),
      throwsFormatException,
    );
    expect(() => detectService('https://youtube.com/'), throwsFormatException);
  });
  test('Разрешение и оценка размера Twitter берутся из ответа', () {
    final links = parseLinks(
      jsonEncode({
        'code': 200,
        'tweet': {
          'media': {
            'videos': [
              {
                'duration': 10,
                'formats': [
                  {
                    'container': 'mp4',
                    'url': 'https://video.twimg.com/vid/720x1280/test.mp4',
                    'bitrate': 800000,
                  },
                ],
              },
            ],
          },
        },
      }),
      true,
    );
    expect(links.single.label, '720 × 1280');
    expect(links.single.estimatedBytes, 1000000);
    expect(cobaltQuality('Название 1080p (360p, h264).mp4'), '360p');
    expect(estimatedSize(null, 10), isNull);
  });
  test('Автоматический Twitter использует FxEmbed', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.fxtwitter.com');
      return http.Response(
        '{"code":200,"tweet":{"media":{"videos":[{"url":"https://example.org/file.mp4"}]}}}',
        200,
      );
    });
    final cubit = ProbeCubit(clientFactory: () => client);
    await cubit.inspectAuto('https://x.com/user/status/123');
    expect(cubit.state.links.length, 1);
    expect(cubit.state.busy, false);
    await cubit.close();
  });
  test(
    'YouTube сохраняет успешные качества при ошибке одного варианта',
    () async {
      final client = MockClient((request) async {
        final quality = jsonDecode(request.body)['videoQuality'];
        if (quality == '1080') return http.Response('{"error":"login"}', 400);
        return http.Response(
          jsonEncode({
            'status': 'tunnel',
            'url': 'https://example.org/$quality',
            'filename': 'Video (${quality}p, h264).mp4',
          }),
          200,
        );
      });
      final cubit = ProbeCubit(clientFactory: () => client);
      await cubit.inspectAuto('https://youtu.be/abc');
      expect(cubit.state.links.map((l) => l.label), ['360p', '720p']);
      expect(cubit.state.log, contains('400'));
      await cubit.close();
    },
  );
  test('Поздний ответ не перезаписывает отменённый запрос', () async {
    final response = Completer<http.Response>();
    final cubit = ProbeCubit(
      clientFactory: () => MockClient((_) => response.future),
    );
    final pending = cubit.inspectAuto('https://x.com/user/status/123');
    await Future<void>.delayed(Duration.zero);
    cubit.cancel();
    response.complete(http.Response('{"code":200,"tweet":{}}', 200));
    await pending;
    expect(cubit.state.message, 'Запрос отменён');
    expect(cubit.state.busy, false);
    await cubit.close();
  });
}
