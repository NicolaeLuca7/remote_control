import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
//import 'package:flutter_processing/flutter_processing.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:huawei_ml_body/huawei_ml_body.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:remote_control/HandBorders.dart';
import 'package:remote_control/HandState.dart';
import 'package:remote_control/AccessService.dart';
import 'package:remote_control/customButton.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MyPainter.dart';

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

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  AccessService service = AccessService();

  int? textureId;
  int cameraIndex = 1;
  int stateCounter = 0;
  int initStep = 0;
  int cnt = 0;
  int gestureSpeed = 0;

  double aheight = 0, awidth = 0;
  double frameRate = 60;
  double maxFrames = 10000;
  double xdif = 0, ydif = 0;

  HandBorders leftHandBorders = HandBorders();
  HandBorders rightHandBorders = HandBorders();

  Size? imageSize;
  Size? viewportSize;
  Size? modifiedViewport;

  var hController;

  Animation<double>? transition;
  AnimationController? transitionController;

  MLBodyLensEngine? engine;

  bool processing = false;
  bool loading = true;
  bool hasData = false;

  bool updatePoint = true;

  bool guideFollowed = false;
  bool presentApp = false;

  InputImageRotation? rotation;

  String path = '';
  String initError = '';

  Offset? centerPoint;
  Offset? referencePoint;
  Offset? prevReferencePoint;
  Offset? startingPoint;
  Offset? transitionStart;

  Rect? handRect = Rect.fromLTRB(0, 0, 0, 0);

  Map<int, Offset> landmarks = {};

  List<int> fingerLast = [4, 8, 12, 16, 20];
  List<int> fingerSecondLast = [3, 7, 11, 15, 19];

  HandState prevState = HandState.NoData;
  HandState handState = HandState.NoData;

  final keyCustomPaint = GlobalKey();

  //late Sketch sketch;

  late Directory appDocDir;

  Timer? timer;

  Timer? appLoop;
  int updateRate = 60; //hz

  double cursorSpeed = 0.12; //seconds

  Stopwatch stopwatch = Stopwatch();

  SharedPreferences? prefs;

  Color blackColor = Color.fromARGB(255, 40, 43, 48);
  Color accentColor = Colors.deepPurple;

  List<String> textList1 = [
    ''' ● The app is based on an accessibility service. 
Please make sure you give the app the permissions it needs.''',
    ''' ● When opening the app you will be prompted to turn on the accessibility service and give camera access.''',
    ''' ● The service will work as long as you have the app opened in the background.''',
    ''' ● To preserve battery life turn off the service after each use.''',
    ''' ● To turn the service on/off go to: Settings -> Accessibility -> Installed apps -> Remote Control''',
    ''' ● In the case of another app accessing the camera, the app will stop. However the accessibility service will continue to run.''',
    ''' ● In the case of the app stopping and the pointer remaining stuck on the screen, turn the accessibility service off.''',
    ''' ● Currently the app only works for portrait orientation.''',
  ];

  List<String> textList2 = [
    ''' ● The screen pointer is controlled by the movements of the hand that is parallel to the screen.
For the best performance the hand needs to be around 25 cm away from the screen.
Performance may vary from the lighting conditions.''',
    ''' ● For just tracking keep the hand opened.''',
    ''' ● To enter the gesture state slightly close the hand.
Once the pointer becomes green you are in the click state. Opening the hand in this state will trigger a click in the pointer's location.''',
    ''' ● If you keep the hand closed, the service will shift to the continuous gesture state, represented by a blue pointer.
Opening the hand in this state will trigger a swipe between the pointer's location where the state started and the last location.'''
    //''' ● ''',
  ];

  int guideScreen = 0;

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp,
    ]);
    initApp();
    super.initState();
  }

  @override
  void dispose() {
    transitionController?.dispose();
    service.stop();
    engine!.release();
    super.dispose();
  }

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
        backgroundColor: blackColor,
        body: Container(
          child: loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Colors.black,
                  ),
                )
              : initError != ''
                  ? Center(
                      child: Container(
                        height: 200,
                        width: min(300, awidth * 0.9),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListView(
                          children: [
                            Center(
                              child: Text(
                                'Error',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 30),
                              ),
                            ),
                            SizedBox(
                              height: 30,
                            ),
                            Center(
                              child: Text(
                                initError,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                            SizedBox(
                              height: 30,
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton(
                                onPressed: () {
                                  guideScreen=0;
                                  loading = true;
                                  setState(() {});
                                  initApp();
                                },
                                child: Text(
                                  "Try again",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  : presentApp
                      ? getGuideScreen()
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            /*Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                height: aheight,
                                width: awidth,
                                child: Processing(
                                  sketch: sketch,
                                ),
                              ),
                            ),*/
                            Container(
                              color: blackColor,
                              height: aheight,
                              width: awidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  //
                                  SizedBox(
                                    height: 20,
                                  ),
                                  //
                                  SizedBox(
                                    width: awidth,
                                    height: 40,
                                    child: Row(
                                      children: [
                                        Spacer(),
                                        IconButton(
                                          tooltip: "Instructions",
                                          onPressed: () {
                                            guideScreen=0;
                                            service.removeOverlay();
                                            service.pause();
                                            presentApp=true;
                                            setState(() {});
                                          },
                                          icon: Icon(
                                            Icons.info_outline_rounded,
                                            color: accentColor,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  //
                                  Spacer(),
                                  //
                                  Text(
                                    "Cursor speed:",
                                    style: TextStyle(
                                        color: accentColor, fontSize: 20),
                                  ),
                                  SizedBox(
                                    width: min(350, awidth),
                                    height: 50,
                                    child: Slider(
                                      max: 0.24,
                                      min: 0.05,
                                      activeColor: accentColor,
                                      value:(0.24 - cursorSpeed).clamp(0.05, 0.24),
                                      onChanged: (val) {
                                        cursorSpeed = 0.24 - val;
                                      },
                                    ),
                                  ),
                                  //
                                  SizedBox(
                                    height: 50,
                                  ),
                                  //
                                  Text(
                                    "Gesture speed:",
                                    style: TextStyle(
                                        color: accentColor, fontSize: 20),
                                  ),
                                  SizedBox(
                                    width: min(350, awidth),
                                    height: 50,
                                    child: Slider(
                                      max: 18,
                                      min: 1,
                                      activeColor: accentColor,
                                      value: (18 - gestureSpeed.toDouble()).clamp(1, 18),
                                      onChanged: (val) {
                                        gestureSpeed = 18 - val.toInt();
                                      },
                                      onChangeEnd: (val) {
                                        gestureSpeed = 18 - val.toInt();
                                        service.setGestureSpeed(gestureSpeed);
                                      },
                                    ),
                                  ),
                                  //
                                  Spacer(),
                                  //
                                ],
                              ),
                            ),
                            /*MLBodyLens(
                          textureId: textureId,
                          //width: awidth,
                          //height: aheight,
                        ),*/
                            /*Align(
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
                        ),*/
                            // Text(handState.name)
                          ],
                        ),
        ),
      ),
    );
  }


  void initApp() async {
    bool status;
    int currentStep = 1;
    initError = "";

    if (initStep < currentStep) {
      status = await initPreferences();
      if (!status) {
        initError = "The service could not start";
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }
    if (!guideFollowed) {
      presentApp = true;
      loading = false;
      setState(() {});
      return;
    }

    currentStep++;

    if (initStep < currentStep) {
      status = await getDirectory();
      if (!status) {
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }

    currentStep++;

    if (initStep < currentStep) {
      status = await getCameraPermission();
      if (!status) {
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }

    currentStep++;

    if (initStep < currentStep) {
      status = await service.init(awidth, aheight);
      if (!status) {
        initError = "The service could not start";
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }

    currentStep++;

    if (initStep < currentStep) {
      gestureSpeed = await service.getGestureSpeed();
      initStep = currentStep;
    }

    currentStep++;

    if (initStep < currentStep) {
      status = await initStream();
      if (!status) {
        initError = "The camera stream could not start";
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }

    currentStep++;

    if (initStep < currentStep) {
      try {
        initSketch();
        initStep = currentStep;
      } catch (e) {
        initError = "The sketch could not start";
        loading = false;
        setState(() {});
        return;
      }
    }

    currentStep++;

    if (initStep < currentStep) {
      status = initTransition();
      if (!status) {
        initError = "The transition could not start";
        loading = false;
        setState(() {});
        return;
      }
      initStep = currentStep;
    }

    currentStep++;

    runLoop();
    loading = false;
    setState(() {});
  }

  Future<bool> initPreferences() async {
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs == null) {
        return false;
      }
      dynamic state = prefs!.get("guideFollowed");
      if (state == null) {
        state = false;
      }
      guideFollowed = state;
    } catch (e) {
      return false;
    }
    return true;
  }

  Future<bool> getCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isRestricted) {
      initError = "Camera access is restricted";
      return false;
    } else if (status.isPermanentlyDenied) {
      initError = "Camera access is permanently denied";
      return false;
    } else if (status.isDenied) {
      status = (await Permission.camera.request());
      if (status.isRestricted) {
        initError = "Camera access is restricted";
        return false;
      }
      if (status.isDenied) {
        initError = "Camera access was denied";
        return false;
      } else if (status.isPermanentlyDenied) {
        initError = "Camera access is permanently denied";
        return false;
      }
    }
    return true;
  }

  Future<bool> getDirectory() async {
    try {
      appDocDir = await getApplicationDocumentsDirectory();
      String filePath = appDocDir.path + '/action.txt';
      filePath = filePath.replaceFirst("/app_flutter", "", 0);
      File(filePath).writeAsStringSync("NoAction");
    } catch (e) {
      initError = "The application directory could not be obtained";
      return false;
    }
    return true;
  }

  Future<bool> initStream() async {
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

      double leftBorder = viewportSize!.width * 0.5;
      double rightBorder = viewportSize!.width * 0.3;
      double topBorder = viewportSize!.height * 0.4;
      double bottomBorder = viewportSize!.height * 0.15;

      leftHandBorders =
          HandBorders(leftBorder, rightBorder, topBorder, bottomBorder);
      rightHandBorders =
          HandBorders(leftBorder, rightBorder, topBorder, bottomBorder);

      modifiedViewport = Size(viewportSize!.width - leftBorder - rightBorder,
          viewportSize!.height - topBorder - bottomBorder);
    } catch (e) {
      return false;
    }
    return true;
  }

  void initSketch() {
    /*sketch = Sketch.simple(
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

        //Offset p1, p2;

        /*p1 = convertPoint(Offset(widthDif, heightDif));
        p2 = convertPoint(Offset(viewportSize!.width - widthDif, heightDif));
        sketch.line(p1, p2);

        p1 = convertPoint(Offset(viewportSize!.width - widthDif, heightDif));
        p2 = convertPoint(Offset(
            viewportSize!.width - widthDif, viewportSize!.height - heightDif));
        sketch.line(p1, p2);

        p1 = convertPoint(Offset(
            viewportSize!.width - widthDif, viewportSize!.height - heightDif));
        p2 = convertPoint(Offset(widthDif, viewportSize!.height - heightDif));
        sketch.line(p1, p2);

        p1 = convertPoint(Offset(widthDif, viewportSize!.height - heightDif));
        p2 = convertPoint(Offset(widthDif, heightDif));
        sketch.line(p1, p2);*/

        /* sketch.line(
                      Offset(130, 100),
                      Offset(100, 30),
                    );*/
        if (prevReferencePoint != null) {
          /* sketch.line(
            prevReferencePoint!,
            referencePoint!,
          );*/
          prevReferencePoint = Offset(referencePoint!.dx, referencePoint!.dy);
        }
      },
    );*/
  }

  bool initTransition() {
    try {
      transitionController = AnimationController(
          duration: const Duration(milliseconds: 125), vsync: this);
      transition =
          Tween<double>(begin: 0, end: 1).animate(transitionController!)
            ..addListener(() {
              referencePoint = Offset(
                  transitionStart!.dx + transition!.value * xdif,
                  transitionStart!.dy + transition!.value * ydif);
            });
    } catch (e) {
      return false;
    }
    return true;
  }


  void markGuide() async {
    guideFollowed = true;
    presentApp = false;
    await prefs?.setBool('guideFollowed', guideFollowed);
  }

  Widget getGuideScreen() {
    return Container(
        height: aheight,
        width: awidth,
        color: blackColor,
        child: guideScreen == 0
            ? ListView(
                children: [
                  SizedBox(
                    height: 30,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      "Instructions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 55,
                  ),
                  for (String text in textList1)
                    Padding(
                      padding: EdgeInsets.only(
                          left: 30, top: 5, bottom: 5, right: 10),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 40,
                  ),
                  SizedBox(
                    height: 70,
                    width: awidth,
                    child: Row(
                      children: [
                        Spacer(),
                        CustomButton(
                            widget: Text(
                              "Next",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 25),
                            ),
                            backgroundColors: [Colors.deepPurple],
                            shadowColor: blackColor,
                            blurRadius: 3,
                            width: 90,
                            height: 50,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () {
                              guideScreen++;
                              setState(() {});
                            },
                            activated: true),
                        SizedBox(
                          width: 20,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                ],
              )
            : ListView(
                controller: ScrollController(),
                children: [
                  SizedBox(
                    height: 30,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Text(
                      "How to use",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 55,
                  ),
                  for (String text in textList2)
                    Padding(
                      padding: EdgeInsets.only(
                          left: 30, top: 5, bottom: 5, right: 10),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 40,
                  ),
                  SizedBox(
                    height: 70,
                    width: awidth,
                    child: Row(
                      children: [
                        Spacer(),
                        CustomButton(
                          widget: Text(
                            "Start",
                            style: TextStyle(color: Colors.white, fontSize: 25),
                          ),
                          backgroundColors: [Colors.deepPurple],
                          shadowColor: blackColor,
                          blurRadius: 3,
                          width: 90,
                          height: 50,
                          borderRadius: BorderRadius.circular(10),
                          activated: true,
                          onPressed: () {
                            if (!guideFollowed) {
                              markGuide();
                              loading = true;
                              setState(() {});
                              initApp();
                            } else {
                              presentApp = false;
                              service.resume();
                              setState(() {});
                            }
                          },
                        ),
                        SizedBox(
                          width: 20,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                ],
              ));
  }

  void runLoop() {
    appLoop =
        Timer.periodic(Duration(milliseconds: 1000 ~/ updateRate), (timer) {
//
      if (transitionStart != null) {
        referencePoint =
            Offset(transitionStart!.dx + xdif, transitionStart!.dy + ydif);
      }
      if (referencePoint != null) {
        service.drawHandLocation(referencePoint!, handState);
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
            service.unsureState();
            break;
          }
          if (stateCounter.toDouble() >=
              transitionDuration[HandState.Press]! * updateRate) {
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
              transitionDuration[HandState.NoData]! * updateRate) {
            handState = HandState.NoData;
            transitionController?.reset();
            prevReferencePoint = null;
            referencePoint = null;
            transitionStart = null;
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
            //startTimeout();
            service.clickScreen();
            handState = HandState.Unsure;
            service.unsureState();
            break;
          }

          if (isFreeGesture()) {
            //startTimeout();
            service.clickScreen();
            handState = HandState.Tracking;
            break;
          }

          if (stateCounter.toDouble() >=
              transitionDuration[HandState.Gesture]! * updateRate) {
            handState = HandState.Gesture;
            stopwatch.start();
            service.setGestureStart();
            //startingPoint = Offset(referencePoint!.dx, referencePoint!.dy);
            break;
          }

          break;

        ////

        case HandState.Gesture:
          if (!hasData) {
            stopwatch.stop();
            stopwatch.reset();
            //startTimeout();
            service.executeGesture();
            handState = HandState.Unsure;
            service.unsureState();
            break;
          }

          if (isFreeGesture()) {
            //startTimeout();
            service.executeGesture();
            stopwatch.stop();
            stopwatch.reset();
            handState = HandState.Tracking;
            break;
          }

          break;
      }

      HandState tempState = HandState.values
          .firstWhere((element) => element.name == handState.name);

      if (prevState.name != handState.name) {
        stateCounter = 1;
      } else {
        stateCounter++;
        if (stateCounter > maxFrames) {
          handState = HandState.NoData;
          stateCounter = 1;
        }
      }
      prevState = tempState;
    });
  }

  void startTimeout() {
    updatePoint = false;
    var timeout = Timer(Duration(milliseconds: 200), () {
      updatePoint = true;
    });
  }

  void onTransaction({dynamic result}) {
    int i = 0;
    //centerPoint = null;
    handRect = null;
    landmarks.clear();

    cnt++;

    double normalSize = min(aheight, awidth);
    hasData = false;

    if (result.length == 0 || result[0].handKeyPoints.length != 21) {
    } else {
      if (updatePoint) {
        computeData(result);
        hasData = true;
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

    double leftBorder;
    double rightBorder;
    double topBorder;
    double bottomBorder;

    if (isLeftHand()) {
      leftBorder = leftHandBorders.leftBorder;
      rightBorder = leftHandBorders.rightBorder;
      topBorder = leftHandBorders.topBorder;
      bottomBorder = leftHandBorders.bottomBorder;
    } else {
      leftBorder = rightHandBorders.leftBorder;
      rightBorder = rightHandBorders.rightBorder;
      topBorder = rightHandBorders.topBorder;
      bottomBorder = rightHandBorders.bottomBorder;
    }

    if (x <= leftBorder) {
      x = 0;
    } else if (x >= viewportSize!.width - rightBorder) {
      x = modifiedViewport!.width;
    } else {
      x -= leftBorder;
    }

    if (y <= topBorder) {
      y = 0;
    } else if (y >= viewportSize!.height - bottomBorder) {
      y = modifiedViewport!.height;
    } else {
      y -= topBorder;
    }

    x = x / modifiedViewport!.width * awidth;
    y = y / modifiedViewport!.height * aheight;

    if (referencePoint == null) {
      referencePoint = Offset(x, y);
    } else {
      transitionStart = Offset(referencePoint!.dx, referencePoint!.dy);
      xdif = (x - transitionStart!.dx) / (updateRate * cursorSpeed);
      ydif = (y - transitionStart!.dy) / (updateRate * cursorSpeed);
      //setTransitionPoint(Offset(x, y));
    }
  }

  void setTransitionPoint(Offset p) {
    transitionStart = Offset(referencePoint!.dx, referencePoint!.dy);
    xdif = p.dx - transitionStart!.dx;
    ydif = p.dy - transitionStart!.dy;
    transitionController?.reset();
    transitionController?.forward();
  }

  bool isLeftHand() => (landmarks[4]!.dx >= landmarks[20]!.dx);

  Offset convertPoint(Offset point) => Offset(
      point.dx / viewportSize!.width * awidth,
      point.dy / viewportSize!.height * aheight);

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
