import 'package:animation_debugger/src/animation_debugger.dart';
import 'package:flutter/material.dart';

class DIconButton extends StatelessWidget {
  const DIconButton({
    required this.child,
    required this.onPressed,
    super.key,
  });

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: kSize,
          width: kSize,
          child: Center(
            child: child,
          ),
        ),
        Positioned.fill(
          child: Material(
            borderRadius: radius,
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
            ),
          ),
        ),
      ],
    );
  }
}
