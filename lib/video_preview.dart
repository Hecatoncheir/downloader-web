import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

String videoMimeType(String filename) =>
    filename.toLowerCase().endsWith('.webm') ? 'video/webm' : 'video/mp4';

class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final String _url = web.URL.createObjectURL(
    web.Blob(
      [widget.bytes.toJS].toJS,
      web.BlobPropertyBag(type: videoMimeType(widget.filename)),
    ),
  );
  web.HTMLVideoElement? _video;

  @override
  void dispose() {
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    web.URL.revokeObjectURL(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: HtmlElementView.fromTagName(
      tagName: 'video',
      onElementCreated: (element) {
        final video = element as web.HTMLVideoElement;
        _video = video;
        video
          ..src = _url
          ..controls = true
          ..preload = 'metadata'
          ..setAttribute('playsinline', '')
          ..setAttribute('aria-label', 'Предпросмотр подготовленного видео')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000'
          ..style.borderRadius = '8px';
      },
    ),
  );
}
