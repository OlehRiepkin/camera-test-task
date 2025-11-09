import 'package:flutter/material.dart';

class Disabled extends StatelessWidget {
  const Disabled({
    required this.child,
    this.disabled = true,
    this.opacity = 0.5,
    super.key,
  });

  final Widget child;
  final bool disabled;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: disabled,
      child: Opacity(
        opacity: disabled ? opacity : 1,
        child: child,
      ),
    );
  }
}
