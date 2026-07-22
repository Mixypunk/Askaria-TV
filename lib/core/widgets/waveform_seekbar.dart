import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaveformSeekbar extends StatefulWidget {
  final List<double>? peaks;
  final double progress;
  final Color accentColor;
  final double height;
  final void Function(int deltaSeconds) onSeekDelta;

  const WaveformSeekbar({
    super.key,
    required this.peaks,
    required this.progress,
    required this.accentColor,
    required this.onSeekDelta,
    this.height = 40.0,
  });

  @override
  State<WaveformSeekbar> createState() => _WaveformSeekbarState();
}

class _WaveformSeekbarState extends State<WaveformSeekbar> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onSeekDelta(5);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onSeekDelta(-5);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.height + (_hasFocus ? 10 : 0),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: _hasFocus
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.peaks == null || widget.peaks!.isEmpty
            ? Center(
                child: LinearProgressIndicator(
                  value: widget.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.white30,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                ),
              )
            : CustomPaint(
                painter: _WaveformPainter(
                  peaks: widget.peaks!,
                  progress: widget.progress.clamp(0.0, 1.0),
                  accentColor: widget.accentColor,
                  unplayedColor: Colors.white30,
                ),
                size: Size.infinite,
              ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double progress;
  final Color accentColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.accentColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final paintPlayed = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final paintUnplayed = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final int barCount = peaks.length;
    final double spacing = 2.0;
    final double barWidth = (size.width - (spacing * (barCount - 1))) / barCount;

    final int splitIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      final double peak = peaks[i].clamp(0.0, 1.0);
      final double barHeight = (peak * size.height).clamp(2.0, size.height);
      final double x = i * (barWidth + spacing);
      final double y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, i < splitIndex ? paintPlayed : paintUnplayed);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.peaks != peaks;
  }
}
