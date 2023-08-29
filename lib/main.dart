import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_processing/flutter_processing.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:huawei_ml_body/huawei_ml_body.dart';
import 'package:path_provider/path_provider.dart';
import 'package:remote_control/HandState.dart';
import 'package:remote_control/AccessService.dart';

late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  AccessService service = AccessService();

  int? textureId;
  int cameraIndex = 1;
  int stateCounter = 0;

  double aheight = 0, awidth = 0;
  double imgHeight = 0, imgWidth = 0;
  double heightDif = 0, widthDif = 0;
  double heightPercent = 0.4, widthPercent = 0.3;
  double frameRate = 30;
  double maxFrames = 10000;

  Size? imageSize;
  Size? viewportSize;
  Size? modifiedViewport;

  var hController;

  MLBodyLensEngine? engine;

  bool processing = false;
  bool loading = true;

  InputImageRotation? rotation;

  String path = '';

  Offset? centerPoint = Offset(0, 0);
  Offset? referencePoint = Offset(0, 0);
  Offset? prevReferencePoint = Offset(0, 0);
  Offset? startingPoint = Offset(0, 0);

  Rect? handRect = Rect.fromLTRB(0, 0, 0, 0);

  Map<int, Offset> landmarks = {};

  List<int> fingerLast = [4, 8, 12, 16, 20];
  List<int> fingerSecondLast = [3, 7, 11, 15, 19];

  HandState prevState = HandState.NoData;
  HandState handState = HandState.NoData;

  final keyCustomPaint = GlobalKey();

  late Sketch sketch;

  late Directory appDocDir;

  int cnt = 0;

  Timer? timer;
  Stopwatch stopwatch = Stopwatch();

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    initApp();

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      cnt = 0;
    });

    super.initState();
  }

  @override
  void dispose() {
    service.stop();
    engine!.release();
    super.dispose();
  }

  Image? testImage;

  @override
  Widget build(BuildContext context) {
    var query = MediaQuery.of(context);
    aheight = query.size.height;
    awidth = query.size.width;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          return Future.value(true);
        } else {
          AccessService.platform.invokeMethod("sendToBackground");
          return Future.value(false);
        }
      },
      child: Scaffold(
        body: Container(
          child: loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        height: aheight,
                        width: awidth,
                        child: Processing(
                          sketch: sketch,
                        ),
                      ),
                    ),
                    MLBodyLens(
                      textureId: textureId,
                      //width: awidth,
                      //height: aheight,
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        height: aheight,
                        width: awidth,
                        child: CustomPaint(
                          painter: MyPainter(
                            landmarks: landmarks,
                            centerPoint: referencePoint,
                            prevCenterPoint: prevReferencePoint,
                            handRect: handRect,
                            handState: handState,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 10, top: 10),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: handState == HandState.Press
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                    // Text(handState.name)
                  ],
                ),
        ),
      ),
    );
  }

  void initApp() async {
    await getDirectory();
    await service.init(awidth, aheight);
    await initStream();
    initSketch();
    loading = false;
    setState(() {});
  }

  Future<void> getDirectory() async {
    appDocDir = await getApplicationDocumentsDirectory();
    String filePath = appDocDir.path + '/action.txt';
    filePath = filePath.replaceFirst("/app_flutter", "", 0);
    File(filePath).writeAsStringSync("NoAction");
  }

  Future<void> initStream() async {
    try {
      hController = MLBodyLensController(
        applyFps: frameRate,
        transaction: BodyTransaction.hand,
        lensType: MLBodyLensController.frontLens,
      );
      engine = MLBodyLensEngine(controller: hController);
      engine!.setTransactor(onTransaction);
      await engine!.init().then((value) {
        setState(() => textureId = value);
      });
      engine!.run();
      viewportSize = await engine!.getDisplayDimension();
      imgHeight = viewportSize!.height * heightPercent;
      imgWidth = viewportSize!.width * widthPercent;

      widthDif = (viewportSize!.width - imgWidth) / 2;
      heightDif = (viewportSize!.height - imgHeight) / 2;
      modifiedViewport = Size(imgWidth, imgHeight);
    } catch (e) {
      int i = 0;
    }
  }

  void initSketch() {
    sketch = Sketch.simple(
      setup: (sketch) async {
        sketch.size(width: awidth.toInt() + 1, height: aheight.toInt() + 1);
        sketch.background(color: Colors.white);
      },
      draw: (sketch) async {
        if (handState == HandState.NoData) {
          sketch.background(color: Colors.white);
          return;
        }
        sketch.stroke(color: Colors.yellow);
        sketch.strokeWeight(3);
        /* sketch.line(
                      Offset(130, 100),
                      Offset(100, 30),
                    );*/
        if (prevReferencePoint != null) {
          sketch.line(
            prevReferencePoint!,
            referencePoint!,
          );
          prevReferencePoint = Offset(referencePoint!.dx, referencePoint!.dy);
        }
      },
    );
  }

  void onTransaction({dynamic result}) {
    int i = 0;
    //centerPoint = null;
    handRect = null;
    landmarks.clear();

    cnt++;

    double normalSize = min(aheight, awidth);
    bool hasData = false;

    prevState = HandState.values
        .firstWhere((element) => element.name == handState.name);

    if (result.length == 0 || result[0].handKeyPoints.length != 21) {
      /*if (handState == HandState.Tracking) {

      } else {
        service.removeOverlay();
      }*/
    } else {
      computeData(result);
      service.drawHandLocation(referencePoint ?? Offset(0, 0), handState);
      hasData = true;
    }

    switch (handState) {
      ////

      case HandState.Tracking:
        if (!hasData) {
          handState = HandState.Unsure;
          break;
        }

        if (isLockGesture()) {
          handState = HandState.Locking;
          break;
        }

        break;

      ////

      case HandState.Locking:
        if (!hasData) {
          handState = HandState.Unsure;
          break;
        }
        double nr = transitionDuration[HandState.Press]! * frameRate;
        if (stateCounter.toDouble() >=
            transitionDuration[HandState.Press]! * frameRate) {
          handState = HandState.Press;
          break;
        }

        if (isFreeGesture()) {
          handState = HandState.Tracking;
          break;
        }

        break;

      ////

      case HandState.Unsure:
        if (stateCounter.toDouble() >=
            transitionDuration[HandState.NoData]! * frameRate) {
          prevReferencePoint = null;
          handState = HandState.NoData;
          referencePoint = null;
          service.removeOverlay();
          break;
        }

        if (hasData) {
          handState = HandState.Tracking;
          break;
        }

        break;

      ////

      case HandState.NoData:
        if (hasData) {
          handState = HandState.Tracking;
          break;
        }

        break;

      ////

      case HandState.Press:
        if (!hasData) {
          service.clickScreen();
          handState = HandState.Unsure;
          break;
        }

        if (isFreeGesture()) {
          service.clickScreen();
          handState = HandState.Tracking;
          break;
        }

        if (stateCounter.toDouble() >=
            transitionDuration[HandState.Gesture]! * frameRate) {
          handState = HandState.Gesture;
          stopwatch.start();
          startingPoint = Offset(referencePoint!.dx, referencePoint!.dy);
          break;
        }

        break;

      ////

      case HandState.Gesture:
        if (!hasData) {
          stopwatch.stop();
          stopwatch.reset();
          service.clickScreen();
          handState = HandState.Unsure;
          break;
        }

        if (isFreeGesture()) {
          service.executeGesture(
              startingPoint!, referencePoint!, stopwatch.elapsedMilliseconds);
          stopwatch.stop();
          stopwatch.reset();
          handState = HandState.Tracking;
          break;
        }

        break;
    }

    if (prevState.name != handState.name) {
      stateCounter = 1;
    } else {
      stateCounter++;
      if (stateCounter > maxFrames) {
        handState = HandState.NoData;
        stateCounter = 1;
      }
    }

    setState(() {});
  }

  void computeData(var result) {
    BodyBorder rect = result[0].rect;
    /*handRect = Rect.fromLTRB(
      (viewportSize!.height - rect.left!.toDouble()) *
          awidth /
          viewportSize!.height,
      rect.top!.toDouble() * aheight / viewportSize!.width,
      (viewportSize!.height - rect.right!.toDouble()) *
          awidth /
          viewportSize!.height,
      rect.bottom!.toDouble() * aheight / viewportSize!.width,
    );*/

    for (var landmark in result[0].handKeyPoints) {
      /*double x = awidth -
          (max(0, (landmark.pointX - widthDif) as double) /
                  modifiedViewport!.width) *
              awidth;
      double y = (max(0, (landmark.pointY - heightDif) as double)) /
          modifiedViewport!.height *
          aheight;*/
      landmarks[landmark.type] = Offset(viewportSize!.width - landmark.pointX,
          landmark.pointY); // Offset(min(awidth, x), min(aheight, y));
    }

    List<bool> marked = List.filled(21, false);

    marked[0] = true;
    int currentId = 0, prev = 0;
    double sumX = 0, sumY = 0;

    List<int> interestIndexes = [0, 1, 2, 5, 9, 13, 17];

    for (int j in interestIndexes) {
      int id = j;
      if (!landmarks.containsKey(j)) continue;
      // currentId;
      /*double minDist = double.maxFinite;
      for (int y = 0; y < 21; y++) {
        if (!marked[y]) {
          double dist = sqrt(
              (pow(landmarks[y]!.dx - landmarks[currentId]!.dx, 2)) +
                  (pow(landmarks[y]!.dy - landmarks[currentId]!.dy, 2)));
          if (minDist > dist) {
            minDist = dist;
            id = y;
          }
        }
      }*/
      sumX += landmarks[id]!.dx - landmarks[0]!.dx;
      sumY += landmarks[id]!.dy - landmarks[0]!.dy;
      prev = j;
      //marked[id] = true;
      //currentId = id;
    }
    sumX = -sumX / (interestIndexes.length - 1);
    sumY = -sumY / (interestIndexes.length - 1);

    double x = landmarks[0]!.dx - sumX;
    double y = landmarks[0]!.dy - sumY;

    /**/

    centerPoint = Offset(x, y);

    x = (max(0, (x - widthDif) as double) / modifiedViewport!.width) * awidth;
    y = (max(0, (y - heightDif) as double)) /
        modifiedViewport!.height *
        aheight;

    x = max(0, x);
    x = min(x, awidth); //
    y = max(0, y);
    y = min(y, aheight);

    referencePoint = Offset(x, y);
    // referencePoint=Offset(landmarks[6]!.dx,landmarks[6]!.dy);
  }

  bool isLockGesture() {
    bool ok = true;
    for (int i = 0; i < fingerLast.length; i++) {
      if (getDist(centerPoint!, landmarks[fingerLast[i]]!) >
          getDist(centerPoint!, landmarks[fingerSecondLast[i]]!)) {
        ok = false;
        break;
      }
    }
    /*if(getDist(landmarks[5]!, landmarks[7]!)>getDist(landmarks[5]!, landmarks[8]!)) {
      return true;
    }
    else{
      return false;
    }*/
    return ok;
  }

  bool isFreeGesture() {
    /*if(getDist(landmarks[5]!, landmarks[7]!)<getDist(landmarks[5]!, landmarks[8]!)) {
      return true;
    }
    else{
      return false;
    }*/
    bool ok = true;
    for (int i = 0; i < fingerLast.length; i++) {
      if (getDist(centerPoint!, landmarks[fingerLast[i]]!) <
          getDist(centerPoint!, landmarks[fingerSecondLast[i]]!)) {
        ok = false;
        break;
      }
    }
    return ok;
  }

  void getHandLandmarks(File image) async {
    if (processing) return;
    processing = true;
    // Create a hand keypoint analyzer.
    final analyzer = MLHandKeypointAnalyzer();

    final setting = MLHandKeyPointAnalyzerSetting(path: image.path);

    List<MLHandKeyPoints> list = await analyzer.analyseFrame(setting);

    bool result = await analyzer.stop();
    processing = false;
  }

  double getDist(Offset p1, Offset p2) =>
      sqrt(pow((p1.dx - p2.dx), 2) + pow((p1.dy - p2.dy), 2));
}

