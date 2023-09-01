package com.example.remote_control

import LocationView
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

    var referencePoint: PointF? = null
    var transitionStart: PointF? = null
    var gestureStart: PointF = PointF(0F, 0F)

    var handState: HandState = HandState.NoData

    var xdif: Float = 0f
    var ydif: Float = 0f
    val gestureBackSide: Float = 20f
    val gestureHomeSide: Float = 50f
    var statusBarHeight: Float = 0f
    var displayWidth: Float = 0f
    var displayHeight: Float = 0f

    var appHeight: Int = 0
    var appWidth: Int = 0

    var resetTimer: Timer? = null

    lateinit var transition: ValueAnimator


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
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager
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

    fun initTransition() {
        transition = ValueAnimator.ofFloat(0f, 1f)
        transition.duration = 250 // Duration in milliseconds

        transition.addUpdateListener { current ->
            if ((current.animatedValue as Float) > 0f && (current.animatedValue as Float) < 1f) {
                var i = 0
            }
            referencePoint = PointF(
                transitionStart!!.x + (current.animatedValue as Float) * xdif,
                transitionStart!!.y + (current.animatedValue as Float) * ydif
            )
            drawOverlay()
        }
    }

    fun unsureState() {
        transition.cancel()
        transitionStart = null
        referencePoint = null
        handState = HandState.Unsure
    }

    fun setGestureStart() {
        gestureStart = PointF(referencePoint!!.x, referencePoint!!.y)
    }

    fun drawHandLocation(x: Float, y: Float, handState: HandState) {
        this.handState = handState

        /*if (referencePoint != null) {
            transitionStart = PointF(referencePoint!!.x, referencePoint!!.y)
            xdif = x - referencePoint!!.x
            ydif = y - referencePoint!!.y
            transition.cancel()
            transition.start()
            return
        }*/
        referencePoint = PointF(convertX(x), convertY(y))
        drawOverlay()
        //(view as LocationView).setBackgroundColor(Color.GREEN)

    }

    fun drawOverlay() {
        var color = Color.WHITE
        if (handState == HandState.Press) {
            color = Color.GREEN
        } else if (handState == HandState.Gesture) {
            color = Color.BLUE
        }

        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager

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

        var parameters = WindowManager.LayoutParams(
            displayWidth.toInt(),
            displayHeight.toInt(),
            0,
            0,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )

        var newView = LocationView(baseContext, referencePoint!!.x, referencePoint!!.y, color)

        if (view != null) {
            windowManager.removeViewImmediate(view)
        }

        windowManager.addView(newView, parameters)

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

    fun checkChanges() {
        try {
            var name = event?.packageName

            var filePath = getApplicationInfo().dataDir;
            if (filePath == null)
                return;

            filePath += "/action.txt";
            var file = File(filePath)

            var action = file.readText()


            if (action == "Scroll") {
                file.writeText("NoAction")

                val builder = GestureDescription.Builder()
                val path = Path()
                path.moveTo(200f, 700f)
                path.lineTo(200f, 100f)

                val duration = 500L // 0.5 second

                var displayId = event?.displayId

                var sc = SurfaceControl.CREATOR


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
        } catch (e: Exception) {
            var i = 0
        }
    }

    fun startLoop() {
        Looper.prepare()

    }


}