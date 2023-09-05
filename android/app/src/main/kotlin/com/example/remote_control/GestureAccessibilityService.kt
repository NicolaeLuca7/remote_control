package com.example.remote_control

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.annotation.SuppressLint
import android.annotation.TargetApi
import android.graphics.*
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.DrawableContainer
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import androidx.core.content.res.ResourcesCompat
import java.lang.Math.PI
import java.lang.Math.acos
import java.lang.Math.cos
import java.lang.Math.pow
import java.lang.Math.sin
import java.lang.Math.sqrt
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit


@TargetApi(Build.VERSION_CODES.TIRAMISU)
class GestureAccessibilityService : AccessibilityService() {

    private var connected: Boolean = false

    private var event: AccessibilityEvent? = null
    private var view: View? = null

    private var parameters: WindowManager.LayoutParams? = null

    private var trackingBackground: GradientDrawable? = null
    private var trackingView: View? = null

    private var referencePoint: PointF? = null
    private var gestureStart: PointF = PointF(0F, 0F)

    private var handState: HandState = HandState.NoData

    private val gestureBackSide: Float = 20f
    private val gestureHomeSide: Float = 50f
    private var statusBarHeight: Float = 0f
    private var displayWidth: Float = 0f
    private var displayHeight: Float = 0f

    private var appHeight: Int = 0
    private var appWidth: Int = 0

    private var gestureSpeed: Long = 90

    private var lastUpdate: LocalDateTime? = null


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

        var now = LocalDateTime.now()
        if (ChronoUnit.MILLIS.between(lastUpdate, now) > 1000) {
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
    }

    @SuppressLint("ResourceType")
    override fun onServiceConnected() {
        this.serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            packageNames = arrayOf("com.example.remote_control")
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            notificationTimeout = 100
        }

        lastUpdate = LocalDateTime.now()

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

        var mouse = trackingView?.findViewById<Button>(com.example.remote_control.R.id.mouse)

        var drawableRes: Drawable? = mouse?.background

        val drawableContainerState: DrawableContainer.DrawableContainerState =
            drawableRes?.constantState as DrawableContainer.DrawableContainerState

        val children: Array<Drawable> = drawableContainerState.children

        trackingBackground = children[0] as GradientDrawable

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

    fun setGestureSpeed(speed: Long) {
        gestureSpeed = speed * 10
    }

    fun getGestureSpeed(): Long {
        return gestureSpeed / 10
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
        lastUpdate = LocalDateTime.now()

        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager

        parameters!!.x = (referencePoint!!.x - displayWidth / 2).toInt()
        parameters!!.y = (referencePoint!!.y - displayHeight / 2).toInt()


        if (handState == HandState.Press) {
            trackingBackground?.setColor(Color.parseColor("#CC41B74D"))
        } else if (handState == HandState.Gesture) {
            trackingBackground?.setColor(Color.parseColor("#CC167DD0"))
        } else { //Just Tracking
            trackingBackground?.setColor(Color.parseColor("#CCdbdad5"))
        }

        if (view != null) {
            windowManager.updateViewLayout(
                trackingView,
                parameters
            ) //windowManager.removeViewImmediate(view)
        } else {
            windowManager.addView(trackingView, parameters)
        }

        view = trackingView
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

        val duration = 1L // 0.001 seconds, for just click

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
        var duration = gestureSpeed

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