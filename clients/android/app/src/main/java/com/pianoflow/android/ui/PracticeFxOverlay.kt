package com.pianoflow.android.ui

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator

/** Hit burst rings — display only. Port of practice_visual_fx_overlay.dart (simplified). */
class PracticeFxOverlay @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private data class Burst(val cx: Float, val hue: Int, val combo: Int, val born: Long)

    var fxEnabled: Boolean = true
        set(v) { field = v; if (!v) bursts.clear(); invalidate() }

    private val bursts = mutableListOf<Burst>()
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val pillarPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 36f
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#E8A849")
    }
    private var animator: ValueAnimator? = null

    init {
        setWillNotDraw(false)
        startLoop()
    }

    private fun startLoop() {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 980L
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener { prune(); invalidate() }
            start()
        }
    }

    fun hit(cx: Float, perfect: Boolean, combo: Int) {
        if (!fxEnabled) return
        val hue = if (perfect) Color.parseColor("#FFD078") else Color.parseColor("#8FD4FF")
        bursts.add(Burst(cx, hue, combo, System.currentTimeMillis()))
        invalidate()
    }

    private fun prune() {
        val now = System.currentTimeMillis()
        bursts.removeAll { now - it.born > 980L }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!fxEnabled) return
        prune()
        val now = System.currentTimeMillis()
        val y = height * 0.92f
        for (b in bursts) {
            val t = ((now - b.born) / 980f).coerceIn(0f, 1f)
            val a = 1f - t
            val r = 18f + t * 48f + if (b.combo >= 5) 12f else 0f
            ringPaint.color = b.hue
            ringPaint.alpha = (a * 220).toInt()
            ringPaint.strokeWidth = 3f - t * 1.5f
            canvas.drawCircle(b.cx, y, r, ringPaint)
            pillarPaint.color = b.hue
            pillarPaint.alpha = (a * 90).toInt()
            val pw = 10f + t * 6f
            canvas.drawRect(b.cx - pw / 2f, y - height * 0.55f, b.cx + pw / 2f, y, pillarPaint)
            if (b.combo >= 3 && t < 0.35f) {
                textPaint.alpha = (a * 255).toInt()
                canvas.drawText("${b.combo}", b.cx, y - 28f, textPaint)
            }
        }
    }

    override fun onDetachedFromWindow() {
        animator?.cancel()
        super.onDetachedFromWindow()
    }
}
