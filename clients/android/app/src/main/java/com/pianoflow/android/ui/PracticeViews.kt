package com.pianoflow.android.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import com.pianoflow.android.practice.Hand
import com.pianoflow.android.practice.ScoreNote

/** Shared 88-key geometry (A0–C8) for waterfall + keyboard. */
class KeyboardGeo(val contentWidthPx: Float) {
    val startMidi = 21
    val whiteKeyCount = 52
    val whiteMidis: List<Int>
    val blackMidis: List<Int>
    private val whiteLefts: FloatArray
    private val whiteWidths: FloatArray
    val whiteWidth: Float
    val blackWidth: Float

    init {
        val whites = ArrayList<Int>(whiteKeyCount)
        var m = startMidi
        while (whites.size < whiteKeyCount) {
            if (!isBlack(m)) whites.add(m)
            m++
        }
        whiteMidis = whites
        val total = contentWidthPx.coerceAtLeast(1f)
        val base = (total / whiteKeyCount).toInt().coerceAtLeast(1).toFloat()
        val rem = (total - base * whiteKeyCount).toInt().coerceIn(0, whiteKeyCount)
        whiteWidths = FloatArray(whiteKeyCount) { i -> if (i < rem) base + 1f else base }
        whiteLefts = FloatArray(whiteKeyCount)
        var x = 0f
        for (i in 0 until whiteKeyCount) {
            whiteLefts[i] = x
            x += whiteWidths[i]
        }
        whiteWidth = base
        blackWidth = whiteWidth * 0.62f
        blackMidis = (whiteMidis.first()..whiteMidis.last()).filter { isBlack(it) }
    }

    fun whiteLeft(i: Int) = whiteLefts[i]
    fun whiteW(i: Int) = whiteWidths[i]

    fun midiCenterX(midi: Int): Float? {
        if (midi !in whiteMidis.first()..whiteMidis.last()) return null
        if (isBlack(midi)) {
            val left = blackLeft(midi) ?: return null
            return left + blackWidth / 2f
        }
        val i = whiteMidis.indexOf(midi)
        if (i < 0) return null
        return whiteLeft(i) + whiteW(i) / 2f
    }

    fun blackLeft(midi: Int): Float? {
        if (!isBlack(midi)) return null
        val leftWhite = whiteMidis.indexOfFirst { it > midi } - 1
        if (leftWhite < 0) return null
        return whiteLeft(leftWhite + 1) - blackWidth / 2f
    }

    companion object {
        fun isBlack(midi: Int): Boolean {
            val pc = midi % 12
            return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10
        }

        /** Phone: fit 88 keys to viewport width — no horizontal scroll. */
        fun contentWidthFor(context: Context, viewportPx: Int): Float {
            return viewportPx.coerceAtLeast(1).toFloat()
        }
    }
}

