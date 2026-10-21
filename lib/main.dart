import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web/web.dart' as web;

import 'api.dart';
import 'brand.dart';
import 'browser_link_input.dart';
import 'link_input_cubit.dart';
import 'probe_cubit.dart';

void main() => runApp(
  MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => ProbeCubit()),
      BlocProvider(create: (_) => LinkInputCubit()),
    ],
    child: const DownloaderApp(),
  ),
);

class DownloaderApp extends StatelessWidget {
  const DownloaderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Downloader · Видео по ссылке',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'Nunito Sans',
      colorScheme: const ColorScheme.dark(
        primary: coral,
        onPrimary: background,
        surface: surface,
        onSurface: ink,
        outline: line,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyMedium: TextStyle(fontSize: 15, height: 1.6, color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Nunito Sans',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: background),
      ),
    ),
    home: const DownloadPage(),
  );
}

void saveFile(ProbeState state) {
  final blob = web.Blob([state.file!.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  startFileDownload(Uri.parse(url), state.filename);
  Future<void>.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
}

void startFileDownload(Uri url, String filename) {
  final anchor = web.HTMLAnchorElement()
    ..href = url.toString()
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});
  @override
  Widget build(BuildContext context) => BlocListener<ProbeCubit, ProbeState>(
    listenWhen: (before, after) =>
        (after.file != null && !identical(before.file, after.file)) ||
        (after.attachmentUrl != null &&
            before.attachmentUrl != after.attachmentUrl),
    listener: (_, state) {
      if (state.attachmentUrl != null) {
        startFileDownload(state.attachmentUrl!, state.filename);
      } else {
        saveFile(state);
      }
    },
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final mobile = box.maxWidth < 640;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 22 : 48,
                      mobile ? 24 : 36,
                      mobile ? 22 : 48,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Header(),
                        SizedBox(height: mobile ? 48 : 76),
                        _Hero(mobile: mobile),
                        SizedBox(height: mobile ? 32 : 42),
                        const _LinkForm(),
                        const SizedBox(height: 24),
                        const _Result(),
                        SizedBox(height: mobile ? 36 : 52),
                        _Steps(mobile: mobile),
                        SizedBox(height: mobile ? 36 : 48),
                        const _Footer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const BrandMark(size: 39),
      const SizedBox(width: 12),
      const Text(
        'downloader',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 25,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -1,
        ),
      ),
      const Spacer(),
      const _Mono('БЕЗ ЛИШНЕГО', size: 9),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.mobile});
  final bool mobile;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: coral),
                  child: SizedBox(width: 6, height: 6),
                ),
                SizedBox(width: 10),
                _Mono('YOUTUBE + TWITTER / X', size: 10),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Хочется сохранить?\nПросто вставьте ссылку.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: mobile ? 35 : 52,
                height: 1.13,
                fontWeight: FontWeight.w800,
                letterSpacing: mobile ? -1.3 : -2.1,
                color: ink,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Любимые видео — под рукой.\nВыберите качество и скачайте на своё устройство.',
            ),
          ],
        ),
      ),
      if (!mobile) ...[const SizedBox(width: 28), const VideoDrawing()],
    ],
  );
}

class _LinkForm extends StatefulWidget {
  const _LinkForm();
  @override
  State<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends State<_LinkForm> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void changed(String value) {
    context.read<LinkInputCubit>().changed(value);
    context.read<ProbeCubit>().reset();
  }

