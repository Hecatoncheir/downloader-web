import 'package:flutter_test/flutter_test.dart';
import 'package:downloader_lab/api.dart';

void main() {
  test('Преобразование X и отклонение чужого домена', () {
    expect(
      twitterApi('https://x.com/user/status/123/video/1').toString(),
      'https://api.fxtwitter.com/user/status/123',
    );
    expect(
      () => twitterApi('https://example.com/user/status/123'),
      throwsFormatException,
    );
  });
  test('Файл Cobalt, ошибка API и локальная обработка', () {
    expect(
      parseLinks(
        '{"status":"tunnel","url":"https://example.com/file","filename":"x.mp4"}',
        false,
      ).single.filename,
      'x.mp4',
    );
    expect(
      () => parseLinks('{"error":{"code":"login"}}', false),
      throwsFormatException,
    );
    expect(
      () => parseLinks('{"status":"local-processing"}', false),
      throwsFormatException,
    );
  });
  test('Несколько видео FxEmbed: только MP4, без HLS', () {
    final links = parseLinks(
      '{"code":200,"tweet":{"media":{"videos":[{"formats":[{"container":"m3u8","url":"https://example.com/hls"},{"container":"mp4","url":"https://example.com/a"}]},{"url":"https://example.com/b"}]}}}',
      true,
    );
    expect(links.length, 2);
    expect(links.first.url.path, '/a');
  });
}
