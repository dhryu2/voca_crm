import 'package:flutter/material.dart';

import 'session_manager.dart';

/// 사용자 활동 감지 위젯
///
/// 자식 위젯의 터치, 스크롤 등의 이벤트를 감지하여
/// SessionManager에 활동을 기록합니다.
///
/// 사용 예:
/// ```dart
/// ActivityDetector(
///   child: MaterialApp(...),
/// )
/// ```
class ActivityDetector extends StatelessWidget {
  final Widget child;

  const ActivityDetector({
    super.key,
    required this.child,
  });

  void _recordActivity() {
    SessionManager.instance.recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: child,
    );
  }
}

/// 스크롤 활동 감지 NotificationListener
///
/// 스크롤 이벤트도 활동으로 기록하려면 이 위젯을 사용합니다.
///
/// 사용 예:
/// ```dart
/// ScrollActivityListener(
///   child: ListView(...),
/// )
/// ```
class ScrollActivityListener extends StatelessWidget {
  final Widget child;

  const ScrollActivityListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification) {
          SessionManager.instance.recordActivity();
        }
        return false; // 버블링 허용
      },
      child: child,
    );
  }
}

/// 키보드 활동 감지 위젯
///
/// 텍스트 입력 시 활동을 기록합니다.
///
/// 사용 예:
/// ```dart
/// KeyboardActivityListener(
///   child: TextField(...),
/// )
/// ```
class KeyboardActivityListener extends StatelessWidget {
  final Widget child;

  const KeyboardActivityListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        SessionManager.instance.recordActivity();
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// 활동 감지 TextField
///
/// 텍스트 입력 활동을 자동으로 기록하는 TextField입니다.
class ActivityTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;

  const ActivityTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.decoration,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      focusNode: focusNode,
      decoration: decoration ??
          InputDecoration(
            labelText: labelText,
            hintText: hintText,
          ),
      onChanged: (value) {
        SessionManager.instance.recordActivity();
        onChanged?.call(value);
      },
      onEditingComplete: () {
        SessionManager.instance.recordActivity();
        onEditingComplete?.call();
      },
      onSubmitted: (value) {
        SessionManager.instance.recordActivity();
        onSubmitted?.call(value);
      },
      onTap: () {
        SessionManager.instance.recordActivity();
      },
    );
  }
}
