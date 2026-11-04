package com.pianoflow.android

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.pianoflow.android.practice.MicPitchTracker

/** 音高识别测试（Basic Pitch → Poly-YIN / YIN） */
class PitchTestActivity : AppCompatActivity() {
    private var mic: MicPitchTracker? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val engine = TextView(this).apply {
            text = "引擎: …"
            textSize = 14f
            setTextColor(0xFF9AA3B2.toInt())
            setPadding(48, 48, 48, 8)
        }
        val label = TextView(this).apply {
            text = "对着麦克风演奏…"
            textSize = 18f
            setTextColor(0xFFF5F2EB.toInt())
            setPadding(48, 8, 48, 48)
        }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF0B0E13.toInt())
            addView(engine)
            addView(label)
        }
        setContentView(layout)
        mic = MicPitchTracker(
            context = this,
            onNoteOns = { midis, _ ->
                runOnUiThread {
                    label.text = "noteOn: ${midis.sorted().joinToString(", ")}"
                }
            },
            onFrame = { midis, _, _ ->
                runOnUiThread {
                    if (midis.isNotEmpty()) {
                        label.text = "识别: ${midis.sorted().joinToString(", ")}"
                    }
                }
            },
            onError = { msg -> runOnUiThread { label.text = msg } },
            onEngine = { name -> runOnUiThread { engine.text = "引擎: $name" } },
        )
        mic?.start()
    }

    override fun onDestroy() {
        mic?.stop()
        super.onDestroy()
    }
}
