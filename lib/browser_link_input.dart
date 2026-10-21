import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Нативное поле сохраняет стандартную вставку браузера без чтения Clipboard API.
class BrowserLinkInput extends StatefulWidget {
  const BrowserLinkInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<BrowserLinkInput> createState() => _BrowserLinkInputState();
}

class _BrowserLinkInputState extends State<BrowserLinkInput> {
  web.HTMLInputElement? _input;
  final _subscriptions = <StreamSubscription<web.Event>>[];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(BrowserLinkInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _sync();
  }

  void _created(Object element) {
    final input = element as web.HTMLInputElement;
    _input = input;
    input
      ..type = 'text'
      ..inputMode = 'url'
      ..placeholder = 'Вставьте ссылку сюда'
      ..autocomplete = 'off'
      ..spellcheck = false
      ..setAttribute('aria-label', 'Ссылка на видео')
      ..setAttribute('enterkeyhint', 'go');
    input.style.cssText =
        'width:100%;height:100%;box-sizing:border-box;'
        'border:0;outline:0;background:transparent;color:#d9d4bd;'
        'font:16px "Downloader Input",sans-serif;padding:0;margin:0;'
        'caret-color:#f29370;';
    _subscriptions.add(input.onInput.listen((_) => _edited()));
    _subscriptions.add(
      input.onKeyDown.listen((event) {
        event.stopPropagation();
        if (event.key != 'Enter' || !widget.enabled || event.isComposing) {
          return;
        }
        event.preventDefault();
        widget.onSubmitted();
      }),
    );
    _sync();
  }

  void _edited() {
    final input = _input!;
    widget.controller.value = TextEditingValue(
      text: input.value,
      selection: TextSelection(
        baseOffset: input.selectionStart ?? input.value.length,
        extentOffset: input.selectionEnd ?? input.value.length,
      ),
    );
    widget.onChanged(input.value);
  }

  void _sync() {
    final input = _input;
    if (input == null) return;
    input.disabled = !widget.enabled;
    if (input.value == widget.controller.text) return;
    input.value = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    input.setSelectionRange(selection.start, selection.end);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: HtmlElementView.fromTagName(
      tagName: 'input',
      onElementCreated: _created,
    ),
  );

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
