import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';

/// The 3.7 "booking confirmed" hero moment — the app's single budget-spend of
/// drama. Runs once, ~1100ms, never blocking:
///
///   0ms    the check STROKE DRAWS (180ms) — it is not faded in.
///   120ms  a semantic-green (#34C759) radial bloom settles behind the check to
///          18% on [Motion.bounce] (the system's ONE overshoot).
///   ~250ms mediumImpact haptic fires exactly at the bloom peak (haptic + visual
///          peak alignment is what makes it feel physical).
///   300ms  [onRevealContent] fires so the host can rise + cascade the booking
///          summary and secondary actions (kept in the screen, not here).
///   1100ms [onComplete] fires.
///
/// No confetti, no full-screen takeover — the restraint IS the brand. Under
/// reduced motion the check shows instantly, the bloom and haptic are skipped,
/// and both callbacks fire immediately (responsive, not autonomous).
class BookingConfirmedSeal extends StatefulWidget {
  final double size;

  /// Fired ~300ms in — host rises + cascades the summary card + actions.
  final VoidCallback? onRevealContent;

  /// Fired when the whole sequence settles (~1100ms).
  final VoidCallback? onComplete;

  const BookingConfirmedSeal({
    super.key,
    this.size = 96,
    this.onRevealContent,
    this.onComplete,
  });

  @override
  State<BookingConfirmedSeal> createState() => _BookingConfirmedSealState();
}

class _BookingConfirmedSealState extends State<BookingConfirmedSeal>
    with TickerProviderStateMixin {
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final AnimationController _bloom =
      AnimationController.unbounded(vsync: this, value: 0);
  final List<Timer> _timers = [];
  bool _started = false;
  bool _hapticFired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return; // run the sequence exactly once
    _started = true;
    _bloom.addListener(_onBloomTick);
    _run(reduced: Motion.reduced(context));
  }

  // mediumImpact exactly at the bloom's first peak (physical alignment).
  void _onBloomTick() {
    if (!_hapticFired && _bloom.value >= 0.9) {
      _hapticFired = true;
      Feel.confirm.go();
    }
  }

  void _after(int ms, VoidCallback fn) {
    _timers.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) fn();
    }));
  }

  void _run({required bool reduced}) {
    if (reduced) {
      _draw.value = 1.0; // check present, no draw; bloom + haptic skipped
      widget.onRevealContent?.call();
      widget.onComplete?.call();
      return;
    }
    _draw.forward(); // stroke draws over 180ms
    _after(120, () => Motion.spring(_bloom, Motion.bounce, target: 1.0));
    _after(300, () => widget.onRevealContent?.call());
    _after(1100, () => widget.onComplete?.call());
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _bloom.removeListener(_onBloomTick);
    _draw.dispose();
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Green radial bloom (settles to 18%), isolated for cheap repaints.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bloom,
              builder: (_, _) {
                final v = _bloom.value.clamp(0.0, 1.3);
                return Opacity(
                  opacity: (0.18 * v).clamp(0.0, 0.18),
                  child: Transform.scale(
                    scale: 0.5 + 1.1 * v,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.successGreen,
                            AppColors.successGreen.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // The check, drawn stroke-by-stroke.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _draw,
              builder: (_, _) => CustomPaint(
                size: Size.square(s * 0.7),
                painter: _CheckPainter(_draw.value, AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress; // 0..1 fraction of the stroke drawn
  final Color color;

  _CheckPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.14, h * 0.54)
      ..lineTo(w * 0.40, h * 0.78)
      ..lineTo(w * 0.86, h * 0.24);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
