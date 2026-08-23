package com.pianoflow.android

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.SwitchCompat
import com.pianoflow.android.data.UserStore

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = UserStore(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
            setBackgroundColor(0xFF0B0E13.toInt())
        }
        root.addView(
            TextView(this).apply {
                text =
                    "曲库含正式校对谱与 OMR 草稿；草稿未逐音校对，勿当教材。\n\n" +
                    "PianoFlow Android · 功能对齐 Windows · 布局为手机优化。"
                textSize = 15f
                setTextColor(0xFF9AA3B2.toInt())
            },
        )
        root.addView(
            SwitchCompat(this).apply {
                text = "视觉特效（命中环/光柱）"
                textSize = 16f
                setTextColor(0xFFE8EDF4.toInt())
                isChecked = store.getVisualFxEnabled()
                setPadding(0, 32, 0, 0)
                setOnCheckedChangeListener { _, on -> store.setVisualFxEnabled(on) }
            },
        )
        setContentView(root)
    }
}
