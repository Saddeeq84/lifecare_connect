// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

/// A reusable line chart widget for analytics dashboards
class AnalyticsLineChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color primaryColor;
  final double height;
  final String? yAxisLabel;
  final String? xAxisLabel;

  const AnalyticsLineChart({
    super.key,
    required this.data,
    required this.title,
    this.primaryColor = Colors.blue,
    this.height = 200,
    this.yAxisLabel,
    this.xAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? _buildEmptyState()
                : CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: LineChartPainter(
                      data: data,
                      primaryColor: primaryColor,
                    ),
                  ),
          ),
          if (xAxisLabel != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                xAxisLabel!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color primaryColor;

  LineChartPainter({required this.data, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw grid lines
    _drawGrid(canvas, size, gridPaint);

    // Calculate bounds
    final minY = data.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    // Draw line
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i].y - minY) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw data points
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, paint);

    // Draw area under curve
    final areaPaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final areaPath = Path()..addPath(path, Offset.zero);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    canvas.drawPath(areaPath, areaPaint);
  }

  void _drawGrid(Canvas canvas, Size size, Paint paint) {
    // Vertical grid lines
    for (int i = 1; i < 5; i++) {
      final x = (i / 5) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A reusable bar chart widget for analytics dashboards
class AnalyticsBarChart extends StatelessWidget {
  final List<ChartDataPoint> data;
  final String title;
  final Color primaryColor;
  final double height;
  final String? yAxisLabel;
  final String? xAxisLabel;

  const AnalyticsBarChart({
    super.key,
    required this.data,
    required this.title,
    this.primaryColor = Colors.blue,
    this.height = 200,
    this.yAxisLabel,
    this.xAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? _buildEmptyState()
                : CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: BarChartPainter(
                      data: data,
                      primaryColor: primaryColor,
                    ),
                  ),
          ),
          if (xAxisLabel != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                xAxisLabel!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color primaryColor;

  BarChartPainter({required this.data, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxY = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final barWidth = size.width / (data.length * 1.5);

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i].y / maxY) * size.height * 0.8;
      final x = (i * size.width) / data.length + barWidth * 0.25;
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      // Gradient effect
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor, primaryColor.withOpacity(0.6)],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(x, y, barWidth, barHeight),
        );

      canvas.drawRRect(rect, gradientPaint);

      // Draw value labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: data[i].y.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + barWidth / 2 - textPainter.width / 2,
          y - textPainter.height - 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A reusable donut chart widget for analytics dashboards
class AnalyticsDonutChart extends StatelessWidget {
  final List<DonutChartData> data;
  final String title;
  final double height;
  final String? centerText;
  final String? centerSubtext;

  const AnalyticsDonutChart({
    super.key,
    required this.data,
    required this.title,
    this.height = 250,
    this.centerText,
    this.centerSubtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? _buildEmptyState()
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CustomPaint(
                          size: const Size(double.infinity, double.infinity),
                          painter: DonutChartPainter(
                            data: data,
                            centerText: centerText,
                            centerSubtext: centerSubtext,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLegend()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.donut_small, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${item.value.toStringAsFixed(0)} (${item.percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DonutChartData> data;
  final String? centerText;
  final String? centerSubtext;

  DonutChartPainter({required this.data, this.centerText, this.centerSubtext});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    final innerRadius = radius * 0.6;

    double startAngle = -90 * 3.14159 / 180; // Start from top

    for (final item in data) {
      final sweepAngle = (item.percentage / 100) * 2 * 3.14159;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      // Draw outer arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw inner circle (donut hole)
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, innerRadius, innerPaint);

      startAngle += sweepAngle;
    }

    // Draw center text
    if (centerText != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: centerText!,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2 - (centerSubtext != null ? 12 : 0),
        ),
      );
    }

    // Draw center subtext
    if (centerSubtext != null) {
      final subtextPainter = TextPainter(
        text: TextSpan(
          text: centerSubtext!,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      subtextPainter.layout();
      subtextPainter.paint(
        canvas,
        Offset(center.dx - subtextPainter.width / 2, center.dy + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Data models for charts
class ChartDataPoint {
  final double x;
  final double y;
  final String? label;

  ChartDataPoint({required this.x, required this.y, this.label});
}

class DonutChartData {
  final String label;
  final double value;
  final double percentage;
  final Color color;

  DonutChartData({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });
}

/// Helper function to calculate percentages for donut charts
List<DonutChartData> calculateDonutData(
  Map<String, double> data,
  List<Color> colors,
) {
  final total = data.values.fold<double>(0, (sum, value) => sum + value);
  final items = <DonutChartData>[];

  int colorIndex = 0;
  for (final entry in data.entries) {
    final percentage = (entry.value / total) * 100;
    items.add(
      DonutChartData(
        label: entry.key,
        value: entry.value,
        percentage: percentage,
        color: colors[colorIndex % colors.length],
      ),
    );
    colorIndex++;
  }

  return items;
}

/// Predefined color palettes for charts
class ChartColors {
  static const List<Color> primary = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  static const List<Color> pastel = [
    Color(0xFF6BB6FF),
    Color(0xFF41C9A7),
    Color(0xFFFFB84D),
    Color(0xFFFF6B6B),
    Color(0xFFAE81FF),
    Color(0xFF26D0CE),
    Color(0xFF5C7CFA),
    Color(0xFFFF8CC8),
  ];
}
