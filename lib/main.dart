import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web/web.dart' as web;

import 'api.dart';
import 'probe_cubit.dart';

void main() => runApp(
  BlocProvider(create: (_) => ProbeCubit(), child: const DownloaderApp()),
);

class DownloaderApp extends StatelessWidget {
  const DownloaderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Downloader · Проверка API',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xff9ce4c2),
      scaffoldBackgroundColor: const Color(0xff111815),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const ProbePage(),
  );
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  final _url = TextEditingController();
  final _endpoint = TextEditingController(
    text: 'https://rue-cobalt.xenon.zone/',
  );
  String _provider = 'cobalt', _quality = '360';
  static const gap = SizedBox(height: 16);
  @override
  void dispose() {
    _url.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: BlocBuilder<ProbeCubit, ProbeState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'DOWNLOADER / ЛАБОРАТОРИЯ',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xff9ce4c2),
                    letterSpacing: 2,
                  ),
                ),
                gap,
                Text(
                  'Проверим скачивание',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Twitter/X и YouTube · прямые запросы из вашего браузера · без ключей',
                ),
                const SizedBox(height: 24),
                _card(_form(context, state)),
                gap,
                _card([
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (state.busy) ...[gap, const LinearProgressIndicator()],
                  if (state.bytes > 0) ...[
                    gap,
                    Text(
                      'Получено: ${(state.bytes / 1024 / 1024).toStringAsFixed(2)} МиБ',
                    ),
                  ],
                  if (state.file != null) ...[
                    gap,
                    FilledButton.icon(
                      onPressed: () => _save(state),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Сохранить файл'),
                    ),
                  ],
                  if (state.links.isNotEmpty) ...[
                    gap,
                    const Text(
                      '«Открыть напрямую» передаёт ссылку браузеру. «Проверить загрузку» получает файл через CORS и показывает фактический объём.',
                    ),
                  ],
                  for (final link in state.links) ...[
                    gap,
                    _media(context, link, state.busy),
                  ],
                ]),
                gap,
                _card([
                  Row(
                    children: [
                      const Expanded(child: Text('Журнал проверки')),
                      IconButton(
                        tooltip: 'Скопировать журнал',
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: state.log)),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    state.log.isEmpty
                        ? 'Здесь появятся HTTP-статусы, ответы API и ошибки.'
                        : state.log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ]),
                gap,
                const Text(
                  'Ссылка на ролик передаётся выбранному стороннему сервису. API могут быть недоступны. Журнал может содержать временные ссылки доступа — проверьте его перед отправкой. Проверка файла: до 200 МиБ и 120 секунд. Звук и воспроизведение проверяйте самостоятельно.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  List<Widget> _form(BuildContext context, ProbeState state) => [
    TextField(
      controller: _url,
      enabled: !state.busy,
      decoration: const InputDecoration(
        labelText: 'Ссылка на видео',
        hintText: 'https://www.youtube.com/watch?v=…',
      ),
      keyboardType: TextInputType.url,
    ),
    gap,
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: state.busy
              ? null
              : () {
                  setState(() => _provider = 'cobalt');
                  _url.text = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
                },
          child: const Text('Пример YouTube'),
        ),
        OutlinedButton(
          onPressed: state.busy
              ? null
              : () {
                  setState(() => _provider = 'fx');
                  _url.text =
                      'https://x.com/CTVJLaidlaw/status/1600649710662213632';
                },
          child: const Text('Пример Twitter'),
        ),
      ],
    ),
    gap,
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _provider,
      key: ValueKey(_provider),
      decoration: const InputDecoration(labelText: 'Сервис'),
      items: const [
        DropdownMenuItem(
          value: 'cobalt',
          child: Text('Cobalt · YouTube / Twitter'),
        ),
        DropdownMenuItem(
          value: 'fx',
          child: Text('FxEmbed · только Twitter/X'),
        ),
      ],
      onChanged: state.busy
          ? null
          : (value) => setState(() => _provider = value!),
    ),
    if (_provider == 'cobalt') ...[
      gap,
      TextField(
        controller: _endpoint,
        enabled: !state.busy,
        decoration: const InputDecoration(
          labelText: 'Адрес API Cobalt (можно изменить)',
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final host in ['rue-cobalt.xenon.zone', 'cobaltapi.cjs.nz'])
            ActionChip(
              label: Text(host),
              onPressed: state.busy
                  ? null
                  : () => _endpoint.text = 'https://$host/',
            ),
        ],
      ),
      gap,
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _quality,
        decoration: const InputDecoration(labelText: 'Желаемое качество'),
        items: [
          for (final quality in ['144', '360', '720', '1080'])
            DropdownMenuItem(value: quality, child: Text('${quality}p')),
        ],
        onChanged: state.busy
            ? null
            : (value) => setState(() => _quality = value!),
      ),
    ],
    gap,
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: state.busy
              ? null
              : () => context.read<ProbeCubit>().inspect(
                  _url.text,
                  _endpoint.text,
                  _provider == 'fx',
                  _quality,
                ),
          icon: const Icon(Icons.search),
          label: const Text('Получить ссылки'),
        ),
        if (state.busy)
          OutlinedButton(
            onPressed: context.read<ProbeCubit>().cancel,
            child: const Text('Отменить'),
          ),
      ],
    ),
  ];
  Widget _card(List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget _media(BuildContext context, MediaLink link, bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(link.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: busy
                ? null
                : () => context.read<ProbeCubit>().download(link),
            child: const Text('Проверить загрузку'),
          ),
          OutlinedButton(
            onPressed: () => web.window.open(
              link.url.toString(),
              '_blank',
              'noopener,noreferrer',
            ),
            child: const Text('Открыть напрямую'),
          ),
          IconButton(
            tooltip: 'Скопировать ссылку',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: link.url.toString())),
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    ],
  );
  void _save(ProbeState state) {
    final blob = web.Blob([state.file!.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = state.filename;
    anchor.click();
    Future<void>.delayed(
      const Duration(minutes: 1),
      () => web.URL.revokeObjectURL(url),
    );
  }
}
