@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:downloader_lab/transport_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Чтение большого ответа с паузами сохраняет все байты', () async {
    final client = createTransportClient();
    addTearDown(client.close);
    final bytes = Uint8List.fromList(List.generate(256 * 1024, (i) => i % 251));
    final response = await client.send(
      http.Request(
        'GET',
        Uri.dataFromBytes(bytes, mimeType: 'application/octet-stream'),
      ),
    );
    final received = BytesBuilder();
    await for (final part in response.stream.timeout(
      const Duration(seconds: 5),
    )) {
      received.add(part);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(received.takeBytes(), bytes);
  });

  test('Закрытие клиента отменяет ответ после получения заголовков', () async {
    final client = createTransportClient();
    final response = await client.send(
      http.Request(
        'GET',
        Uri.dataFromString('video body', mimeType: 'text/plain'),
      ),
    );
    client.close();
    await expectLater(
      response.stream.toBytes().timeout(const Duration(seconds: 5)),
      throwsA(isA<http.ClientException>()),
    );
  });
}
