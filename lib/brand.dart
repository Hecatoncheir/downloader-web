import 'package:flutter/material.dart';

const ink = Color(0xffd9d4bd);
const muted = Color(0xffa39b8b);
const background = Color(0xff191410);
const surface = Color(0xff211b17);
const line = Color(0xff443a31);
const coral = Color(0xfff29370);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Downloader',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: const _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final blob = Path()
      ..moveTo(18, 5)
      ..cubicTo(4, 7, 5, 28, 6, 43)
      ..cubicTo(7, 59, 16, 63, 33, 59)
      ..cubicTo(52, 55, 62, 47, 58, 29)
      ..cubicTo(55, 12, 38, 1, 18, 5)
      ..close();
    canvas.drawPath(blob, Paint()..color = ink);
    final arrow = Path()
      ..moveTo(31, 17)
      ..cubicTo(30, 23, 29, 32, 30, 41)
      ..moveTo(20, 32)
      ..quadraticBezierTo(24, 39, 30, 44)
      ..quadraticBezierTo(37, 39, 43, 30);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

enum Glyph { link, download, play, check }

class SoftIcon extends StatelessWidget {
  const SoftIcon(this.glyph, {super.key, this.size = 22, this.color = ink});
  final Glyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);
  final Glyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (glyph) {
      case Glyph.download:
        path
          ..moveTo(12, 3)
          ..lineTo(12, 15)
          ..moveTo(7, 10)
          ..quadraticBezierTo(9, 13, 12, 16)
          ..quadraticBezierTo(15, 13, 17, 10)
          ..moveTo(4, 17)
          ..lineTo(4, 19)
          ..quadraticBezierTo(4, 21, 7, 21)
          ..lineTo(17, 21)
          ..quadraticBezierTo(20, 21, 20, 19)
          ..lineTo(20, 17);
      case Glyph.link:
        path
          ..moveTo(9, 8)
          ..lineTo(12, 5)
          ..cubicTo(18, -1, 26, 7, 20, 13)
          ..lineTo(17, 16)
          ..moveTo(7, 8)
          ..lineTo(4, 11)
          ..cubicTo(-2, 17, 6, 25, 12, 19)
          ..lineTo(15, 16)
          ..moveTo(8, 16)
          ..lineTo(16, 8);
      case Glyph.play:
        path
          ..moveTo(8, 4)
          ..quadraticBezierTo(7, 3, 7, 6)
          ..lineTo(7, 18)
          ..quadraticBezierTo(7, 21, 10, 19)
          ..lineTo(19, 13)
          ..quadraticBezierTo(21, 12, 18, 10)
          ..close();
      case Glyph.check:
        path
          ..moveTo(5, 12)
          ..quadraticBezierTo(8, 15, 10, 18)
          ..quadraticBezierTo(14, 12, 20, 6);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.glyph != glyph;
}

class VideoDrawing extends StatelessWidget {
  const VideoDrawing({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: const Size(220, 170), painter: _VideoPainter()),
  );
}

class _VideoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = line.withValues(alpha: .65);
    for (double x = 0; x < size.width; x += 10) {
      for (double y = 0; y < size.height; y += 10) {
        canvas.drawCircle(Offset(x, y), .65, grid);
      }
    }
    final pen = Paint()
      ..color = ink.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(35, 46)
      ..lineTo(150, 25)
      ..lineTo(190, 53)
      ..lineTo(75, 76)
      ..close()
      ..lineTo(75, 140)
      ..lineTo(190, 117)
      ..lineTo(190, 53)
      ..moveTo(35, 46)
      ..lineTo(35, 110)
      ..lineTo(75, 140)
      ..moveTo(75, 88)
      ..lineTo(190, 65);
    canvas.drawPath(path, pen);
    final play = Path()
      ..moveTo(118, 84)
      ..lineTo(118, 111)
      ..lineTo(141, 93)
      ..close();
    canvas.drawPath(play, pen);
    canvas.drawRect(const Rect.fromLTWH(12, 12, 5, 5), Paint()..color = coral);
  }

  @override
  bool shouldRepaint(_VideoPainter oldDelegate) => false;
}
