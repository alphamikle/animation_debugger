import 'dart:async';
import 'dart:math';

import 'package:animation_debugger/src/debuggable_animation_controller.dart';
import 'package:animation_debugger/src/debugger_icon_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kSize = 44;
const double kGap = kSize / 2;
const double kVisibleValue = 0.25;
final BorderRadius radius = BorderRadius.circular(kSize / 4);
const Duration _rulerMovingDuration = Duration(milliseconds: 500);
const double _kMaxHeight = 400;

enum _RulerPositionStatus {
  /// ? Bottom side
  onBottom,
  hiddenAtBottom,

  /// ? Top side
  onTop,
  hiddenAtTop,
}

bool _isRulerOnBottomSide(_RulerPositionStatus status) {
  if (status == _RulerPositionStatus.hiddenAtBottom) {
    return true;
  }
  if (status == _RulerPositionStatus.onBottom) {
    return true;
  }
  return false;
}

class AnimationDebugger extends StatefulWidget {
  const AnimationDebugger({
    required this.child,
    super.key,
  });

  static Widget builder(BuildContext context, Widget? child) {
    if (child == null) {
      return const SizedBox.shrink();
    }

    return AnimationDebugger(child: child);
  }

  final Widget child;

  static AnimationDebuggerState of(BuildContext context) {
    final AnimationDebuggerState? debugger = context.findAncestorStateOfType<AnimationDebuggerState>();
    if (debugger == null) {
      throw Exception('Not found AnimationDebugger at the widget tree');
    }
    return debugger;
  }

  @override
  State<AnimationDebugger> createState() => AnimationDebuggerState();
}

class AnimationDebuggerState extends State<AnimationDebugger> with TickerProviderStateMixin {
  late final AnimationController _rulerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final Animation<double> _rulerAnimation = CurvedAnimation(parent: _rulerController, curve: Curves.easeOutQuart);
  late final AnimationController _expanderController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final Animation<double> _expanderAnimation = CurvedAnimation(parent: _expanderController, curve: Curves.easeOutQuart);

  Color get _foregroundColor => Theme.of(context).colorScheme.onTertiary;
  Color get _backgroundColor => Theme.of(context).colorScheme.tertiary;

  final Map<String, DebuggableAnimationController> _controllers = {};
  final Map<String, Timer?> _manualModePlayingTimers = {};
  final Map<String, bool> _manuallyPlayingControllers = {};
  final Map<String, bool> _stoppedControllers = {};
  Timer? _watchTimer;

  bool _isHovered = false;
  bool _isExpanded = false;
  double _rulerHeight = _kMaxHeight + kGap + kSize;
  _RulerPositionStatus _rulerStatus = _RulerPositionStatus.onBottom;

  AnimationController watch(AnimationController originalController) {
    if (kReleaseMode) {
      return originalController;
    }
    final String? debugLabel = originalController.debugLabel;
    if (debugLabel == null || debugLabel.isEmpty) {
      throw Exception('AnimationController does not have a debugLabel');
    }
    if (_controllers.containsKey(debugLabel)) {
      return _controllers[debugLabel]!;
    }
    final DebuggableAnimationController debuggableAnimationController = DebuggableAnimationController(
      vsync: this,
      duration: originalController.duration,
      value: originalController.value,
      debugLabel: debugLabel,
      upperBound: originalController.upperBound,
      reverseDuration: originalController.reverseDuration,
      lowerBound: originalController.lowerBound,
      animationBehavior: originalController.animationBehavior,
    );
    _controllers[debugLabel] = debuggableAnimationController;
    debuggableAnimationController.onDispose(() => _removeController(debugLabel));
    _updateAfterChanges();
    return debuggableAnimationController;
  }

  void _removeController(String debugLabel) {
    _controllers.remove(debugLabel);
    _manualModePlayingTimers[debugLabel]?.cancel();
    _manualModePlayingTimers.remove(debugLabel);
    _manuallyPlayingControllers.remove(debugLabel);
    _stoppedControllers.remove(debugLabel);
    _updateAfterChanges();
  }

  void _updateAfterChanges() {
    _watchTimer?.cancel();
    _watchTimer = Timer(const Duration(milliseconds: 50), () {
      _watchTimer = null;
      setState(() {});
    });
  }

  void _toggleHoverState(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
  }

  void _manuallyPlayingInfoCleaner(String debugLabel) {
    _manuallyPlayingControllers.remove(debugLabel);
    _manualModePlayingTimers.remove(debugLabel);
    setState(() {});
  }

