package com.pianoflow.android.data

import org.json.JSONArray
import org.json.JSONObject

/** MIDI → draft MusicXML + practice JSON (userImport). Port of scripts/midi_to_musicxml_draft.py */
object MidiImport {
    private val steps = arrayOf("C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B")
    private val alters = intArrayOf(0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0)

    data class NoteEv(val start: Int, val end: Int, val midi: Int, val velocity: Int)

    fun importBytes(bytes: ByteArray, fileName: String, store: UserStore): SongSummary {
        val (notes, ppq, bpm, timeSig) = parseMidi(bytes)
        val title = fileName.substringBeforeLast('.')
        val xml = midiToMusicXml(notes, ppq, bpm, timeSig, title)
        val id = "user_midi_${fileName.replace(Regex("[^a-zA-Z0-9\\u4e00-\\u9fff]"), "_").take(30)}_${System.currentTimeMillis().toString(36).takeLast(4)}"
        val scoreJson = JSONObject()
        scoreJson.put("id", id)
        scoreJson.put("title", title)
        scoreJson.put("bpm", bpm)
        scoreJson.put("timeSignature", JSONObject().put("num", timeSig.first).put("den", timeSig.second))
        scoreJson.put("keySignature", 0)
        val arr = JSONArray()
        for (n in notes) {
            val start = n.start.toDouble() / ppq
            val dur = ((n.end - n.start).coerceAtLeast(1)).toDouble() / ppq
            arr.put(
                JSONObject()
                    .put("midi", n.midi)
                    .put("start", start)
                    .put("duration", dur.coerceAtLeast(0.05))
                    .put("hand", if (n.midi < 60) "left" else "right"),
            )
        }
        scoreJson.put("notes", arr)
        val catalog = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("artist", "MIDI导入")
            .put("genre", "用户导入")
            .put("difficulty", 2)
            .put("bpm", bpm)
            .put("scoreKind", "userImport")
            .put("asset", "user/$id.json")
            .put("description", WorkshopImport.HONESTY_MIDI)
        store.saveUserImport(id, catalog, scoreJson.toString(2), xml)
        return SongSummary(id, title, "MIDI导入", "userImport", "用户导入", 2, bpm.toDouble(), "user/$id.json", true)
    }

    private fun parseMidi(raw: ByteArray): Parsed {
        if (raw.size < 14 || String(raw, 0, 4) != "MThd") throw IllegalStateException("不是标准 MIDI 文件")
        val headerLen = u32be(raw, 4)
        val ntrks = u16be(raw, 10)
        val division = u16be(raw, 12)
        if (division and 0x8000 != 0) throw IllegalStateException("不支持 SMPTE MIDI")
        val ppq = division
        var i = 8 + headerLen
        val all = mutableListOf<NoteEv>()
        var tempoUs: Int? = null
        var timeSig: Pair<Int, Int>? = null
        repeat(ntrks) {
            if (String(raw, i, 4) != "MTrk") throw IllegalStateException("MTrk 缺失")
            val tlen = u32be(raw, i + 4)
            val track = raw.copyOfRange(i + 8, i + 8 + tlen)
            i += 8 + tlen
            val p = parseTrack(track)
            all.addAll(p.notes)
            if (p.tempoUs != null && tempoUs == null) tempoUs = p.tempoUs
            if (p.timeSig != null && timeSig == null) timeSig = p.timeSig
        }
        if (all.isEmpty()) throw IllegalStateException("MIDI 中无音符")
        var bpm = 120
        tempoUs?.let { if (it > 0) bpm = (60000000.0 / it).toInt().coerceIn(30, 240) }
        val ts = timeSig ?: (4 to 4)
        all.sortWith(compareBy({ it.start }, { it.midi }))
        return Parsed(all, ppq, bpm, ts)
    }

    private data class Parsed(val notes: List<NoteEv>, val ppq: Int, val bpm: Int, val timeSig: Pair<Int, Int>)
    private data class TrackParsed(val notes: List<NoteEv>, val tempoUs: Int?, val timeSig: Pair<Int, Int>?)

