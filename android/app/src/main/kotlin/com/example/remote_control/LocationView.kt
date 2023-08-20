import android.content.Context
import android.graphics.*
import android.view.View


class LocationView(mas: Context?,x:Float,y:Float) : View(mas) {
    private val paint = Paint()
    private var xPos:Float
    private var yPos:Float

    init {
        xPos=x
        yPos=y
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        paint.color=Color.WHITE
        canvas.drawCircle(xPos,yPos,30f,paint)
    }

}