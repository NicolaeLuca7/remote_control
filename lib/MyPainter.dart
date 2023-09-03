import 'package:flutter/material.dart';

import 'HandState.dart';

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
     /* canvas.drawCircle(
          centerPoint!,
          10,
          paint
            ..color = Colors.yellow.withOpacity(0.5)
            ..style = PaintingStyle.fill);*/
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
