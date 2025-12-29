import 'dart:math';
import 'package:flutter/material.dart';

/// 간단한 파이 차트 위젯
class SimplePieChart extends StatelessWidget {
  final Map<String, int> data;
  final String title;
  final Map<String, Color> colorMap;
  final double size;

  const SimplePieChart({
    Key? key,
    required this.data,
    required this.title,
    required this.colorMap,
    this.size = 180,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (sum, value) => sum + value);

    if (total == 0) {
      return Container(
        height: size + 100,
        child: Center(child: Text('데이터가 없습니다')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 파이 차트
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    data: data,
                    colorMap: colorMap,
                    total: total,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // 범례
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: data.entries
                      .where((entry) => entry.value > 0)
                      .map((entry) {
                    final percentage = (entry.value / total * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: colorMap[entry.key] ?? Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_getGradeDisplayName(entry.key)}: ${entry.value}명',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGradeDisplayName(String grade) {
    switch (grade) {
      case 'VIP':
        return 'VIP';
      case 'GOLD':
        return 'GOLD';
      case 'SILVER':
        return 'SILVER';
      case 'BRONZE':
        return 'BRONZE';
      case 'GENERAL':
        return 'GENERAL';
      default:
        return grade;
    }
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final Map<String, Color> colorMap;
  final int total;

  _PieChartPainter({
    required this.data,
    required this.colorMap,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    double startAngle = -pi / 2; // Start from top

    for (final entry in data.entries) {
      if (entry.value == 0) continue;

      final sweepAngle = (entry.value / total) * 2 * pi;
      final paint = Paint()
        ..color = colorMap[entry.key] ?? Colors.grey
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // 테두리
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
