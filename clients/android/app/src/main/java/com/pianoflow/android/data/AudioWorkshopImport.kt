package com.pianoflow.android.data

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min
import kotlin.math.roundToInt

/** Audio → userImport draft (Poly-YIN / optional ONNX later). No Demucs on device. */
object AudioWorkshopImport {
    const val HONESTY =
        "工坊音频转录草稿（非正式精确谱；Android Poly-YIN 转练习 JSON，禁止冒充正式谱）。Demucs/Basic Pitch 完整链路请用 Windows。"

    fun importFile(ctx: Context, path: String, fileName: String, store: UserStore): SongSummary {
        val pcm = decodeToMono22050(path)
        if (pcm.size < 22050 / 2) throw IllegalStateException("音频太短")
        val events = transcribe(pcm)
        if (events.isEmpty()) throw IllegalStateException("未识别到音符")
        val title = fileName.substringBeforeLast('.')
        val bpm = 72
        val id = "user_audio_${fileName.replace(Regex("[^a-zA-Z0-9\\u4e00-\\u9fff]"), "_").take(30)}_${System.currentTimeMillis().toString(36).takeLast(4)}"
        val notesJson = JSONArray()
        for (e in events) {
            notesJson.put(
                JSONObject()
                    .put("midi", e.midi)
                    .put("start", e.start)
                    .put("duration", e.duration)
                    .put("hand", if (e.midi < 60) "left" else "right"),
            )
        }
        val scoreJson = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("bpm", bpm)
            .put("timeSignature", JSONObject().put("num", 4).put("den", 4))
            .put("keySignature", 0)
            .put("notes", notesJson)
        val xmlText = buildMinimalXml(title, bpm, events)
        val catalog = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("artist", "音频导入")
            .put("genre", "用户导入")
            .put("difficulty", 2)
            .put("bpm", bpm)
            .put("scoreKind", "userImport")
            .put("asset", "user/$id.json")
            .put("description", HONESTY)
        store.saveUserImport(id, catalog, scoreJson.toString(2), xmlText)
        return SongSummary(id, title, "音频导入", "userImport", "用户导入", 2, bpm.toDouble(), "user/$id.json", true)
    }

    private data class Ev(val midi: Int, val start: Double, val duration: Double)

    private fun transcribe(pcm: ShortArray): List<Ev> {
        val hop = 2048
        val out = mutableListOf<Ev>()
        var i = 0
        while (i < pcm.size) {
            val end = min(i + 4096, pcm.size)
            val slice = pcm.copyOfRange(i, end)
            val midis = com.pianoflow.android.practice.PolyYinPitch.midisFromPcm16(slice, 22050, 0.16)
            val beat = (i / 22050.0) * 2.0
            for (m in midis) out.add(Ev(m, beat, 0.2))
            i += hop
        }
        return out
    }

    private fun buildMinimalXml(title: String, bpm: Int, events: List<Ev>): String {
        val sb = StringBuilder()
        sb.append("""<?xml version="1.0" encoding="UTF-8"?><score-partwise version="3.1"><work><work-title>$title</work-title></work><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>480</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes><direction><sound tempo="$bpm"/></direction>""")
        for (e in events.sortedBy { it.start }) {
            val dur = (e.duration * 480).roundToInt().coerceAtLeast(1)
            val octave = e.midi / 12 - 1
            val pc = e.midi % 12
            val steps = arrayOf("C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B")
            sb.append("<note><pitch><step>${steps[pc]}</step><octave>$octave</octave></pitch><duration>$dur</duration></note>")
        }
        sb.append("</measure></part></score-partwise>")
        return sb.toString()
    }

    private fun decodeToMono22050(path: String): ShortArray {
        val ext = File(path).extension.lowercase()
        if (ext == "wav") return readWavMono(path, 22050)
        return decodeMedia(path)
    }

    private fun readWavMono(path: String, targetSr: Int): ShortArray {
        val bytes = File(path).readBytes()
        if (bytes.size < 44) throw IllegalStateException("无效 WAV")
        val sr = ByteBuffer.wrap(bytes, 24, 4).order(ByteOrder.LITTLE_ENDIAN).int
        val bits = ByteBuffer.wrap(bytes, 34, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
        var off = 12
        while (off + 8 < bytes.size) {
            val tag = String(bytes, off, 4)
            val sz = ByteBuffer.wrap(bytes, off + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
            if (tag == "data") {
                val raw = bytes.copyOfRange(off + 8, off + 8 + sz)
                val samples = if (bits == 16) {
                    val n = raw.size / 2
                    ShortArray(n) { i ->
                        ByteBuffer.wrap(raw, i * 2, 2).order(ByteOrder.LITTLE_ENDIAN).short
                    }
                } else throw IllegalStateException("仅支持 16-bit WAV")
                return resample(samples, sr, targetSr)
            }
            off += 8 + sz
        }
        throw IllegalStateException("WAV data 块缺失")
    }

    private fun decodeMedia(path: String): ShortArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(path)
        var track = -1
        for (i in 0 until extractor.trackCount) {
            val fmt = extractor.getTrackFormat(i)
            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) { track = i; break }
        }
        if (track < 0) throw IllegalStateException("无音频轨")
        extractor.selectTrack(track)
        val fmt = extractor.getTrackFormat(track)
        val sr = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val out = ArrayList<Short>(sr * 90)
        val buf = ByteBuffer.allocate(16384)
        while (true) {
            val n = extractor.readSampleData(buf, 0)
            if (n < 0) break
            buf.order(ByteOrder.LITTLE_ENDIAN)
            buf.position(0)
            val shorts = n / 2
            for (i in 0 until shorts) out.add(buf.short)
            extractor.advance()
        }
        extractor.release()
        if (out.isEmpty()) throw IllegalStateException("解码为空")
        val max = min(out.size, sr * 90)
        return resample(out.take(max).toShortArray(), sr, 22050)
    }

    private fun resample(samples: ShortArray, fromSr: Int, toSr: Int): ShortArray {
        if (fromSr == toSr) return samples
        val n2 = (samples.size.toLong() * toSr / fromSr).toInt().coerceAtLeast(1)
        return ShortArray(n2) { i ->
            samples[min(samples.size - 1, (i * fromSr / toSr))]
        }
    }
}
