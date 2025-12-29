import 'package:flutter/material.dart';
import 'package:voca_crm/core/theme/theme_color.dart';
import 'package:voca_crm/data/datasource/statistics_service.dart';

/// 간단한 라인 차트 위젯
class SimpleLineChart extends StatelessWidget {
  final List<TimeSeriesDataPoint> dataPoints;
  final String title;
  final Color lineColor;
  final double height;

  const SimpleLineChart({
    Key? key,
    required this.dataPoints,
    required this.title,
    this.lineColor = Colors.blue,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return Container(
        height: height,
        child: Center(child: Text('데이터가 없습니다')),
      );
    }

    final maxCount = dataPoints.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    final minCount = dataPoints.map((e) => e.count).reduce((a, b) => a < b ? a : b);
    final range = maxCount - minCount;

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y축 레이블
                SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$maxCount',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(maxCount / 2).round()}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '0',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 차트
                Expanded(
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      dataPoints: dataPoints,
                      maxCount: maxCount,
                      minCount: minCount,
                      lineColor: lineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // X축 레이블
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(dataPoints.first.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  _formatDate(dataPoints.last.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

class _LineChartPainter extends CustomPainter {
  final List<TimeSeriesDataPoint> dataPoints;
  final int maxCount;
  final int minCount;
  final Color lineColor;

  _LineChartPainter({
    required this.dataPoints,
    required this.maxCount,
    required this.minCount,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (dataPoints.length - 1);
    final range = maxCount - minCount;

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final normalizedValue = range == 0 ? 0.5 : (dataPoints[i].count - minCount) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // 점 그리기
      canvas.drawCircle(Offset(x, y), 4, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }

    // 채우기 패스 완성
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 채우기 그리기
    canvas.drawPath(fillPath, fillPaint);

    // 선 그리기
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
