import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:downloader_lab/api.dart';
import 'package:downloader_lab/probe_cubit.dart';

void main() {
  for (final sharing in [false, true]) {
    test('Ошибка подготовки: прямой файл, отправка=$sharing', () async {
      final requests = <String>[];
      final cubit = ProbeCubit(
        clientFactory: () => MockClient((request) async {
          requests.add(request.method);
          if (request.method == 'POST') {
            return http.Response(
              '{"error":{"code":"error.api.fetch.empty"}}',
              400,
            );
          }
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'video/mp4'},
          );
        }),
      );
      await cubit.download(
        MediaLink(
          '720p',
          Uri.parse('https://video.twimg.com/a.mp4'),
          'a.mp4',
          sourceUrl: Uri.parse('https://x.com/test/status/123/video/1'),
        ),
        forSharing: sharing,
      );
      expect(requests, sharing ? ['POST', 'GET'] : ['GET']);
      expect(sharing ? cubit.state.shareFile : cubit.state.file, [1, 2, 3]);
      expect(cubit.state.downloadFailed, false);
      expect(cubit.state.fallbackUrl, isNull);
      await cubit.close();
    });
  }
  test('Дозагрузка ждёт лимит сервиса и обновляет истёкшую ссылку', () async {
    final stream = StreamController<List<int>>();
    var preparations = 0;
    var parts = 0;
    final cubit = ProbeCubit(
      transferIdleTimeout: const Duration(milliseconds: 30),
      clientFactory: () => MockClient.streaming((request, body) async {
        if (request.method == 'POST') {
          preparations++;
          final data = utf8.encode(
            '{"status":"tunnel","url":"https://example.com/tunnel$preparations","filename":"video.mp4"}',
          );
          return http.StreamedResponse(Stream.value(data), 200);
        }
        if (request.headers['Range'] == null) {
          stream.add([1]);
          return http.StreamedResponse(stream.stream, 200, contentLength: 3);
        }
        parts++;
        if (parts == 1) {
          return http.StreamedResponse(
            Stream.empty(),
            429,
            headers: {'retry-after': '1'},
          );
        }
        if (parts == 2) return http.StreamedResponse(Stream.empty(), 404);
        expect(request.url.path, '/tunnel2');
        expect(request.headers['Range'], 'bytes=1-2');
        return http.StreamedResponse(Stream.value([2, 3]), 206);
      }),
    );
    await cubit.download(
      MediaLink(
        '720p',
        Uri.parse('https://video.twimg.com/video.mp4'),
        'video.mp4',
        sourceUrl: Uri.parse('https://x.com/test/status/123'),
      ),
      forSharing: true,
    );
    expect(cubit.state.shareFile, [1, 2, 3]);
    expect(preparations, 2);
    expect(parts, 3);
    await stream.close();
    await cubit.close();
  });

  test(
    'Кнопка скачивания получает все части файла без потери байтов',
    () async {
      final stream = StreamController<List<int>>();
      final expected = List.generate(40000, (index) => index % 251);
      final ranges = <String>[];
      final cubit = ProbeCubit(
        transferIdleTimeout: const Duration(milliseconds: 30),
        clientFactory: () => MockClient.streaming((request, body) async {
          final range = request.headers['Range'];
          if (range == null) {
            stream.add(expected.sublist(0, 100));
            return http.StreamedResponse(
              stream.stream,
              200,
              contentLength: expected.length,
              headers: {'content-type': 'video/mp4'},
            );
          }
          ranges.add(range);
          final bounds = range.substring(6).split('-').map(int.parse).toList();
          final part = expected.sublist(bounds[0], bounds[1] + 1);
          return http.StreamedResponse(
            Stream.value(part),
            206,
            contentLength: part.length,
          );
        }),
      );
      await cubit.download(
        MediaLink(
          '720p',
          Uri.parse('https://example.com/video.mp4'),
          'video.mp4',
        ),
      );
      expect(cubit.state.file, expected);
      expect(ranges, [
        'bytes=100-16483',
        'bytes=16484-32867',
        'bytes=32868-39999',
      ]);
      await stream.close();
      await cubit.close();
    },
  );

  test(
    'Зависший поток завершается ошибкой и снимает состояние загрузки',
    () async {
      final stream = StreamController<List<int>>();
      final cubit = ProbeCubit(
        transferIdleTimeout: const Duration(milliseconds: 30),
        clientFactory: () => MockClient.streaming(
          (request, body) async => http.StreamedResponse(
            stream.stream,
            200,
            headers: {'content-type': 'video/mp4'},
          ),
        ),
      );
      await cubit.download(
        MediaLink(
          '720p',
          Uri.parse('https://example.com/video.mp4'),
          'video.mp4',
        ),
        forSharing: true,
      );
      expect(cubit.state.busy, false);
      expect(cubit.state.downloadFailed, true);
      expect(cubit.state.message, contains('перестал отвечать'));
      expect(cubit.state.shareFile, isNull);
      await stream.close();
      await cubit.close();
    },
  );

  test('При ошибке туннеля отправка получает сам файл напрямую', () async {
    final requests = <Uri>[];
    final cubit = ProbeCubit(
      clientFactory: () => MockClient((request) async {
        requests.add(request.url);
        if (request.method == 'POST') {
          return http.Response(
            '{"status":"tunnel","url":"https://example.com/tunnel","filename":"video.mp4"}',
            200,
          );
        }
        if (request.url.path == '/tunnel') return http.Response('', 502);
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'video/mp4'},
        );
      }),
    );
    final url = Uri.parse('https://video.twimg.com/video.mp4');
    await cubit.download(
      MediaLink(
        '720p',
        url,
        'video.mp4',
        sourceUrl: Uri.parse('https://x.com/test/status/123'),
      ),
      forSharing: true,
    );
    expect(requests.last, url);
    expect(cubit.state.shareFile, [1, 2, 3]);
    expect(cubit.state.shareSourceUrl, url);
    expect(cubit.state.busy, false);
    expect(cubit.state.fallbackUrl, isNull);
    await cubit.close();
  });
  test(
    'Поделиться получает файл из туннеля без сохранения и открытия ссылки',
    () async {
      final cubit = ProbeCubit(
        clientFactory: () => MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              '{"status":"tunnel","url":"https://rue-cobalt.xenon.zone/tunnel?id=share","filename":"video.mp4"}',
              200,
            );
          }
          expect(request.url.host, 'rue-cobalt.xenon.zone');
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'video/mp4'},
          );
        }),
      );
      final link = MediaLink(
        '720p',
        Uri.parse('https://video.twimg.com/a.mp4'),
        'video.mp4',
        sourceUrl: Uri.parse('https://x.com/test/status/123/video/1'),
      );
      await cubit.download(link, forSharing: true);
      expect(cubit.state.shareFile, [1, 2, 3]);
      expect(cubit.state.shareSourceUrl, link.url);
      expect(cubit.state.file, isNull);
      expect(cubit.state.attachmentUrl, isNull);
      expect(cubit.state.fallbackUrl, isNull);
      await cubit.close();
    },
  );
  test(
    'Ошибка подготовки отправки не открывает видео и не подменяет файл ссылкой',
    () async {
      final cubit = ProbeCubit(
        clientFactory: () => MockClient((_) async => http.Response('', 403)),
      );
      await cubit.download(
        MediaLink(
          '360p',
          Uri.parse('https://video.twimg.com/a.mp4'),
          'video.mp4',
        ),
        forSharing: true,
      );
      expect(cubit.state.downloadFailed, true);
      expect(cubit.state.shareFile, isNull);
      expect(cubit.state.fallbackUrl, isNull);
      await cubit.close();
    },
  );
  test('Twitter: все варианты, только лучший использует туннель', () {
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
    expect(choices.length, 2);
    expect(choices.first.label, '1280 × 720');
    expect(choices.first.url.path, endsWith('/b.mp4'));
    expect(choices.last.label, '320 × 180');
    expect(choices.last.sourceUrl, isNull);
    expect(
      choices.first.sourceUrl.toString(),
      'https://x.com/test/status/123/video/2',
    );
  });
  test('При ошибке прямой загрузки Twitter получает файл из туннеля', () async {
    final requests = <http.Request>[];
    final cubit = ProbeCubit(
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'video.twimg.com') {
          return http.Response('', 403);
        }
        if (request.method == 'GET') {
          expect(request.url.host, 'rue-cobalt.xenon.zone');
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'video/mp4'},
          );
        }
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
    expect(requests.map((r) => r.method), ['GET', 'POST', 'GET']);
    expect(cubit.state.attachmentUrl, isNull);
    expect(cubit.state.file, [1, 2, 3]);
    expect(cubit.state.filename, 'twitter.mp4');
    await cubit.close();
  });
  test('Меньшее качество получает файл напрямую прежним способом', () async {
    final url = Uri.parse('https://video.twimg.com/vid/320x180/a.mp4');
    final cubit = ProbeCubit(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, url);
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'video/mp4'},
        );
      }),
    );
    await cubit.download(MediaLink('320 × 180', url, 'small.mp4'));
    expect(cubit.state.file, [1, 2, 3]);
    expect(cubit.state.attachmentUrl, isNull);
    expect(cubit.state.downloadFailed, false);
    await cubit.close();
  });
  test(
    'Ответ redirect не подменяет файл, если прямое получение тоже не удалось',
    () async {
      final cubit = ProbeCubit(
        clientFactory: () => MockClient(
          (_) async => http.Response(
            '{"status":"redirect","url":"https://video.twimg.com/a.mp4"}',
            200,
            headers: {'content-type': 'application/json'},
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
      expect(cubit.state.fallbackUrl, isNull);
      expect(cubit.state.message, contains('не выдал ссылку'));
      await cubit.close();
    },
  );
}
