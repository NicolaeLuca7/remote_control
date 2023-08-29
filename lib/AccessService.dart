
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:remote_control/HandState.dart';

class AccessService{
  static const platform = MethodChannel('app/gesture_control');
  bool _on=false;

  AccessService(){}

  Future<void> init(double awidth,double aheight) async{
    bool status =
    await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    if (!status) {
      status =
      await FlutterAccessibilityService.requestAccessibilityPermission();
    }

    try {
      await platform.invokeMethod("init", [awidth.toInt(), aheight.toInt()]);
      _on = true;
    } catch (e) {
      int i = 0;
    }

  }

  Future<void> stop() async{
    _on=false;
    try {
      await platform.invokeMethod("removeOverlay");
    } catch (e) {
      int i = 0;
    }
  }

  Future<void> drawHandLocation(Offset referencePoint,HandState handState) async {
    if(!_on)
      return;
    try {
      await platform.invokeMethod("drawHandLocation",
          [referencePoint?.dx.toString(), referencePoint?.dy.toString(),handState.name]);
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

  Future<void> executeGesture(Offset startingPoint,Offset endingPoint,int duration) async {
    if(!_on)
      return;
    try {
      endingPoint=processPath(startingPoint,endingPoint);
      await platform.invokeMethod("executeGesture",[startingPoint.dx.toString(),startingPoint.dy.toString(),endingPoint.dx.toString(),endingPoint.dy.toString(),duration.toString()]);
    } catch (e) {
      int i = 0;
    }
  }

  Offset processPath(Offset startingPoint,Offset endingPoint){

    double tangent=sqrt(pow(endingPoint.dx-startingPoint.dx,2)+pow(endingPoint.dy-startingPoint.dy,2));
    double angle=acos((endingPoint.dx-startingPoint.dx)/tangent);

    if(startingPoint.dy>endingPoint.dy){
      angle=2*pi-angle;
    }

    double interval=pi/2;
    double next=angle-angle%interval+interval;

    if(angle%interval<next-angle){
      angle-=angle%interval;
    }
    else{
      angle=next;
    }
    angle%=2*pi;

    return Offset(startingPoint.dx+cos(angle)*tangent,startingPoint.dy+sin(angle)*tangent);
  }


}