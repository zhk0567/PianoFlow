package com.pianoflow.android

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.pianoflow.android.data.CatalogRepository
import com.pianoflow.android.data.UserStore
import org.json.JSONObject

/** 练习星座 — 点亮练过的曲子 */
class ConstellationActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = UserStore(this)
        val repo = CatalogRepository(assets, store)
        val songs = repo.loadSongs().associateBy { it.id }
        val stats = store.getStats().optJSONObject("bySong") ?: JSONObject()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }
        layout.addView(TextView(this).apply {
            text = "练习星座"
            textSize = 24f
            setTextColor(0xFFF5F2EB.toInt())
        })
        var count = 0
        val keys = stats.keys()
        while (keys.hasNext()) {
            val id = keys.next()
            val o = stats.getJSONObject(id)
            if (!o.optBoolean("lit") && o.optInt("sessions") <= 0) continue
            val s = songs[id] ?: continue
            count++
            layout.addView(TextView(this).apply {
                text = "★ ${s.title}"
                textSize = 16f
                setPadding(0, 16, 0, 0)
                setTextColor(0xFFE8A849.toInt())
                setOnClickListener {
                    startActivity(
                        android.content.Intent(this@ConstellationActivity, PracticeActivity::class.java)
                            .putExtra(PracticeActivity.EXTRA_ID, s.id),
                    )
                }
            })
        }
        if (count == 0) {
            layout.addView(TextView(this).apply {
                text = "还没有点亮的曲子"
                setTextColor(0xFF9AA3B2.toInt())
            })
        }
        layout.setBackgroundColor(0xFF0B0E13.toInt())
        setContentView(layout)
    }
}
