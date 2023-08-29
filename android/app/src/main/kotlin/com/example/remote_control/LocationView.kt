import android.content.Context
import android.graphics.*
import android.view.View


class LocationView(mas: Context?,x:Float,y:Float,color:Int) : View(mas) {
    private val paint = Paint()
    private var xPos:Float
    private var yPos:Float
    private var color:Int

    init {
        xPos=x
        yPos=y
        this.color=color
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        paint.color=color
        canvas.drawCircle(xPos,yPos,30f,paint)
    }

}