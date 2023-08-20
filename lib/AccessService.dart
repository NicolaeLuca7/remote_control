
import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';

class AcccessService{
  static const platform = MethodChannel('app/gesture_control');
  bool _on=false;

  AccessService(){}

  Future<void> init(double awidth,double aheight) async{
    bool status =
    await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    if (!status) {
      status =
      await FlutterAccessibilityService.requestAccessibilityPermission();
      _on=true;
    }
    try {
      await platform.invokeMethod("init", [awidth.toInt(), aheight.toInt()]);
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> drawHandLocation(Offset centerPoint) async {
    if(!_on)
      return;
    try {
      await platform.invokeMethod("drawHandLocation",
          [centerPoint?.dx.toString(), centerPoint?.dy.toString()]);
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> removeOverlay() async {
    if(!_on)
      return;
    try {
      await platform.invokeMethod("removeOverlay");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> clickScreen() async {
    if(!_on)
      return;
    try {
      await platform.invokeMethod("click");
    } catch (e) {
      int i = 0;
    }
  }


}