    private fun parseTrack(data: ByteArray): TrackParsed {
        var i = 0
        var absTick = 0
        var running: Int? = null
        val active = mutableMapOf<Pair<Int, Int>, Pair<Int, Int>>()
        val notes = mutableListOf<NoteEv>()
        var tempoUs: Int? = null
        var timeSig: Pair<Int, Int>? = null
        while (i < data.size) {
            val (delta, ni) = readVlq(data, i)
            i = ni
            absTick += delta
            if (i >= data.size) break
            var status = data[i].toInt() and 0xFF
            if (status and 0x80 != 0) {
                i++
                running = status
            } else {
                status = running ?: throw IllegalStateException("running status")
            }
            if (status == 0xFF) {
                if (i >= data.size) break
                val meta = data[i++].toInt() and 0xFF
                val (len, ni2) = readVlq(data, i)
                i = ni2 + len
                if (meta == 0x2F) break
                if (meta == 0x51 && len == 3) {
                    val p = data.copyOfRange(i - len, i)
                    tempoUs = ((p[0].toInt() and 0xFF) shl 16) or ((p[1].toInt() and 0xFF) shl 8) or (p[2].toInt() and 0xFF)
                } else if (meta == 0x58 && len >= 2) {
                    val p = data.copyOfRange(i - len, i)
                    timeSig = (p[0].toInt() and 0xFF) to (1 shl (p[1].toInt() and 0xFF))
                }
                continue
            }
            if (status == 0xF0 || status == 0xF7) {
                val (len, ni2) = readVlq(data, i)
                i = ni2 + len
                continue
            }
            val msg = status and 0xF0
            val ch = status and 0x0F
            if (msg == 0x90 || msg == 0x80) {
                if (i + 1 >= data.size) break
                val a = data[i].toInt() and 0xFF
                val b = data[i + 1].toInt() and 0xFF
                i += 2
                val key = ch to a
                if (msg == 0x90) {
                    if (b == 0) {
                        active.remove(key)?.let { (st, vel) -> notes.add(NoteEv(st, absTick, a, vel)) }
                    } else active[key] = absTick to b
                } else {
                    active.remove(key)?.let { (st, vel) -> notes.add(NoteEv(st, absTick, a, vel)) }
                }
            } else if (msg == 0xC0 || msg == 0xD0) i++ else break
        }
        for ((k, v) in active) notes.add(NoteEv(v.first, maxOf(v.first + 1, absTick), k.second, v.second))
        return TrackParsed(notes, tempoUs, timeSig)
    }

    private fun readVlq(data: ByteArray, start: Int): Pair<Int, Int> {
        var value = 0
        var i = start
        while (i < data.size) {
            val b = data[i++].toInt() and 0xFF
            value = (value shl 7) or (b and 0x7F)
            if (b < 0x80) return value to i
        }
        throw IllegalStateException("VLQ")
    }

    private fun u16be(b: ByteArray, o: Int) = ((b[o].toInt() and 0xFF) shl 8) or (b[o + 1].toInt() and 0xFF)
    private fun u32be(b: ByteArray, o: Int) =
        ((b[o].toInt() and 0xFF) shl 24) or ((b[o + 1].toInt() and 0xFF) shl 16) or
            ((b[o + 2].toInt() and 0xFF) shl 8) or (b[o + 3].toInt() and 0xFF)

    private fun midiToMusicXml(notes: List<NoteEv>, ppq: Int, bpm: Int, timeSig: Pair<Int, Int>, title: String): String {
        val (beats, beatType) = timeSig
        val divisions = ppq.coerceAtLeast(1)
        val ticksPerMeasure = maxOf(1, (ppq * beats * (4.0 / beatType)).toInt())
        val cleaned = notes.map { n -> if (n.end > n.start) n else n.copy(end = n.start + maxOf(1, ppq / 4)) }
        val maxTick = cleaned.maxOf { it.end }
        val measureCount = maxOf(1, (maxTick + ticksPerMeasure - 1) / ticksPerMeasure)
        val sb = StringBuilder()
        sb.append("""<?xml version="1.0" encoding="UTF-8"?><score-partwise version="3.1"><work><work-title>$title</work-title></work><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list><part id="P1">""")
        for (mi in 0 until measureCount) {
            val mStart = mi * ticksPerMeasure
            val mEnd = mStart + ticksPerMeasure
            val inM = cleaned.filter { it.start in mStart until mEnd }
            sb.append("<measure number=\"${mi + 1}\">")
            if (mi == 0) {
                sb.append("<attributes><divisions>$divisions</divisions><time><beats>$beats</beats><beat-type>$beatType</beat-type></time></attributes>")
                sb.append("<direction><sound tempo=\"$bpm\"/></direction>")
            }
            val byOnset = inM.groupBy { it.start - mStart }
            var cursor = 0
            for (onset in byOnset.keys.sorted()) {
                val delta = (onset - cursor).coerceAtLeast(0)
                if (delta > 0) sb.append("<forward><duration>$delta</duration></forward>")
                val chord = byOnset[onset]!!.sortedBy { it.midi }
                chord.forEachIndexed { ci, n ->
                    val dur = maxOf(1, n.end - n.start)
                    val m = n.midi.coerceIn(21, 108)
                    val octave = m / 12 - 1
                    val pc = m % 12
                    sb.append("<note>")
                    if (ci > 0) sb.append("<chord/>")
                    sb.append("<pitch><step>${steps[pc]}</step>")
                    if (alters[pc] != 0) sb.append("<alter>${alters[pc]}</alter>")
                    sb.append("<octave>$octave</octave></pitch><duration>$dur</duration></note>")
                }
                cursor = onset
            }
            sb.append("</measure>")
        }
        sb.append("</part></score-partwise>")
        return sb.toString()
    }
}
