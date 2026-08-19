import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class StatisticsChart extends StatelessWidget {
  const StatisticsChart({
    super.key,
    required this.values,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<double> values;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(values.join(',')),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (_, progress, _) => GestureDetector(
      onTapDown: (d) => _select(d.localPosition.dx, context),
      onHorizontalDragUpdate: (d) => _select(d.localPosition.dx, context),
      child: CustomPaint(
        size: const Size(double.infinity, 180),
        painter: _StatisticsChartPainter(
          values,
          selectedIndex,
          progress,
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    ),
  );

  void _select(double x, BuildContext context) {
    if (values.isEmpty) return;
    final width = context.size?.width ?? 1;
    onSelected(
      (x / width * (values.length - 1)).round().clamp(0, values.length - 1),
    );
  }
}

class _StatisticsChartPainter extends CustomPainter {
  _StatisticsChartPainter(this.values, this.selected, this.progress, this.dark);
  final List<double> values;
  final int selected;
  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final grid = Paint()
      ..color = dark ? Colors.white10 : const Color(0xFFEDEFF5);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    final maxValue = math.max(values.fold<double>(0, math.max), 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - 16 - (values[i] / maxValue) * (size.height - 36);
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      path.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: .14),
            AppTheme.primary.withValues(alpha: .01),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    if (selected < points.length && progress >= .95) {
      canvas.drawCircle(
        points[selected],
        8,
        Paint()..color = dark ? AppTheme.darkBackground : Colors.white,
      );
      canvas.drawCircle(
        points[selected],
        7,
        Paint()
          ..color = AppTheme.primary
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StatisticsChartPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.values != values ||
      old.dark != dark;
}
