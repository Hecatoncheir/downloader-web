import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createTransportClient() => _TransportClient();

// Читаем Fetch-поток напрямую: async* сохраняет порядок байтов и обратное
// давление, а отмена прерывает сам запрос, включая чтение тела ответа.
class _TransportClient extends http.BaseClient {
  final _requests = <web.AbortController>{};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Клиент закрыт', request.url);
    final abort = web.AbortController();
    _requests.add(abort);
    try {
      final body = await request.finalize().toBytes();
      if (_closed) throw http.ClientException('Запрос отменён', request.url);
      final response = await web.window
          .fetch(
            request.url.toString().toJS,
            web.RequestInit(
              method: request.method,
              headers: request.headers.jsify()! as web.HeadersInit,
              body: body.isEmpty ? null : body.toJS,
              signal: abort.signal,
              cache: 'no-store',
              credentials: 'same-origin',
              redirect: request.followRedirects ? 'follow' : 'error',
            ),
          )
          .toDart;
      final headers = <String, String>{};
      (response.headers as _Headers).forEach(
        ((
          String value,
          String name,
        ) => headers[name.toLowerCase()] = value).toJS,
      );
      return http.StreamedResponse(
        _body(response, abort, request.url),
        response.status,
        headers: headers,
        contentLength: int.tryParse(headers['content-length'] ?? ''),
        reasonPhrase: response.statusText,
        request: request,
      );
    } catch (error) {
      _requests.remove(abort);
      abort.abort();
      throw http.ClientException('$error', request.url);
    }
  }

  Stream<List<int>> _body(
    web.Response response,
    web.AbortController abort,
    Uri url,
  ) async* {
    final reader =
        response.body?.getReader() as web.ReadableStreamDefaultReader?;
    try {
      if (reader == null) return;
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        yield (chunk.value! as JSUint8Array).toDart;
      }
    } catch (error) {
      throw http.ClientException('$error', url);
    } finally {
      abort.abort();
      _requests.remove(abort);
      reader?.releaseLock();
    }
  }

  @override
  void close() {
    _closed = true;
    for (final request in _requests) {
      request.abort();
    }
    _requests.clear();
  }
}

@JS()
extension type _Headers._(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}
