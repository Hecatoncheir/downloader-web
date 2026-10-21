import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:downloader_lab/api.dart';
import 'package:downloader_lab/probe_cubit.dart';

void main() {
  test('Twitter: только исходный вариант, индекс учитывает фотографии', () {
    final choices = twitterDownloadChoices(
      jsonEncode({
        'code': 200,
        'tweet': {
          'media': {
            'all': [
              {'id': 'photo'},
              {'id': 'video'},
            ],
            'videos': [
              {
                'id': 'video',
                'duration': 10,
                'formats': [
                  {
                    'container': 'mp4',
                    'url': 'https://video.twimg.com/vid/320x180/a.mp4',
                    'bitrate': 100,
                  },
                  {
                    'container': 'mp4',
                    'url': 'https://video.twimg.com/vid/1280x720/b.mp4',
                    'bitrate': 200,
                  },
                ],
              },
            ],
          },
        },
      }),
      'https://x.com/test/status/123',
    );
    expect(choices.single.label, '1280 × 720');
    expect(choices.single.url.path, endsWith('/b.mp4'));
    expect(
      choices.single.sourceUrl.toString(),
      'https://x.com/test/status/123/video/2',
    );
  });
  test(
    'Скачивание Twitter готовит attachment, не запрашивая video.twimg.com',
    () async {
      final requests = <http.Request>[];
      final cubit = ProbeCubit(
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          expect(request.method, 'POST');
          final data = jsonDecode(request.body);
          expect(data['alwaysProxy'], true);
          expect(data['url'], 'https://x.com/test/status/123/video/2');
          return http.Response(
            '{"status":"tunnel","url":"https://rue-cobalt.xenon.zone/tunnel?id=1","filename":"twitter.mp4"}',
            200,
          );
        }),
      );
      await cubit.download(
        MediaLink(
          '1280 × 720',
          Uri.parse('https://video.twimg.com/vid/1280x720/a.mp4'),
          'original.mp4',
          sourceUrl: Uri.parse('https://x.com/test/status/123/video/2'),
        ),
      );
      expect(requests.length, 1);
      expect(cubit.state.attachmentUrl?.host, 'rue-cobalt.xenon.zone');
      expect(cubit.state.file, isNull);
      expect(cubit.state.message, isNot(contains('целиком')));
      await cubit.close();
    },
  );
  test('Redirect в проигрыватель не выдаётся за скачивание', () async {
    final cubit = ProbeCubit(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          '{"status":"redirect","url":"https://video.twimg.com/a.mp4"}',
          200,
        ),
      ),
    );
    await cubit.download(
      MediaLink(
        '720p',
        Uri.parse('https://video.twimg.com/a.mp4'),
        'a.mp4',
        sourceUrl: Uri.parse('https://x.com/test/status/123/video/1'),
      ),
    );
    expect(cubit.state.attachmentUrl, isNull);
    expect(cubit.state.downloadFailed, true);
    expect(cubit.state.message, contains('не выдал'));
    await cubit.close();
  });
}
