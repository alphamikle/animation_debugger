import 'dart:async';
import 'dart:math';

import 'package:animation_debugger/animation_debugger.dart';
import 'package:example/controller_extension.dart';
import 'package:flutter/material.dart';

const backgroundEndColor = Color.fromRGBO(1, 103, 213, 1);
const backgroundStartColor = Color.fromRGBO(43, 88, 153, 1);
const legendBackgroundColor = Color.fromRGBO(16, 99, 196, 1);
const inkColor = Colors.white;
const borderWidth = 3.0;
const gap = 15.0;
const bottomGap = gap * 5;
const minLegendWidth = 200.0;
const maxLegendWidth = 300.0;
const minLegendHeight = 100.0;
const maxLegendHeight = 150.0;
const legendSizePercent = 0.15;
const ballSize = 10.0;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      builder: AnimationDebugger.builder,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  Curve get curve => Curves.linear;
  Duration get duration => const Duration(seconds: 120);

  final List<String> spaceObjects = [
    'sun',
    'mercury',
    'venus',
    'earth',
    'mars',
    'jupiter',
    'saturn',
    'uranus',
    'neptune',
    'pluto',
  ];
  final List<int> daysInTheYear = [
    25,
    88,
    225,
    365,
    687,
    4380,
    10950,
    30660,
    60225,
    90520,
  ];
  List<double> get distances => [
        1,
        100,
        170,
        260,
        380,
        530,
        700,
        860,
        1040,
        1200,
      ];
  final List<AnimationController> controllers = [];

  void initSpaceObjects() {
    for (int i = 0; i < spaceObjects.length; i++) {
      final String objectName = spaceObjects[i];
      final int daysInTheYear = this.daysInTheYear[i];

      final AnimationController controller = AnimationDebugger.of(context).watch(AnimationController(
        vsync: this,
        debugLabel: objectName,
        duration: Duration(seconds: daysInTheYear),
      ));
      controllers.add(controller);
      unawaited(controller.cyclicForward());
    }
  }

  void goBack(BuildContext context) {
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (BuildContext context) => const MyHomePage(),
        ),
      ),
    );
  }

  void leavePage(BuildContext context) {
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) {
                  return ElevatedButton(
                    onPressed: () => goBack(context),
                    child: const Text('Go back'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPaper() {
    return Positioned(
      left: gap,
      top: gap,
      right: gap,
      bottom: bottomGap,
      child: GridPaper(
        color: Colors.white.withOpacity(0.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: inkColor,
              width: borderWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLegend() {
    return const Positioned(
      right: gap + borderWidth,
      bottom: bottomGap + borderWidth,
      child: Padding(
        padding: EdgeInsets.only(left: 16, top: 8, right: 16),
        child: Text(
          'ANIMATION DEBUGGER',
          style: TextStyle(
            fontFamily: 'BlueprintFont',
            color: inkColor,
            fontSize: 70,
            letterSpacing: 5,
          ),
        ),
      ),
    );
  }

  List<Widget> buildObjects() {
    final List<Widget> result = [];

    final Size size = MediaQuery.of(context).size;
    final double width = size.width - gap * 2 - borderWidth * 2 - ballSize;
    final double height = size.height - bottomGap - gap - borderWidth * 2 - ballSize;

    final double square = min(width, height) * 0.8;

    for (int i = 0; i < spaceObjects.length; i++) {
      final String name = spaceObjects[i];
      final AnimationController controller = controllers[i];
      final double distance = distances[i];
      final double fixMover = i == 6 || i == 7 ? -20 : -10;

      final Widget spaceObject = Image.asset(
        'assets/$name.png',
        height: i == 0 ? 50 : 30,
      );

      result.add(
        AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            final double value = controller.value;
            final double rads = value * 360 / 2 / pi;
            const double multiplier = 0.65;
            final double x = cos(rads) * distance * multiplier;
            final double y = sin(rads) * distance * multiplier;

            if (i == 0) {
              return Positioned(
                left: width / 2,
                bottom: height / 2 * 1.2,
                child: Transform.translate(
                  offset: Offset(fixMover, -5),
                  child: Transform.rotate(
                    angle: rads,
                    child: child!,
                  ),
                ),
              );
            }

            return Positioned(
              left: (width / 2) + x,
              bottom: (height / 2 * 1.2) + y,
              child: Transform.translate(
                offset: Offset(fixMover, -5),
                child: child!,
              ),
            );
          },
          child: spaceObject,
        ),
      );
    }
    return result;
  }

  @override
  void dispose() {
    print('DISPOSE');
    for (final AnimationController controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initSpaceObjects();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            backgroundStartColor,
            backgroundEndColor,
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          stops: [
            0,
            1,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            /// ? GRID,
            buildPaper(),

            ...buildObjects(),

            /// ? LEGEND
            buildLegend(),

            Positioned(
              bottom: 8,
              right: 8,
              child: Builder(
                builder: (BuildContext context) {
                  return Tooltip(
                    message: 'Leave page',
                    child: FloatingActionButton(
                      onPressed: () => leavePage(context),
                      child: const Icon(Icons.exit_to_app),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
