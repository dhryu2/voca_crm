import 'package:flutter/material.dart';

class CustomCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double elevation;
  final bool enableHover;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const CustomCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.elevation = 2,
    this.enableHover = true,
    this.borderRadius,
    this.shape,
  }) : super(key: key);

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final shapeBorder = widget.shape ?? RoundedRectangleBorder(borderRadius: borderRadius);

    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: widget.margin,
        child: Material(
          color: widget.color ?? Colors.white,
          elevation: _isHovered && widget.enableHover ? widget.elevation + 2 : widget.elevation,
          shape: shapeBorder,
          child: InkWell(
            onTap: widget.onTap,
            customBorder: shapeBorder,
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