  Future<void> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || context.read<ProbeCubit>().state.busy) return;
      final text = data?.text;
      if (text == null || text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В буфере нет текста. Скопируйте ссылку на видео.'),
          ),
        );
        return;
      }
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      changed(controller.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вставьте ссылку через меню поля или Ctrl+V.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ProbeCubit, ProbeState>(
    buildWhen: (a, b) => a.busy != b.busy,
    builder: (context, state) => Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Mono('ССЫЛКА НА ВИДЕО', size: 10),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final input = InputDecorator(
                decoration: InputDecoration(
                  hintText: 'Вставьте ссылку сюда',
                  hintStyle: const TextStyle(color: muted),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: SoftIcon(Glyph.link, size: 20, color: muted),
                  ),
                  filled: true,
                  fillColor: background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: const BorderSide(color: line),
                  ),
                ),
                child: BrowserLinkInput(
                  controller: controller,
                  enabled: !state.busy,
                  onChanged: changed,
                  onSubmitted: () =>
                      context.read<ProbeCubit>().inspectAuto(controller.text),
                ),
              );
              final actions = _actions(state, box.maxWidth >= 300);
              if (box.maxWidth < 570) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [input, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 12),
                  SizedBox(width: 284, height: 58, child: actions),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          BlocBuilder<LinkInputCubit, String>(
            builder: (context, value) {
              final service = context.read<LinkInputCubit>().service;
              final label = switch (service) {
                VideoService.youtube =>
                  'YouTube определён · найдём доступное качество',
                VideoService.twitter =>
                  'Twitter / X определён · найдём доступное качество',
                null => 'YouTube, Shorts и Twitter / X. Сервис определим сами.',
              };
              return AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Align(
                  key: ValueKey(service),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _actions(ProbeState state, bool icons) => Row(
    children: [
      Expanded(
        child: FilledButton(
          onPressed: state.busy ? null : paste,
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: background,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Вставить'),
              if (icons) ...[
                const SizedBox(width: 8),
                const Icon(Icons.content_paste_rounded, size: 18),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: state.busy
              ? null
              : () => context.read<ProbeCubit>().inspectAuto(controller.text),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Скачать'),
              if (icons) ...[
                const SizedBox(width: 8),
                const SoftIcon(Glyph.download, color: background, size: 18),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _Result extends StatelessWidget {
  const _Result();
  @override
  Widget build(BuildContext context) => BlocBuilder<ProbeCubit, ProbeState>(
    builder: (context, state) {
      final visible =
          state.busy ||
          state.log.isNotEmpty ||
          state.message != 'Готово к проверке';
      return AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: visible
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.busy) _Progress(state: state),
                  if (!state.busy && state.links.isEmpty)
                    _Notice(state.message),
                  if (state.attachmentUrl != null || state.downloadFailed)
                    _Notice(
                      state.message,
                      success: state.attachmentUrl != null,
                    ),
                  if (state.file != null) ...[
                    const _Notice(
                      'Готово. Файл передан браузеру для сохранения.',
                      success: true,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => saveFile(state),
                        icon: const SoftIcon(Glyph.download, size: 18),
                        label: const Text('Сохранить ещё раз'),
                      ),
                    ),
                  ],
                  if (state.links.isNotEmpty) ...[
                    if (state.links.any((link) => link.sourceUrl != null)) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Выберите подходящее разрешение и размер файла.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Выберите качество',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _Mono(
                          '${state.links.length.toString().padLeft(2, '0')} ВАРИАНТОВ',
                          size: 9,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Размер файла приблизительный, если он указан со знаком ≈.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, box) {
                        final columns = box.maxWidth < 570 ? 1 : 3;
                        final width =
                            (box.maxWidth - (columns - 1) * 12) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final link in state.links)
                              SizedBox(
                                width: width,
                                child: _FormatCard(
                                  link: link,
                                  busy: state.busy,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              )
            : const SizedBox.shrink(),
      );
    },
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final ProbeState state;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(state.message, style: const TextStyle(color: ink)),
            ),
            TextButton(
              onPressed: context.read<ProbeCubit>().cancel,
              child: const Text('Отменить'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          minHeight: 2,
          color: coral,
          backgroundColor: line,
        ),
        if (state.bytes > 0) ...[
          const SizedBox(height: 12),
          _Mono(
            '${(state.bytes / 1048576).toStringAsFixed(1)} МИБ ПОЛУЧЕНО',
            size: 10,
          ),
        ],
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.success = false});
  final String text;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (success)
          const SoftIcon(Glyph.check, color: coral)
        else
          const Icon(Icons.info_outline_rounded, color: coral, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: ink)),
        ),
      ],
    ),
  );
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.link, required this.busy});
  final MediaLink link;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          link.label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _Mono(link.details.toUpperCase(), size: 10),
        const SizedBox(height: 8),
        Text(
          link.estimatedBytes == null
              ? 'Размер не указан источником'
              : '≈ ${(link.estimatedBytes! / 1048576).toStringAsFixed(1)} МиБ',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: busy
              ? null
              : () => context.read<ProbeCubit>().download(link),
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: background,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Скачать'),
              SizedBox(width: 10),
              SoftIcon(Glyph.download, color: background, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => web.window.open(
                  link.url.toString(),
                  '_blank',
                  'noopener,noreferrer',
                ),
          child: const Text(
            'Открыть напрямую',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    ),
  );
}

class _Steps extends StatelessWidget {
  const _Steps({required this.mobile});
  final bool mobile;
  @override
  Widget build(BuildContext context) {
    final steps = [
      _Step(
        compact: mobile,
        number: '01',
        glyph: Glyph.link,
        title: 'Вставьте ссылку',
        body: 'Скопируйте ссылку на видео\nиз YouTube или Twitter / X.',
      ),
      _Step(
        compact: mobile,
        number: '02',
        glyph: Glyph.play,
        title: 'Выберите качество',
        body: 'Покажем доступные варианты.\nВы решаете, какой сохранить.',
      ),
      _Step(
        compact: mobile,
        number: '03',
        glyph: Glyph.download,
        title: 'Заберите с собой',
        body: 'Скачайте файл на устройство\nи смотрите, когда удобно.',
      ),
    ];
    if (mobile) {
      return Column(
        children: [
          for (final step in steps) ...[step, const SizedBox(height: 12)],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 18),
            Expanded(child: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    this.compact = false,
    required this.number,
    required this.glyph,
    required this.title,
    required this.body,
  });
  final String number, title, body;
  final Glyph glyph;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      border: Border.all(color: line.withValues(alpha: .75)),
      borderRadius: BorderRadius.circular(2),
    ),
    child: compact
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftIcon(glyph, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body.replaceAll('\n', ' '),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Mono(number, size: 9),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SoftIcon(glyph, size: 28, color: ink),
                  const Spacer(),
                  _Mono(number, size: 10),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 20,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(fontSize: 12, height: 1.7, color: muted),
              ),
            ],
          ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(color: line),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 24,
        runSpacing: 12,
        children: const [
          Text(
            'Без регистрации. Без лишних действий.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          _Mono('ССЫЛКА → ВИДЕО → ГОТОВО', size: 9),
        ],
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          link: true,
          child: TextButton.icon(
            onPressed: () => web.window.open(
              'https://github.com/Hecatoncheir/downloader-web',
              '_blank',
              'noopener,noreferrer',
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Код на GitHub'),
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Ссылку обработает сторонний сервис. Доступность видео зависит от источника. Сохраняйте материалы, на скачивание которых у вас есть право.',
        style: TextStyle(fontSize: 11, color: muted, height: 1.6),
      ),
    ],
  );
}

class _Mono extends StatelessWidget {
  const _Mono(this.text, {this.size = 11});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: size,
      letterSpacing: .6,
      color: muted,
    ),
  );
}
