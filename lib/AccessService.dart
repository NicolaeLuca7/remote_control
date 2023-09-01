import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:remote_control/HandState.dart';

class AccessService {
  static const platform = MethodChannel('app/gesture_control');
  bool _on = false;

  AccessService() {}

  Future<bool> init(double awidth, double aheight) async {
    await FlutterAccessibilityService.requestAccessibilityPermission();
    bool status = bool.parse(await platform.invokeMethod("checkConnection"));

    try {
      await platform.invokeMethod("init", [awidth.toInt(), aheight.toInt()]);
      _on = true;
    } catch (e) {
      return false;
    }

    return true;
  }

  Future<void> stop() async {
    _on = false;
    try {
      await platform.invokeMethod("removeOverlay");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> drawHandLocation(
      Offset referencePoint, HandState handState) async {
    if (!_on) return;
    try {
      await platform.invokeMethod("drawHandLocation", [
        referencePoint?.dx.toString(),
        referencePoint?.dy.toString(),
        handState.name
      ]);
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> removeOverlay() async {
    if (!_on) return;
    try {
      await platform.invokeMethod("removeOverlay");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> clickScreen() async {
    if (!_on) return;
    try {
      await platform.invokeMethod("click");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> setGestureStart() async {
    if (!_on) return;
    try {
      await platform.invokeMethod("setGestureStart");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> executeGesture() async {
    if (!_on) return;
    try {
      await platform.invokeMethod("executeGesture");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> unsureState() async {
    if (!_on) return;
    try {
      await platform.invokeMethod("unsureState");
    } catch (e) {
      int i = 0;
    }
  }
}
