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
  AcccessService service = AcccessService();

  int? textureId;
  int cameraIndex = 1;
  int abortFrames = 0;

  double aheight = 0, awidth = 0;
  double imgHeight = 0, imgWidth = 0;
  double heightDif = 0, widthDif = 0;
  double heightPercent = 0.1, widthPercent = 0.1;

  Size? imageSize;
  Size? viewportSize;

  var hController;

  MLBodyLensEngine? engine;

  bool processing = false;
  bool loading = true;

  InputImageRotation? rotation;

  String path = '';

  Offset? referencePoint = Offset(0, 0);
  Offset? prevCenterPoint = Offset(0, 0);

  Rect? handRect = Rect.fromLTRB(0, 0, 0, 0);

  Map<int, Offset> landmarks = {};

  List<int> fingerLast = [4, 8, 12, 16, 20];
  List<int> fingerSecondLast = [3, 7, 11, 15, 19];

  HandState handState = HandState.NotTracking;

  final keyCustomPaint = GlobalKey();

  late Sketch sketch;

  late Directory appDocDir;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    initApp();

    super.initState();
  }

  @override
  void dispose() {
    engine!.release();
    super.dispose();
  }

  Image? testImage;

  @override
  Widget build(BuildContext context) {
    var query = MediaQuery.of(context);
    aheight = query.size.height;
    awidth = query.size.width;

    return Scaffold(
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
                    width: awidth,
                    height: aheight,
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
                          prevCenterPoint: prevCenterPoint,
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
                          color: handState == HandState.NotTracking
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ),
                  ),
                  // Text(handState.name)
                ],
              ),
      ),
    );
  }

  void initApp() async {
    await getDirectory();
    //await service.init(awidth, aheight);
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
        applyFps: 30,
        transaction: BodyTransaction.hand,
        lensType: MLBodyLensController.backLens,
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
      viewportSize = Size(imgWidth, imgHeight);
    }
    catch(e){
      int i=0;
    }
  }

  void initSketch() {
    sketch = Sketch.simple(
      setup: (sketch) async {
        sketch.size(width: awidth.toInt() + 1, height: aheight.toInt() + 1);
        sketch.background(color: Colors.white);
      },
      draw: (sketch) async {
        if (handState == HandState.NotTracking)
          sketch.background(color: Colors.white);
        sketch.stroke(color: Colors.yellow);
        sketch.strokeWeight(3);
        /* sketch.line(
                      Offset(130, 100),
                      Offset(100, 30),
                    );*/
        if (handState == HandState.Tracking) {
          if (prevCenterPoint != null) {
            sketch.line(
              prevCenterPoint!,
              referencePoint!,
            );
            prevCenterPoint = Offset(referencePoint!.dx, referencePoint!.dy);
          }
        }
      },
    );
  }

  void onTransaction({dynamic result}) {
    int i = 0;
    //centerPoint = null;
    handRect = null;
    landmarks.clear();

    double normalSize = min(aheight, awidth);

    if (result.length == 0 || result[0].handKeyPoints.length != 21) {
      if (handState == HandState.Tracking) {
        abortFrames++;
        if (abortFrames == 20) {
          prevCenterPoint = null;
          handState = HandState.NotTracking;
          referencePoint = null;
        }
      } else {
        service.removeOverlay();
      }

      setState(() {});
      return;
    }
    abortFrames = 0;
    int startIndex = 0;

    computeData(result);

    service.drawHandLocation(referencePoint ?? Offset(0, 0));

    detect();

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
      double x = awidth -
          (max(0, (landmark.pointX - widthDif) as double) *
              awidth /
              viewportSize!.height);
      double y = (max(0, (landmark.pointY - heightDif) as double)) *
          aheight /
          viewportSize!.width;
      landmarks[landmark.type] = Offset(min(awidth, x), min(aheight, y));
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
    referencePoint = Offset(landmarks[0]!.dx - sumX, landmarks[0]!.dy - sumY);
    // referencePoint=Offset(landmarks[6]!.dx,landmarks[6]!.dy);
  }

  void detect() {
    List<List<dynamic>> list = [];
    //0-type
    //1-dx
    //2-dy
    for (var key in landmarks.keys) {
      list.add([
        key,
        landmarks[key]!.dx,
        landmarks[key]!.dy,
      ]);
    }

    list.sort((e1, e2) {
      double dist1 = sqrt(pow(e1[1] - referencePoint!.dx, 2) +
          pow(e1[2] - referencePoint!.dy, 2));
      double dist2 = sqrt(pow(e2[1] - referencePoint!.dx, 2) +
          pow(e2[2] - referencePoint!.dy, 2));
      if (dist1 < dist2) return 1;
      return 0;
    });

    if (handState == HandState.NotTracking) {
      if (isLockGesture()) {
        prevCenterPoint = Offset(referencePoint!.dx, referencePoint!.dy);
        handState = HandState.Tracking;

        service.clickScreen();

        /*String filePath = appDocDir.path + '/action.txt';
        filePath = filePath.replaceFirst("/app_flutter", "", 0);
        File(filePath).writeAsStringSync("Scroll");*/
      }
    } else {
      if (isFreeGesture()) {
        prevCenterPoint = null;
        handState = HandState.NotTracking;
      }
    }
  }

  bool isLockGesture() {
    bool ok = true;
    for (int i = 0; i < fingerLast.length; i++) {
      if (getDist(referencePoint!, landmarks[fingerLast[i]]!) >
          getDist(referencePoint!, landmarks[fingerSecondLast[i]]!)) {
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
      if (getDist(referencePoint!, landmarks[fingerLast[i]]!) <
          getDist(referencePoint!, landmarks[fingerSecondLast[i]]!)) {
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