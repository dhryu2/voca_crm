import 'package:flutter/material.dart';
import '../../core/utils/haptic_helper.dart';

enum CustomButtonVariant {
  primary,
  secondary,
  tertiary,
}

class CustomButton extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final ButtonStyle? style;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final Widget? icon;
  final Widget? label;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    Key? key,
    this.child,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.style,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height = 48,
    this.icon,
    this.label,
    this.padding,
  }) : assert(child != null || (icon != null || label != null), 'Either child or icon/label must be provided'),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEnabled = !isDisabled && !isLoading && onPressed != null;

    Color backgroundColor;
    Color textColor;
    Color? borderColor;

    switch (variant) {
      case CustomButtonVariant.primary:
        backgroundColor = isEnabled ? theme.primaryColor : Colors.grey[300]!;
        textColor = isEnabled ? Colors.white : Colors.grey[500]!;
        borderColor = null;
        break;
      case CustomButtonVariant.secondary:
        backgroundColor = isEnabled ? theme.primaryColor.withOpacity(0.1) : Colors.grey[200]!;
        textColor = isEnabled ? theme.primaryColor : Colors.grey[500]!;
        borderColor = isEnabled ? theme.primaryColor : Colors.grey[400];
        break;
      case CustomButtonVariant.tertiary:
        backgroundColor = Colors.transparent;
        textColor = isEnabled ? theme.primaryColor : Colors.grey[500]!;
        borderColor = null;
        break;
    }

    final defaultStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: variant == CustomButtonVariant.primary ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null
            ? BorderSide(color: borderColor, width: 1.5)
            : BorderSide.none,
      ),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );

    Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else if (icon != null && label != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          const SizedBox(width: 8),
          label!,
        ],
      );
    } else if (icon != null) {
      buttonChild = icon!;
    } else if (label != null) {
      buttonChild = label!;
    } else {
      buttonChild = child!;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                HapticHelper.light();
                if (onPressed != null) onPressed!();
              }
            : null,
        style: style != null ? defaultStyle.merge(style) : defaultStyle,
        child: buttonChild,
      ),
    );
  }
}
