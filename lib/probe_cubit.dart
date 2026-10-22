import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'transport_client.dart';

class ProbeState {
  const ProbeState({
    this.busy = false,
    this.message = 'Готово к проверке',
    this.log = '',
    this.links = const [],
    this.bytes = 0,
    this.file,
    this.filename = 'video.mp4',
    this.attachmentUrl,
    this.downloadFailed = false,
    this.fallbackUrl,
    this.shareFile,
    this.shareSourceUrl,
  });
  final bool busy;
  final String message, log, filename;
  final List<MediaLink> links;
  final int bytes;
  final Uint8List? file;
  final Uri? attachmentUrl;
  final bool downloadFailed;
  final Uri? fallbackUrl;
  final Uint8List? shareFile;
  final Uri? shareSourceUrl;
}

class ProbeCubit extends Cubit<ProbeState> {
  ProbeCubit({
    http.Client Function()? clientFactory,
    this.transferIdleTimeout = const Duration(seconds: 20),
  }) : _clientFactory = clientFactory ?? createTransportClient,
       super(const ProbeState());
  final http.Client Function() _clientFactory;
  final Duration transferIdleTimeout;
  http.Client? _client;
  int _generation = 0;
  Future<void> inspectAuto(String input) async {
    try {
      final service = detectService(input);
      if (service == VideoService.twitter) {
        await inspect(input, '', true, '720');
        return;
      }
      await _youtube(input);
    } catch (error) {
      emit(ProbeState(message: _error(error)));
    }
  }

