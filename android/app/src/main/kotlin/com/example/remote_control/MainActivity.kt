package com.example.remote_control

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "app/gesture_control"



  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    var service:GestureAccessibilityService?=null;

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->

      if (call.method == "sendToBackground") {
        moveTaskToBack(true)
      }
      //
      else if(call.method=="init"){
        try {
          var width = (call.arguments as List<Int>)[0]
          var height = (call.arguments as List<Int>)[1]

          service = GestureAccessibilityService.instance
          service?.setAppSizes(width, height)
          result.success("Succes")
        }
        catch (e:Exception){
          handleException(result,e)
        }
      }
      //
      else if(call.method=="drawHandLocation"){
        try {
          var x = (call.arguments as List<String>)[0].toFloat()
          var y = (call.arguments as List<String>)[1].toFloat()

          var handState= HandState.valueOf((call.arguments as List<String>)[2]);

          service?.drawHandLocation(x, y,handState)
          result.success("Succes")
        }
        catch (e:Exception){
          handleException(result,e)
        }
      }
      //
      else if(call.method=="click"){
        try {
          service?.click()
          result.success("Succes")
        }
        catch (e:Exception){
          handleException(result,e)
        }
      }
      //
      else if(call.method=="executeGesture"){
        try{
          var startX = (call.arguments as List<String>)[0].toFloat()
          var startY = (call.arguments as List<String>)[1].toFloat()
          var endX = (call.arguments as List<String>)[2].toFloat()
          var endY = (call.arguments as List<String>)[3].toFloat()
          var duration = (call.arguments as List<String>)[4].toLong()

          service?.executeGesture(startX, startY,endX,endY)
          result.success("Succes")
        }
        catch (e:Exception){
          handleException(result,e)
        }
      }
      //
      else if(call.method=="removeOverlay"){
        try {
          service?.removeOverlay()
          result.success("Succes")
        }
        catch (e:Exception){
          handleException(result,e)
        }
      }
    }
  }

  fun handleException(result: MethodChannel.Result,e:Exception){
    var message=""
    if(e.message!=null){
      message= e.message!!
    }
    result.error("Error",message,null)
  }


}
