package com.example.remote_control

import LocationView
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.annotation.TargetApi
import android.graphics.*
import android.os.Build
import android.os.Looper
import android.provider.CalendarContract
import android.view.*
import android.view.accessibility.AccessibilityEvent
import java.io.File
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo


@TargetApi(Build.VERSION_CODES.TIRAMISU)
class GestureAccessibilityService : AccessibilityService() {

    var event: AccessibilityEvent? = null
    var view: View? = null

    var handX:Float=0f
    var handY:Float=0f
    val gestureBackSide:Float=10f
    val gestureHomeSide:Float=25f

    var appHeight:Int=0
    var appWidth:Int=0


    companion object {
        lateinit var instance:GestureAccessibilityService
    }

    override fun onCreate() {
        instance=this
        super.onCreate()
    }

    override fun onInterrupt() {

    }


    override fun onAccessibilityEvent(ev: AccessibilityEvent) {
        event = ev
    }

    fun setAppSizes(width:Int,height:Int){
        appWidth=width
        appHeight=height

    }

    fun drawHandLocation(x:Float,y:Float,handState:HandState ){
        var color=Color.WHITE
        if(handState==HandState.Press){
            color= Color.GREEN
        }
        else if(handState==HandState.Gesture){
            color=Color.BLUE;
        }


        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager
        val display: Display = windowManager.getDefaultDisplay()
        val displayWidth = display.width
        val displayHeight = display.height

        handX=x*displayWidth.toFloat()/appWidth
        handY=y*displayHeight.toFloat()/appHeight

        var parameters = WindowManager.LayoutParams(
            displayWidth,
            displayHeight,
            0,
            0,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )

        var newView=LocationView(baseContext,handX,handY,color)

        if (view != null) {
            windowManager?.removeViewImmediate(view)
        }

        windowManager.addView(newView, parameters)

        view =newView

        //(view as LocationView).setBackgroundColor(Color.GREEN)

    }

    fun removeOverlay(){
        var windowManager =
            getSystemService(AccessibilityService.WINDOW_SERVICE) as WindowManager
        if (view != null){
            try {
                windowManager?.removeViewImmediate(view)
            }
            catch (e:Exception) {}
            view=null;
        }
    }

    fun click(){
        val builder = GestureDescription.Builder()
        val path = Path()
        path.moveTo(handX,handY)

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

    fun executeGesture(startX:Float,startY:Float,endX:Float,endY:Float){

        if(startY==endY&&(startX<=gestureBackSide||startX>=appWidth-gestureBackSide)){
            backGesture()
            return
        }

        if(startX==endX&&startY>=appHeight-gestureHomeSide){
            homeGesture()
            return
        }


        val builder = GestureDescription.Builder()
        val path = Path()
        path.moveTo(startX,startY)
        path.lineTo(endX,  endY)

        var displayId = event?.displayId

        var sc = SurfaceControl.CREATOR

        var duration=30L;

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

    fun backGesture(){
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun homeGesture(){
       performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onServiceConnected() {
        this.serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            packageNames = arrayOf("com.example.remote_control")
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            notificationTimeout = 100
        }

       /* thread {
            startLoop()
        }*/

    }

    override fun onDestroy() {
        super.onDestroy()
    }

    fun checkChanges(){
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
        }catch (e:Exception){
            var i=0
        }
    }

    fun startLoop() {
        Looper.prepare()

    }


}