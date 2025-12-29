import 'package:flutter/material.dart';

class SignupProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  const SignupProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // 동적 사이즈
        final circleSize = screenWidth * 0.08; // 원 크기
        final fontSize = screenWidth * 0.032; // 타이틀 폰트
        final numberSize = screenWidth * 0.038; // 숫자 폰트
        final dotSize = screenWidth * 0.012; // 연결 점 크기
        final horizontalPadding = screenWidth * 0.08;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(totalSteps * 2 - 1, (index) {
              if (index.isEven) {
                final stepIndex = index ~/ 2;
                return _buildStep(
                  stepIndex,
                  circleSize: circleSize,
                  fontSize: fontSize,
                  numberSize: numberSize,
                );
              } else {
                final beforeStep = index ~/ 2;
                return _buildDots(beforeStep, dotSize: dotSize);
              }
            }),
          ),
        );
      },
    );
  }

  Widget _buildStep(
    int index, {
    required double circleSize,
    required double fontSize,
    required double numberSize,
  }) {
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;
    final isActive = isCompleted || isCurrent;
    const primaryColor = Color(0xFF6B4EFF);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primaryColor : const Color(0xFFE5E5E5),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: circleSize * 0.5)
                : Text(
                    '${index + 1}',
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: TextStyle(
                      height: 1.0,
                      color: isActive ? Colors.white : const Color(0xFFAAAAAA),
                      fontWeight: FontWeight.w600,
                      fontSize: numberSize,
                    ),
                  ),
          ),
        ),
        SizedBox(height: circleSize * 0.3),
        Text(
          stepTitles[index],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFFAAAAAA),
          ),
        ),
      ],
    );
  }

  Widget _buildDots(int beforeStep, {required double dotSize}) {
    final isCompleted = beforeStep < currentStep;
    const primaryColor = Color(0xFF6B4EFF);

    return Padding(
      padding: EdgeInsets.only(bottom: dotSize * 4), // 텍스트 높이 보정
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: dotSize * 0.8),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? primaryColor : const Color(0xFFD5D5D5),
              ),
            ),
          );
        }),
      ),
    );
  }
}