class FallingNotesView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private var notes: List<ScoreNote> = emptyList()
    private var positionBeats = 0f
    private var geo: KeyboardGeo? = null
    private val bgPaint = Paint()
    private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x18FFFFFF
        strokeWidth = 1f
    }
    private val hitPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xE6FFD078.toInt()
        strokeWidth = 3f
    }
    private val notePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tmp = RectF()

    fun setGeometry(geo: KeyboardGeo) {
        this.geo = geo
        requestLayout()
        invalidate()
    }

    fun setState(notes: List<ScoreNote>, positionBeats: Float) {
        this.notes = notes
        this.positionBeats = positionBeats
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val g = geo
        val w = g?.contentWidthPx?.toInt()?.coerceAtLeast(1)
            ?: MeasureSpec.getSize(widthMeasureSpec).coerceAtLeast(1)
        val hMode = MeasureSpec.getMode(heightMeasureSpec)
        val hSize = MeasureSpec.getSize(heightMeasureSpec)
        val h = when (hMode) {
            MeasureSpec.EXACTLY -> hSize
            MeasureSpec.AT_MOST -> hSize.coerceAtLeast(120)
            else -> TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                200f,
                resources.displayMetrics,
            ).toInt()
        }
        setMeasuredDimension(w, h)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val g = geo ?: return
        val h = height.toFloat()
        val w = g.contentWidthPx
        bgPaint.shader = LinearGradient(
            0f, 0f, 0f, h,
            intArrayOf(0xFF0A121A.toInt(), 0xFF15202B.toInt()),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, w, h, bgPaint)
        bgPaint.shader = null

        // Octave grid
        for (i in g.whiteMidis.indices) {
            if (g.whiteMidis[i] % 12 == 0) {
                val x = g.whiteLeft(i)
                canvas.drawLine(x, 0f, x, h, gridPaint)
            }
        }

        val hitY = h * 0.86f
        canvas.drawLine(0f, hitY, w, hitY, hitPaint)
        // soft glow under hit line
        hitPaint.alpha = 40
        canvas.drawRect(0f, hitY - 6f, w, hitY + 6f, hitPaint)
        hitPaint.alpha = 230

        val lookAhead = 4f
        for (n in notes) {
            val dy = ((n.start - positionBeats) / lookAhead).toFloat()
            if (dy < -0.25f || dy > 1.25f) continue
            val y = hitY - dy * h * 0.82f
            val cx = g.midiCenterX(n.midi) ?: continue
            val nw = if (KeyboardGeo.isBlack(n.midi)) {
                g.blackWidth * 0.85f
            } else {
                g.whiteWidth * 0.72f
            }
            val nh = (n.duration / lookAhead * h * 0.55f).toFloat().coerceIn(14f, h * 0.45f)
            // Hand identity only (match Flutter AppColors) — never voice/staff;
            // Hand.Both shares RH so both-hands mode stays two hues.
            val color = when (n.hand) {
                Hand.Left -> 0xFFF2A06D.toInt()
                Hand.Right, Hand.Both -> 0xFF4EB6C8.toInt()
            }
            notePaint.color = color
            tmp.set(cx - nw / 2f, y - nh, cx + nw / 2f, y)
            canvas.drawRoundRect(tmp, 4f, 4f, notePaint)
            // top highlight
            notePaint.color = Color.argb(60, 255, 255, 255)
            tmp.set(cx - nw / 2f, y - nh, cx + nw / 2f, y - nh + 4f)
            canvas.drawRoundRect(tmp, 4f, 4f, notePaint)
        }
    }
}

class MiniKeyboardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    private var pressed: Set<Int> = emptySet()
    private var geo: KeyboardGeo? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val tmp = RectF()

    fun setGeometry(geo: KeyboardGeo) {
        this.geo = geo
        requestLayout()
        invalidate()
    }

    fun setPressed(midi: Set<Int>) {
        pressed = midi
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val g = geo
        val w = g?.contentWidthPx?.toInt()?.coerceAtLeast(1)
            ?: MeasureSpec.getSize(widthMeasureSpec).coerceAtLeast(1)
        val h = when (MeasureSpec.getMode(heightMeasureSpec)) {
            MeasureSpec.EXACTLY -> MeasureSpec.getSize(heightMeasureSpec)
            else -> TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                112f,
                resources.displayMetrics,
            ).toInt()
        }
        setMeasuredDimension(w, h)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val g = geo ?: return
        val h = height.toFloat()
        for (i in g.whiteMidis.indices) {
            val midi = g.whiteMidis[i]
            val lit = midi in pressed
            paint.style = Paint.Style.FILL
            paint.color = if (lit) 0xFFFFD078.toInt() else 0xFFF4F0E8.toInt()
            val l = g.whiteLeft(i)
            val r = l + g.whiteW(i) - 1.2f
            tmp.set(l, 0f, r, h)
            canvas.drawRoundRect(tmp, 0f, 0f, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.2f
            paint.color = 0xFF9AA3AD.toInt()
            canvas.drawRect(l, 0f, r, h, paint)
        }
        for (midi in g.blackMidis) {
            val l = g.blackLeft(midi) ?: continue
            val lit = midi in pressed
            paint.style = Paint.Style.FILL
            paint.color = if (lit) 0xFFFFB84D.toInt() else 0xFF1A1F26.toInt()
            tmp.set(l, 0f, l + g.blackWidth, h * 0.62f)
            canvas.drawRoundRect(tmp, 3f, 3f, paint)
        }
    }
}