class MyPainter extends CustomPainter {
  Map<int, Offset> landmarks;
  Offset? centerPoint;
  Offset? prevCenterPoint;
  Rect? handRect;
  HandState handState;

  MyPainter(
      {required this.landmarks,
      required this.centerPoint,
      required this.prevCenterPoint,
      required this.handRect,
      required this.handState});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint();

    for (var point in landmarks.values) {
      canvas.drawCircle(
          Offset(point.dx, point.dy), 5, paint..color = Colors.red);
    }
    if (handRect != null) {
      canvas.drawRect(
          handRect!,
          paint
            ..color = Colors.yellow.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }

    if (centerPoint != null) {
      canvas.drawCircle(
          centerPoint!,
          10,
          paint
            ..color = Colors.yellow.withOpacity(0.5)
            ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/*List<bool> marked = List.filled(21, false);
    List<int> interestLandmarks = [1, 2, 5, 6, 10, 11, 14, 15, 18, 19];
    int cnt = 0;

    for (int i = 0; i < min(10, list.length); i++) {
      marked[list[i][0]] = true;
    }
    for (var id in interestLandmarks) {
      if (marked[id]) cnt++;
    }

    bool res = (cnt * 100 / interestLandmarks.length >= 50);
    return res;

    List<bool> marked = List.filled(21, false);
    List<int> interestLandmarks = [4, 8, 12, 16, 19, 20];
    int cnt = 0;

    for (int i = 0; i < min(10, list.length); i++) {
      marked[list[i][0]] = true;
    }
    for (var id in interestLandmarks) {
      if (marked[id]) cnt++;
    }

    bool res = (cnt * 100 / interestLandmarks.length >= 80);
    return res;
     */
