import 'package:flutter/animation.dart';

extension AnimationControllerExtension on AnimationController {
  Future<void> cyclicForward({double? from}) async {
    await forward(from: from);
    await cyclicForward(from: 0);
  }
}
