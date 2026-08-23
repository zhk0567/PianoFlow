package com.pianoflow.android.data

import org.json.JSONArray
import org.json.JSONObject
import java.util.regex.Pattern

/** Client-side MusicXML → practice JSON (userImport quality). */
object WorkshopImport {
    const val HONESTY_MIDI =
        "工坊 MIDI 导入（可跟弹；MIDI→MusicXML 会丢声部/记谱细节，质量档为自导入，非教材级正式谱）。"

    fun importMusicXml(xml: String, fileName: String, store: UserStore): SongSummary {
        val id = "user_${fileName.replace(Regex("[^a-zA-Z0-9\\u4e00-\\u9fff]"), "_").take(30)}_${System.currentTimeMillis().toString(36).takeLast(4)}"
        val title = titleFromXml(xml, fileName)
        val bpm = bpmFromXml(xml)
        val notes = parseNotes(xml)
        if (notes.isEmpty()) throw IllegalStateException("未解析到音符")
        val scoreJson = JSONObject()
        scoreJson.put("id", id)
        scoreJson.put("title", title)
        scoreJson.put("bpm", bpm)
        scoreJson.put("timeSignature", JSONObject().put("num", 4).put("den", 4))
        scoreJson.put("keySignature", 0)
        val arr = JSONArray()
        for (n in notes) {
            arr.put(
                JSONObject()
                    .put("midi", n.midi)
                    .put("start", n.start)
                    .put("duration", n.duration)
                    .put("hand", if (n.midi < 60) "left" else "right"),
            )
        }
        scoreJson.put("notes", arr)
        val catalog = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("artist", "自导入")
            .put("genre", "用户导入")
            .put("difficulty", 2)
            .put("bpm", bpm)
            .put("scoreKind", "userImport")
            .put("asset", "user/$id.json")
            .put("description", "工坊 MusicXML 导入（自导入质量档）")
        store.saveUserImport(id, catalog, scoreJson.toString(2), xml)
        return SongSummary(
            id = id,
            title = title,
            artist = "自导入",
            scoreKind = "userImport",
            genre = "用户导入",
            difficulty = 2,
            bpm = bpm.toDouble(),
            jsonAsset = "user/$id.json",
        )
    }

    private data class N(val midi: Int, val start: Double, val duration: Double)

    private fun parseNotes(xml: String): List<N> {
        val div = Pattern.compile("<divisions>\\s*(\\d+)\\s*</divisions>", Pattern.CASE_INSENSITIVE)
            .matcher(xml).let { if (it.find()) it.group(1)!!.toInt().coerceAtLeast(1) else 1 }
        val blocks = Regex("<note[\\s\\S]*?</note>", RegexOption.IGNORE_CASE).findAll(xml)
        var cursor = 0.0
        val out = mutableListOf<N>()
        for (m in blocks) {
            val block = m.value
            val chord = Regex("<chord[\\s/>]", RegexOption.IGNORE_CASE).containsMatchIn(block)
            val rest = Regex("<rest[\\s/>]", RegexOption.IGNORE_CASE).containsMatchIn(block)
            val dur = Regex("<duration>\\s*(\\d+)\\s*</duration>", RegexOption.IGNORE_CASE)
                .find(block)?.groupValues?.get(1)?.toInt()?.div(div.toDouble()) ?: 1.0
            if (rest) {
                if (!chord) cursor += dur
                continue
            }
            val step = Regex("<step>\\s*([A-G])\\s*</step>", RegexOption.IGNORE_CASE).find(block)?.groupValues?.get(1)
            val octave = Regex("<octave>\\s*(-?\\d+)\\s*</octave>", RegexOption.IGNORE_CASE).find(block)?.groupValues?.get(1)?.toInt()
            val alter = Regex("<alter>\\s*(-?\\d+)\\s*</alter>", RegexOption.IGNORE_CASE).find(block)?.groupValues?.get(1)?.toInt() ?: 0
            if (step != null && octave != null) {
                val midi = stepToMidi(step, octave, alter)
                val onset = if (chord && out.isNotEmpty()) out.last().start else cursor
                out.add(N(midi, onset, dur.coerceAtLeast(0.05)))
                if (!chord) cursor += dur
            } else if (!chord) cursor += dur
        }
        return out.sortedWith(compareBy({ it.start }, { it.midi }))
    }

    private fun stepToMidi(step: String, octave: Int, alter: Int): Int {
        val base = mapOf("C" to 0, "D" to 2, "E" to 4, "F" to 5, "G" to 7, "A" to 9, "B" to 11)[step.uppercase()] ?: 0
        return (octave + 1) * 12 + base + alter
    }

    private fun titleFromXml(xml: String, fallback: String): String {
        val m = Regex("<work-title[^>]*>([^<]+)</work-title>", RegexOption.IGNORE_CASE).find(xml)
            ?: Regex("<movement-title[^>]*>([^<]+)</movement-title>", RegexOption.IGNORE_CASE).find(xml)
        return m?.groupValues?.get(1)?.trim()?.ifEmpty { fallback } ?: fallback
    }

    private fun bpmFromXml(xml: String): Int {
        val m = Regex("tempo=\"([\\d.]+)\"", RegexOption.IGNORE_CASE).find(xml)
        return m?.groupValues?.get(1)?.toDoubleOrNull()?.toInt() ?: 72
    }
}
