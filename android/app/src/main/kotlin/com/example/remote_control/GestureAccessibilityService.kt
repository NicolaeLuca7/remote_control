package com.example.remote_control

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.animation.ValueAnimator
import android.annotation.TargetApi
import android.graphics.*
import android.os.Build
import android.os.Looper
import android.view.*
import android.view.accessibility.AccessibilityEvent
import androidx.core.view.ViewCompat.setLayerType
import java.io.File
import java.lang.Math.PI
import java.lang.Math.acos
import java.lang.Math.cos
import java.lang.Math.pow
import java.lang.Math.sin
import java.lang.Math.sqrt
import java.util.Timer


@TargetApi(Build.VERSION_CODES.TIRAMISU)
class GestureAccessibilityService : AccessibilityService() {

    private var connected: Boolean = false

    var event: AccessibilityEvent? = null
    var view: View? = null

    var parameters:WindowManager.LayoutParams?=null

    var trackingView: View? = null
    var pressView: View? = null
    var gestureView: View? = null

    var referencePoint: PointF? = null
    var gestureStart: PointF = PointF(0F, 0F)

    var handState: HandState = HandState.NoData

    val gestureBackSide: Float = 20f
    val gestureHomeSide: Float = 50f
    var statusBarHeight: Float = 0f
    var displayWidth: Float = 0f
    var displayHeight: Float = 0f

    var appHeight: Int = 0
    var appWidth: Int = 0

    var resetTimer: Timer? = null


    companion object {
        lateinit var instance: GestureAccessibilityService
    }

    override fun onCreate() {
        instance = this
        super.onCreate()
    }

    override fun onInterrupt() {
        connected = false
    }

    override fun onAccessibilityEvent(ev: AccessibilityEvent) {
        event = ev

        if (view != null) {
            try {
                var windowManager =
                    getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager
                windowManager?.removeViewImmediate(view)
                view = null
            } catch (e: Exception) {
            }
        }

    }

    override fun onServiceConnected() {
        this.serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            packageNames = arrayOf("com.example.remote_control")
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            notificationTimeout = 100
        }

        var windowManager =
            getSystemService(WINDOW_SERVICE) as WindowManager

        val display: Display = windowManager.getDefaultDisplay()
        displayWidth = display.width.toFloat()
        displayHeight = display.height.toFloat()

        statusBarHeight = getResources().getDimensionPixelSize(
            getResources().getIdentifier(
                "status_bar_height",
                "dimen",
                "android"
            )
        ).toFloat()

        parameters = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.RGBA_8888,
        )

        trackingView = LayoutInflater.from(this)
            .inflate(com.example.remote_control.R.layout.tracking_view, null)

        pressView = LayoutInflater.from(this)
            .inflate(com.example.remote_control.R.layout.press_view, null)

        gestureView = LayoutInflater.from(this)
            .inflate(com.example.remote_control.R.layout.gesture_view, null)

        connected = true

        /* thread {
             startLoop()
         }*/

    }

    override fun onDestroy() {
        connected = false
        super.onDestroy()
    }

    fun isConnected(): Boolean {
        return connected
    }

    fun setAppSizes(width: Int, height: Int) {
        appWidth = width
        appHeight = height

    }

    fun convertX(x: Float): Float {
        return x * displayWidth.toFloat() / appWidth
    }

    fun convertY(y: Float): Float {
        return y * displayHeight.toFloat() / appHeight //+ statusBarHeight
    }

    fun unsureState() {
        referencePoint = null
        handState = HandState.Unsure
    }

    fun setGestureStart() {
        gestureStart = PointF(referencePoint!!.x, referencePoint!!.y)
    }

    fun drawHandLocation(x: Float, y: Float, handState: HandState) {
        this.handState = handState
        referencePoint = PointF(convertX(x), convertY(y))
        drawOverlay()
    }

    fun drawOverlay() {
        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager

        parameters!!.x = (referencePoint!!.x - displayWidth / 2).toInt()
        parameters!!.y = (referencePoint!!.y - displayHeight / 2).toInt()

        var newView:View

        if (handState == HandState.Press) {
            newView=pressView!!
        } else if (handState == HandState.Gesture) {
            newView=gestureView!!
        }
        else{
            newView=trackingView!!
        }

        if (view != null) {
            windowManager.updateViewLayout(
                newView,
                parameters
            ) //windowManager.removeViewImmediate(view)
        } else {
            windowManager.addView(newView, parameters)
        }

        view = newView
    }

    fun removeOverlay() {
        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager
        if (view != null) {
            try {
                windowManager?.removeViewImmediate(view)
                view = null
            } catch (e: Exception) {
            }
        }
    }

    fun click() {
        val builder = GestureDescription.Builder()
        val path = Path()
        path.moveTo(referencePoint!!.x, referencePoint!!.y + statusBarHeight)

        val duration = 1L // 0.001 second, for just click

        var displayId = event?.displayId

        var sc = SurfaceControl.CREATOR

        val gesture = builder.addStroke(
            GestureDescription.StrokeDescription(
                path,
                0L,
                duration,
                false
            )
        ).build()


        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription) {
                super.onCompleted(gestureDescription)
            }

            override fun onCancelled(gestureDescription: GestureDescription) {
                super.onCancelled(gestureDescription)
            }
        }, null)
    }

    fun executeGesture() {
        var gestureEnd = processPath(gestureStart, referencePoint!!)

        if (gestureStart.y == gestureEnd.y && (gestureStart.x <= gestureBackSide || gestureStart.x >= displayWidth - gestureBackSide)) {
            backGesture()
            return
        }
        if (gestureStart.x == gestureEnd.x && gestureStart.y >= displayHeight - gestureHomeSide) {
            homeGesture()
            return
        }

        val builder = GestureDescription.Builder()
        val path = Path()
        path.moveTo(gestureStart.x, gestureStart.y + statusBarHeight)
        path.lineTo(gestureEnd.x, gestureEnd.y + statusBarHeight)

        var displayId = event?.displayId
        var sc = SurfaceControl.CREATOR
        var duration = 30L;

        val gesture = builder.addStroke(
            GestureDescription.StrokeDescription(
                path,
                0L,
                duration,
            )
        ).build()

        dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription) {
                super.onCompleted(gestureDescription)
            }

            override fun onCancelled(gestureDescription: GestureDescription) {
                super.onCancelled(gestureDescription)
            }
        }, null)
    }

    fun processPath(gestureStart: PointF, gestureEnd: PointF): PointF {
        val tangent: Double = sqrt(
            pow((gestureEnd.x - gestureStart.x).toDouble(), 2.0) +
                    pow((gestureEnd.y - gestureStart.y).toDouble(), 2.0)
        )
        var angle: Double = acos((gestureEnd.x - gestureStart.x) / tangent)
        if (gestureStart.y > gestureEnd.y) {
            angle = 2 * PI - angle
        }
        val interval: Double = PI / 2
        val next = angle - angle % interval + interval
        if (angle % interval < next - angle) {
            angle -= angle % interval
        } else {
            angle = next
        }
        angle %= 2 * PI
        return PointF(
            gestureStart.x + cos(angle).toFloat() * tangent.toFloat(),
            gestureStart.y + sin(angle).toFloat() * tangent.toFloat()
        )
    }

    fun backGesture() {
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun homeGesture() {
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

}