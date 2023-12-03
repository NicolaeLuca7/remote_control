import 'dart:core';

import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:remote_control/shadowState.dart';

class CustomButton extends StatelessWidget {
  final Widget widget;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double borderWidth;
  final Offset shadowOffset;
  final double blurRadius;
  final Color shadowColor;
  final Color splashColor;
  final List<Color> backgroundColors;
  final List<Color> borderColors;
  final AlignmentGeometry backgroundBegining;
  final AlignmentGeometry backgroundEnd;
  final AlignmentGeometry borderBegining;
  final AlignmentGeometry borderEnd;
  final String toolTip;
  final void Function()? onPressed;
  final bool activated;

  const CustomButton(
      {required this.widget,
      required this.width,
      required this.height,
      required this.borderRadius,
      required this.activated,
      this.borderWidth = 0,
      this.shadowOffset = Offset.zero,
      this.blurRadius = 0.0,
      this.shadowColor = Colors.transparent,
      this.splashColor = Colors.transparent,
      this.backgroundColors = const [Colors.transparent, Colors.transparent],
      this.borderColors = const [Colors.transparent, Colors.transparent],
      this.backgroundBegining = Alignment.centerLeft,
      this.backgroundEnd = Alignment.centerRight,
      this.borderBegining = Alignment.centerLeft,
      this.borderEnd = Alignment.centerRight,
      this.toolTip = '',
      this.onPressed});

  @override
  Widget build(BuildContext context) {
    ShadowState shadowState = ShadowState.Out;
    if (backgroundColors.length == 1) {
      backgroundColors.add(backgroundColors[0]);
    }
    if (borderColors.length == 1) {
      borderColors.add(borderColors[0]);
    }
    LinearGradient gradient = LinearGradient(
        colors: backgroundColors,
        begin: backgroundBegining,
        end: backgroundEnd);
    LinearGradient borderGradient = LinearGradient(
        colors: borderColors, begin: borderBegining, end: borderEnd);
    //
    return Tooltip(
      textStyle: TextStyle(fontSize: 17),
      message: toolTip,
      child: SizedBox(
        height: height,
        width: width,
        child: LayoutBuilder(
          builder: (context, contrains) {
            return Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: borderRadius,
                border: GradientBoxBorder(
                  gradient: borderGradient,
                  width: borderWidth,
                ),
              ),
              child: StatefulBuilder(builder: (context, state) {
                //
                return Stack(children: [
                  AnimatedContainer(
                    onEnd: () {
                      if (shadowState.name == 'Out') return;

                      shadowState = ShadowState.Out;
                      state(() {});
                    },
                    duration: Duration(milliseconds: 150),
                    height: height,
                    width: width,
                    child: Center(child: widget),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: borderRadius,
                      boxShadow: [
                        BoxShadow(
                            color: shadowColor,
                            blurRadius:
                                !(shadowState.name == 'In') ? blurRadius : 0.1,
                            offset: shadowOffset,
                            blurStyle: BlurStyle.outer)
                      ],
                    ),
                  ),
                  Center(
                    child: Container(
                      height: height,
                      width: width,
                      decoration: BoxDecoration(
                        color: activated
                            ? Colors.transparent
                            : Colors.black.withOpacity(0.5),
                        borderRadius: borderRadius,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: borderRadius,
                        child: InkWell(
                          borderRadius: borderRadius,
                          splashColor: splashColor,
                          onTap: () {
                            if (!activated) return;
                            shadowState = (shadowState.name == 'Out'
                                ? ShadowState.In
                                : ShadowState.Out);
                            state(() {});
                            if (onPressed != null) onPressed!();
                          },
                        ),
                      ),
                    ),
                  ),
                ]);
              }),
            );
          },
        ),
      ),
    );
  }
}
