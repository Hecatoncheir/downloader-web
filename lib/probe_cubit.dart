import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'api.dart';

class ProbeState {
  const ProbeState({
    this.busy = false,
    this.message = 'Готово к проверке',
    this.log = '',
    this.links = const [],
    this.bytes = 0,
    this.file,
    this.filename = 'video.mp4',
  });
  final bool busy;
  final String message, log, filename;
  final List<MediaLink> links;
  final int bytes;
  final Uint8List? file;
}

class ProbeCubit extends Cubit<ProbeState> {
  ProbeCubit() : super(const ProbeState());
  http.Client? _client;
  int _generation = 0;
  void cancel() {
    _generation++;
    _client?.close();
    _client = null;
    emit(
      ProbeState(message: 'Запрос отменён', log: state.log, links: state.links),
    );
  }

  Future<void> inspect(
    String input,
    String endpoint,
    bool fx,
    String quality,
  ) async {
    final generation = ++_generation;
    final client = http.Client();
    _client?.close();
    _client = client;
    var log = '';
    try {
      final source = httpsUri(input);
      final target = fx ? twitterApi(input) : httpsUri(endpoint);
      log =
          '${DateTime.now().toIso8601String()}\n${fx ? 'GET' : 'POST'} $target\nИсточник: $source\n';
      emit(ProbeState(busy: true, message: 'Запрос к API…', log: log));
      final response = await _request(
        client,
        target,
        source,
        fx,
        quality,
      ).timeout(const Duration(seconds: 40));
      log += 'HTTP ${response.statusCode}\n${response.body}\n';
      if (generation != _generation) return;
      if (response.statusCode != 200) {
        throw FormatException('API: HTTP ${response.statusCode}');
      }
      final links = parseLinks(response.body, fx);
      emit(
        ProbeState(
          message: links.isEmpty
              ? 'В ответе нет файлов'
              : 'Ссылки получены. Скачивание ещё не проверено.',
          log: log,
          links: links,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        emit(ProbeState(message: _error(error), log: '$log\n$error'));
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<http.Response> _request(
    http.Client client,
    Uri target,
    Uri source,
    bool fx,
    String quality,
  ) {
    if (fx) return client.get(target);
    return client.post(
      target,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': source.toString(), 'videoQuality': quality}),
    );
  }

  Future<void> download(MediaLink link) async {
    final generation = ++_generation;
    final client = http.Client();
    _client?.close();
    _client = client;
    final previous = state;
    final log = '${previous.log}\nGET ${link.url}\n';
    emit(
      ProbeState(
        busy: true,
        message: 'Получение файла…',
        log: log,
        links: previous.links,
      ),
    );
    try {
      final bytes = await _read(
        client,
        link.url,
        generation,
        previous.links,
        log,
      ).timeout(const Duration(seconds: 120));
      if (generation != _generation) return;
      emit(
        ProbeState(
          message: 'Файл получен целиком. Нажмите «Сохранить файл».',
          log:
              '${state.log}\nПолучено ${bytes.length} байт. Звук не проверялся.\n',
          links: previous.links,
          bytes: bytes.length,
          file: bytes,
          filename: link.filename,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        emit(
          ProbeState(
            message: _error(error),
            log: '${state.log}\n$error',
            links: previous.links,
            bytes: state.bytes,
          ),
        );
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<Uint8List> _read(
    http.Client client,
    Uri url,
    int generation,
    List<MediaLink> links,
    String log,
  ) async {
    final response = await client.send(http.Request('GET', url));
    log +=
        'HTTP ${response.statusCode} · ${response.headers['content-type'] ?? 'тип не указан'}\n';
    if (response.statusCode != 200) {
      throw FormatException('Файл: HTTP ${response.statusCode}');
    }
    final type = response.headers['content-type'] ?? '';
    if (type.contains('text/html') || type.contains('application/json')) {
      throw const FormatException(
        'Вместо медиафайла сервер вернул HTML или JSON.',
      );
    }
    final builder = BytesBuilder(copy: false);
    final clock = Stopwatch()..start();
    await for (final chunk in response.stream) {
      if (generation != _generation) throw const FormatException('Отменено');
      builder.add(chunk);
      if (builder.length > 200 * 1024 * 1024) {
        throw const FormatException('Превышен тестовый лимит 200 МиБ.');
      }
      if (clock.elapsedMilliseconds < 200) continue;
      clock.reset();
      emit(
        ProbeState(
          busy: true,
          message: 'Получение файла…',
          log: log,
          links: links,
          bytes: builder.length,
        ),
      );
    }
    if (builder.isEmpty) {
      throw const FormatException('Сервер вернул пустой файл.');
    }
    final expected = response.contentLength;
    if (expected != null && builder.length != expected) {
      throw const FormatException('Файл получен не полностью.');
    }
    return builder.takeBytes();
  }

  String _error(Object error) {
    if (error is TimeoutException) {
      return 'Истекло время ожидания. Попробуйте другой API или сеть.';
    }
    if (error is http.ClientException) {
      return 'Ответ недоступен: возможны CORS, блокировка сети или недоступность сервера. Подробности — в консоли браузера.';
    }
    return error.toString();
  }

  @override
  Future<void> close() {
    _generation++;
    _client?.close();
    return super.close();
  }
}