  void _moveController({
    required AnimationController controller,
    required double value,
  }) {
    final String debugLabel = controller.debugLabel!;
    _stoppedControllers.remove(debugLabel);
    controller.value = value;
    if (_manuallyPlayingControllers[debugLabel] ?? false) {
      _manualModePlayingTimers[debugLabel]?.cancel();
      _manualModePlayingTimers[debugLabel] = Timer(const Duration(milliseconds: 250), () => _manuallyPlayingInfoCleaner(debugLabel));
      return;
    }
    _manuallyPlayingControllers[debugLabel] = true;
    _manualModePlayingTimers[debugLabel] = Timer(const Duration(milliseconds: 250), () => _manuallyPlayingInfoCleaner(debugLabel));
  }

  Future<void> _rulerMovingOperation(VoidCallback callback, {bool noWait = false}) async {
    callback();
    setState(() {});
    if (noWait) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(_rulerMovingDuration);
  }

  Future<void> _toggleRulerPosition() async {
    if (_rulerStatus == _RulerPositionStatus.onBottom) {
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.hiddenAtBottom);
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.hiddenAtTop, noWait: true);
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.onTop);
    } else if (_rulerStatus == _RulerPositionStatus.onTop) {
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.hiddenAtTop);
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.hiddenAtBottom, noWait: true);
      await _rulerMovingOperation(() => _rulerStatus = _RulerPositionStatus.onBottom);
    }
  }

  Future<void> _toggleRulerState() async {
    if (_rulerController.isAnimating) {
      return;
    }
    if (_rulerController.isCompleted) {
      if (_isExpanded) {
        unawaited(_expanderController.animateBack(0));
      }
      await _rulerController.animateBack(0);
    } else {
      if (_isExpanded) {
        unawaited(_expanderController.forward(from: 0));
      }
      await _rulerController.forward(from: 0);
    }
  }

  Future<void> _animateExpanding() async {
    if (_expanderController.isAnimating) {
      return;
    }
    if (_expanderController.isCompleted) {
      await _expanderController.animateBack(0);
    } else {
      await _expanderController.forward(from: 0);
    }
  }

  Future<void> _toggleExpandingState() async {
    await _animateExpanding();
    _isExpanded = !_isExpanded;
  }

  double? _rulerBottomPosition() {
    if (_rulerStatus == _RulerPositionStatus.onBottom) {
      return kGap;
    }
    if (_rulerStatus == _RulerPositionStatus.hiddenAtBottom) {
      return -(_isExpanded ? _rulerHeight : kSize + kGap + 5);
    }
    return null;
  }

  double? _rulerTopPosition() {
    if (_rulerStatus == _RulerPositionStatus.onTop) {
      return kGap;
    }
    if (_rulerStatus == _RulerPositionStatus.hiddenAtTop) {
      return -(_isExpanded ? _rulerHeight : kSize + kGap + 5);
    }
    return null;
  }

  Widget _playForwardOrBackwardButton({
    required AnimationController controller,
  }) {
    final String debugLabel = controller.debugLabel!;

    return DIconButton(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final AnimationStatus status = controller.status;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _animationStatusToIcon(
                status: status,
                isAnimated: controller.isAnimating,
                isMovingByHand: _manuallyPlayingControllers[debugLabel] ?? false,
                isStopped: _stoppedControllers[debugLabel] ?? false,
              ),
              key: ValueKey('$debugLabel:$status'),
              color: _foregroundColor,
            ),
          );
        },
      ),
      onPressed: () {
        _stoppedControllers.remove(debugLabel);
        if (controller.isAnimating) {
          _stoppedControllers[debugLabel] = true;
          setState(() {});
          controller.stop();
        } else if (controller.isCompleted) {
          controller.animateBack(0);
        } else {
          controller.forward();
        }
      },
    );
  }

  IconData _animationStatusToIcon({
    required AnimationStatus status,
    required bool isAnimated,
    required bool isMovingByHand,
    required bool isStopped,
  }) {
    const IconData play = Icons.play_arrow_rounded;
    const IconData playBack = Icons.fast_rewind_rounded;
    const IconData pause = Icons.pause_rounded;

    if (isStopped) {
      return play;
    }
    if (status == AnimationStatus.dismissed) {
      return play;
    }
    if (status == AnimationStatus.forward && (isAnimated || isMovingByHand)) {
      return pause;
    }
    if (status == AnimationStatus.forward && !isAnimated && !isMovingByHand) {
      return play;
    }
    if (status == AnimationStatus.reverse) {
      return pause;
    }
    if (status == AnimationStatus.completed) {
      return playBack;
    }
    return play;
  }

  Widget _sliderBuilder(BuildContext context, int index, double rulerValue) {
    final AnimationController controller = _controllers.values.toList()[index];
    final String debugLabel = controller.debugLabel!;

    return Opacity(
      opacity: rulerValue,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                debugLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _foregroundColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return CupertinoSlider(
                  thumbColor: _foregroundColor,
                  value: controller.value,
                  onChanged: (double value) => _moveController(controller: controller, value: value),
                );
              },
            ),
          ),

          /// ? PLAY FORWARD
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _playForwardOrBackwardButton(controller: controller),
          ),
        ],
      ),
    );
  }

  Widget _ruler() {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(kSize / 4);
    final Size size = MediaQuery.of(context).size;
    final double width = min(size.width, 800) - (kGap * 2);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {},
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: const MaterialStatePropertyAll(Colors.transparent),
        focusColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.basic,
        onHover: _toggleHoverState,
        child: AnimatedBuilder(
          animation: _expanderAnimation,
          builder: (BuildContext context, Widget? child) {
            final double expanderValue = _expanderAnimation.value;

            return AnimatedBuilder(
              animation: _rulerAnimation,
              builder: (BuildContext context, Widget? child) {
                final double rulerValue = _rulerAnimation.value;
                final Widget controlButtons = Row(
                  children: [
                    /// ? RULER TOGGLE BUTTON
                    DIconButton(
                      onPressed: _toggleRulerState,
                      child: Stack(
                        children: [
                          Center(
                            child: Opacity(
                              opacity: 1 - rulerValue,
                              child: Icon(
                                Icons.slow_motion_video_rounded,
                                color: _foregroundColor,
                              ),
                            ),
                          ),
                          Center(
                            child: Opacity(
                              opacity: rulerValue,
                              child: Icon(
                                Icons.close_rounded,
                                color: _foregroundColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rulerValue > kVisibleValue)
                      Opacity(
                        opacity: rulerValue,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: DIconButton(
                            onPressed: _toggleRulerPosition,
                            child: Icon(
                              _isRulerOnBottomSide(_rulerStatus) ? Icons.vertical_align_top_rounded : Icons.vertical_align_bottom_rounded,
                              color: _foregroundColor,
                            ),
                          ),
                        ),
                      ),
                    if (rulerValue > kVisibleValue && _controllers.isNotEmpty) const Spacer(),
                    if (rulerValue > kVisibleValue && _controllers.isNotEmpty)
                      Opacity(
                        opacity: rulerValue,
                        child: DIconButton(
                          onPressed: _toggleExpandingState,
                          child: Transform.rotate(
                            angle: 180 * (pi / 180) * expanderValue,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _foregroundColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                );

                _rulerHeight = min(kSize + (_controllers.length * kSize * expanderValue), _kMaxHeight);

                return Container(
                  height: _rulerHeight,
                  width: ((width - kSize) * rulerValue) + kSize,
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow,
                        spreadRadius: -4,
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      /// ? CONTROL BUTTONS
                      if (_isRulerOnBottomSide(_rulerStatus) == false) controlButtons,

                      /// ? CONTROLLERS LIST
                      if (rulerValue > kVisibleValue && expanderValue > kVisibleValue)
                        Expanded(
                          child: Opacity(
                            opacity: expanderValue,
                            child: ListView.builder(
                              itemBuilder: (BuildContext context, int index) => _sliderBuilder(context, index, rulerValue),
                              itemCount: _controllers.length,
                              padding: EdgeInsets.zero,
                              physics: const BouncingScrollPhysics(),
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      /// ? CONTROL BUTTONS
                      if (_isRulerOnBottomSide(_rulerStatus)) controlButtons,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return widget.child;
    }
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (BuildContext context) {
            return Stack(
              children: [
                widget.child,
                AnimatedPositioned(
                  duration: _rulerMovingDuration * 0.99,
                  curve: Curves.easeInOutBack,
                  bottom: _rulerBottomPosition(),
                  top: _rulerTopPosition(),
                  left: kGap,
                  child: AnimatedOpacity(
                    duration: _rulerMovingDuration,
                    opacity: _isHovered ? 1 : 0.65,
                    child: _ruler(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
