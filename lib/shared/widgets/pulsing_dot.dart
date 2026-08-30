import 'package:flutter/material.dart';

/// Expanding, fading dot that pulses behind while the mic is active — the
/// web's pulse animation, driven by the owning widget's [AnimationController].
class PulsingDot extends StatelessWidget {
  const PulsingDot({required this.animation, super.key});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - value).clamp(0.0, 1.0),
                child: Container(
                  width: 8 + 24 * value,
                  height: 8 + 24 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