  Future<void> _youtube(String input) async {
    final generation = ++_generation;
    final client = _clientFactory();
    _client?.close();
    _client = client;
    emit(const ProbeState(busy: true, message: 'Ищем доступное качество…'));
    try {
      final results = await Future.wait([
        for (final quality in ['360', '720', '1080'])
          _youtubeVariant(client, input, quality),
      ]).timeout(const Duration(seconds: 45));
      if (generation != _generation) return;
      final unique = <String, MediaLink>{};
      for (final result in results) {
        for (final link in result.links) {
          unique.putIfAbsent(link.filename, () => link);
        }
      }
      emit(
        ProbeState(
          message: unique.isEmpty
              ? 'Не удалось получить видео. Попробуйте ещё раз чуть позже.'
              : 'Выберите качество',
          links: unique.values.toList(),
          log: results.map((r) => r.log).join('\n'),
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        emit(ProbeState(message: _error(error), log: '$error'));
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<ProbeState> _youtubeVariant(
    http.Client client,
    String input,
    String quality,
  ) async {
    try {
      final response = await _request(
        client,
        Uri.https('rue-cobalt.xenon.zone', '/'),
        httpsUri(input),
        false,
        quality,
      ).timeout(const Duration(seconds: 35));
      final log = '$quality: HTTP ${response.statusCode}\n${response.body}\n';
      if (response.statusCode != 200) return ProbeState(log: log);
      return ProbeState(links: parseLinks(response.body, false), log: log);
    } catch (error) {
      return ProbeState(log: '$quality: $error\n');
    }
  }

  void reset() {
    if (!state.busy) emit(const ProbeState());
  }

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
    final client = _clientFactory();
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
      final links = fx
          ? twitterDownloadChoices(response.body, input)
          : parseLinks(response.body, false);
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
      body: jsonEncode({
        'url': source.toString(),
        'videoQuality': quality,
        'alwaysProxy': true,
      }),
    );
  }

  Future<void> download(MediaLink link, {bool forSharing = false}) async {
    var generation = ++_generation;
    final client = _clientFactory();
    _client?.close();
    _client = client;
    final previous = state;
    var log = '${previous.log}\nGET ${link.url}\n';
    emit(
      ProbeState(
        busy: true,
        message: forSharing
            ? 'Готовим ссылку на видео для отправки…'
            : 'Подготовка скачивания…',
        log: log,
        links: previous.links,
      ),
    );
    try {
      MediaLink? attachment;
      try {
        attachment = await _attachment(client, link);
      } catch (error) {
        if (generation != _generation) return;
        log += 'Подготовка туннеля: $error\nПолучаем файл напрямую.\n';
      }
      if (generation != _generation) return;
      Uint8List bytes;
      try {
        bytes = await _read(
          client,
          attachment?.url ?? link.url,
          generation,
          previous.links,
          log,
          refreshLink: link.sourceUrl == null ? null : link,
        ).timeout(const Duration(minutes: 5));
      } catch (error) {
        if (attachment == null ||
            attachment.url == link.url ||
            generation != _generation) {
          rethrow;
        }
        // Останавливаем предыдущую передачу перед запросом к источнику.
        generation = ++_generation;
        client.close();
        final directClient = _clientFactory();
        _client = directClient;
        try {
          bytes = await _read(
            directClient,
            link.url,
            generation,
            previous.links,
            '$log\nТуннель: $error\nПолучаем файл напрямую.\n',
          ).timeout(const Duration(minutes: 5));
        } finally {
          directClient.close();
          if (identical(_client, directClient)) _client = null;
        }
      }
      if (generation != _generation) return;
      if (forSharing) {
        emit(
          ProbeState(
            message:
                'Видео готово. Нажмите «Отправить» под выбранным вариантом.',
            links: previous.links,
            log: log,
            shareFile: bytes,
            shareSourceUrl: link.url,
            filename: attachment?.filename ?? link.filename,
          ),
        );
        return;
      }
      emit(
        ProbeState(
          message: 'Файл получен целиком. Нажмите «Сохранить файл».',
          log:
              '${state.log}\nПолучено ${bytes.length} байт. Звук не проверялся.\n',
          links: previous.links,
          bytes: bytes.length,
          file: bytes,
          filename: attachment?.filename ?? link.filename,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        _generation++;
        debugPrint('Ошибка получения видео: ${state.log}\n$error');
        emit(
          ProbeState(
            message: forSharing
                ? error is TimeoutException
                      ? 'Сервер видео перестал отвечать. Попробуйте ещё раз или выберите другое качество.'
                      : 'Не удалось получить видеофайл для отправки. Попробуйте другое качество или сеть.'
                : _error(error),
            log: '${state.log}\n$error',
            links: previous.links,
            bytes: state.bytes,
            downloadFailed: true,
          ),
        );
      }
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<MediaLink?> _attachment(http.Client client, MediaLink link) async {
    if (link.attachmentUrl != null) {
      return MediaLink(link.label, link.attachmentUrl!, link.filename);
    }
    final source = link.sourceUrl;
    if (source == null) return null;
    final response = await _request(
      client,
      Uri.https('rue-cobalt.xenon.zone', '/'),
      source,
      false,
      'max',
    ).timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) {
      throw const FormatException(
        'Не удалось подготовить скачивание. Попробуйте ещё раз позже.',
      );
    }
    final choices = parseLinks(response.body, false);
    if (choices.length != 1 || choices.single.attachmentUrl == null) {
      throw const FormatException(
        'Сервис не выдал ссылку для скачивания файла.',
      );
    }
    final choice = choices.single;
    return MediaLink(link.label, choice.attachmentUrl!, choice.filename);
  }

  Future<Uint8List> _read(
    http.Client client,
    Uri url,
    int generation,
    List<MediaLink> links,
    String log, {
    MediaLink? refreshLink,
  }) async {
    if (generation != _generation) throw const FormatException('Отменено');
    emit(
      ProbeState(
        busy: true,
        message: 'Получаем видеофайл…',
        links: links,
        log: log,
      ),
    );
    final response = await client
        .send(http.Request('GET', url))
        .timeout(transferIdleTimeout);
    if (generation != _generation) throw const FormatException('Отменено');
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
    try {
      await for (final chunk in response.stream.timeout(transferIdleTimeout)) {
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
    } on TimeoutException {
      final total = response.contentLength;
      if (generation != _generation ||
          total == null ||
          total <= builder.length ||
          total > 200 * 1024 * 1024) {
        rethrow;
      }
      client.close();
      return _readRemaining(
        url,
        builder,
        total,
        generation,
        links,
        log,
        refreshLink,
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

  Future<Uint8List> _readRemaining(
    Uri url,
    BytesBuilder builder,
    int total,
    int generation,
    List<MediaLink> links,
    String log,
    MediaLink? refreshLink,
  ) async {
    var refreshes = 0;
    while (builder.length < total) {
      if (generation != _generation) throw const FormatException('Отменено');
      final start = builder.length;
      final end = (start + 16383).clamp(0, total - 1);
      final request = http.Request('GET', url)
        ..headers['Range'] = 'bytes=$start-$end';
      final partClient = _clientFactory();
      _client = partClient;
      late Uint8List part;
      try {
        final response = await partClient
            .send(request)
            .timeout(transferIdleTimeout);
        if ((response.statusCode == 404 || response.statusCode == 410) &&
            refreshLink != null &&
            refreshes < 2) {
          final renewed = await _attachment(partClient, refreshLink);
          if (renewed == null) {
            throw const FormatException('Не удалось обновить ссылку на файл.');
          }
          url = renewed.url;
          refreshes++;
          continue;
        }
        if (response.statusCode == 429) {
          final seconds =
              int.tryParse(response.headers['retry-after'] ?? '') ??
              int.tryParse(response.headers['ratelimit-reset'] ?? '') ??
              60;
          emit(
            ProbeState(
              busy: true,
              message:
                  'Сервис ограничил частоту запросов. Продолжим через ${seconds.clamp(1, 60)} с…',
              bytes: builder.length,
              links: links,
              log: log,
            ),
          );
          partClient.close();
          await Future<void>.delayed(Duration(seconds: seconds.clamp(1, 60)));
          continue;
        }
        if (response.statusCode != 206) {
          throw FormatException('Дозагрузка: HTTP ${response.statusCode}.');
        }
        part = await response.stream.toBytes().timeout(transferIdleTimeout);
      } finally {
        partClient.close();
        if (identical(_client, partClient)) _client = null;
      }
      if (generation != _generation) throw const FormatException('Отменено');
      if (part.length != end - start + 1) {
        throw const FormatException('Часть видео получена не полностью.');
      }
      builder.add(part);
      emit(
        ProbeState(
          busy: true,
          message: 'Дозагружаем видео небольшими частями…',
          bytes: builder.length,
          links: links,
          log: log,
        ),
      );
    }
    return builder.takeBytes();
  }

  String _error(Object error) {
    if (error is TimeoutException) {
      return 'Истекло время ожидания. Попробуйте другой API или сеть.';
    }
    if (error is http.ClientException) {
      return 'Не удалось связаться с сервисом. Попробуйте ещё раз или откройте видео напрямую, если ссылка уже получена.';
    }
    if (error is FormatException) {
      if (error.message.startsWith('API:') ||
          error.message.startsWith('FxEmbed:')) {
        return 'Не удалось получить видео. Проверьте ссылку или попробуйте позже.';
      }
      if (error.message.startsWith('Файл: HTTP')) {
        return 'Не удалось скачать файл. Попробуйте открыть его напрямую.';
      }
      return error.message;
    }
    return 'Не удалось обработать видео. Попробуйте ещё раз чуть позже.';
  }

  @override
  Future<void> close() {
    _generation++;
    _client?.close();
    return super.close();
  }
}
