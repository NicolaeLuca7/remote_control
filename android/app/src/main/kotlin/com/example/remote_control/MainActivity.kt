package com.example.remote_control

import android.animation.ValueAnimator
import android.graphics.PointF
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app/gesture_control"

    var service: GestureAccessibilityService? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "sendToBackground") {
                moveTaskToBack(true)
            }

            //
            else if (call.method == "init") {
                try {
                    var width = (call.arguments as List<Int>)[0]
                    var height = (call.arguments as List<Int>)[1]

                    service = GestureAccessibilityService.instance
                    service?.setAppSizes(width, height)

                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "setGestureSpeed") {
                try {
                    var speed = (call.arguments as List<Long>)[0]
                    service?.setGestureSpeed(speed)
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "getGestureSpeed") {
                try {
                    var speed = service?.getGestureSpeed()
                    result.success(speed)
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "checkConnection") {
                try {
                    if (service == null) {
                        result.success(false.toString())
                    } else {
                        var status = service?.isConnected()
                        result.success(status.toString())
                    }
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "drawHandLocation") {
                try {
                    var x = (call.arguments as List<String>)[0].toFloat()
                    var y = (call.arguments as List<String>)[1].toFloat()

                    var handState = HandState.valueOf((call.arguments as List<String>)[2])

                    service?.drawHandLocation(x, y, handState)
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "click") {
                try {
                    service?.click()
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "setGestureStart") {
                try {
                    service?.setGestureStart()
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "executeGesture") {
                try {
                    service?.executeGesture()
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "unsureState") {
                try {
                    service?.unsureState()
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
            //
            else if (call.method == "removeOverlay") {
                try {
                    service?.removeOverlay()
                    result.success("Succes")
                } catch (e: Exception) {
                    handleException(result, e)
                }
            }
        }
    }

    fun handleException(result: MethodChannel.Result, e: Exception) {
        var message = ""
        if (e.message != null) {
            message = e.message!!
        }
        result.error("Error", message, null)
    }

}
