import 'package:flutter/animation.dart';

// TODO(alphamikle): Add support for the unbounded controllers
class DebuggableAnimationController extends AnimationController {
  DebuggableAnimationController({
    required super.vsync,
    super.value,
    super.duration,
    super.reverseDuration,
    super.debugLabel,
    super.lowerBound,
    super.upperBound,
    super.animationBehavior,
  });

  final Set<VoidCallback> _onDispose = {};

  void onDispose(VoidCallback callback) => _onDispose.add(callback);

  void removeOnDisposeCallback(VoidCallback callback) => _onDispose.remove(callback);

  @override
  void dispose() {
    for (final VoidCallback callback in _onDispose) {
      callback();
    }
    _onDispose.clear();
    super.dispose();
  }
}
