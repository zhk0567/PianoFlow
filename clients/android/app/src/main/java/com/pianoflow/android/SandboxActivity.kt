package com.pianoflow.android

import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.pianoflow.android.practice.TonePlayer

/** 节拍器 · 试音 */
class SandboxActivity : AppCompatActivity() {
    private lateinit var tones: TonePlayer

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tones = TonePlayer(this)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
            setBackgroundColor(0xFF0B0E13.toInt())
        }
        layout.addView(TextView(this).apply { text = "节拍器 · 试音"; textSize = 22f; setTextColor(0xFFF5F2EB.toInt()) })
        layout.addView(Button(this).apply {
            text = "节拍器一下"
            setOnClickListener { tones.playMidi(60) }
        })
        layout.addView(SeekBar(this).apply {
            max = 100
            progress = 85
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar?, p: Int, fromUser: Boolean) {
                    tones.masterVolume = p / 100f
                }
                override fun onStartTrackingTouch(sb: SeekBar?) {}
                override fun onStopTrackingTouch(sb: SeekBar?) {}
            })
        })
        layout.addView(TextView(this).apply {
            text = "点按下方 MIDI 试音（60=C4）"
            setTextColor(0xFF9AA3B2.toInt())
            setOnClickListener { tones.playMidi(60) }
            setPadding(0, 24, 0, 0)
        })
        setContentView(layout)
    }

    override fun onDestroy() {
        tones.shutdown()
        super.onDestroy()
    }
}
