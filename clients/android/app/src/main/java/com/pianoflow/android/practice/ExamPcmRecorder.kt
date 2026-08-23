package com.pianoflow.android.practice

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Tee mic PCM16 into exam WAV. Port of lib/features/practice/exam_pcm_recorder.dart */
class ExamPcmRecorder {
    private var file: File? = null
    private var raf: RandomAccessFile? = null
    private var dataBytes = 0
    var isActive: Boolean = false
        private set
    var path: String? = null
        private set

    fun start(songId: String, root: File) {
        stop(deleteIfEmpty = true)
        val dir = File(root, "pianoflow_exam_takes/$songId").apply { mkdirs() }
        val ts = java.time.LocalDateTime.now().toString().replace(":", "-")
        val f = File(dir, "$ts.wav")
        file = f
        path = f.absolutePath
        raf = RandomAccessFile(f, "rw")
        raf?.write(ByteArray(44))
        dataBytes = 0
        isActive = true
        android.util.Log.i("PianoFlow/ExamPcm", "record start ${f.absolutePath}")
    }

    fun addPcm16(pcm: ShortArray, len: Int = pcm.size) {
        if (!isActive) return
        val r = raf ?: return
        val bb = ByteBuffer.allocate(len * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until len) bb.putShort(pcm[i])
        r.write(bb.array())
        dataBytes += len * 2
    }

    fun stop(deleteIfEmpty: Boolean = true): String? {
        if (!isActive) return path
        isActive = false
        val f = file
        val r = raf
        raf = null
        file = null
        try {
            r?.close()
            if (f == null || dataBytes <= 0) {
                if (deleteIfEmpty && f?.exists() == true) f.delete()
                path = null
                return null
            }
            RandomAccessFile(f, "rw").use { rw ->
                rw.seek(0)
                rw.write(wavHeader(dataBytes))
            }
            android.util.Log.i("PianoFlow/ExamPcm", "saved ${f.absolutePath} ($dataBytes B)")
            return f.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("PianoFlow/ExamPcm", "stop failed", e)
            return null
        }
    }

    private fun wavHeader(dataBytes: Int, sampleRate: Int = 22050): ByteArray {
        val channels = 1
        val bits = 16
        val byteRate = sampleRate * channels * bits / 8
        val blockAlign = channels * bits / 8
        val bb = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray())
        bb.putInt(36 + dataBytes)
        bb.put("WAVE".toByteArray())
        bb.put("fmt ".toByteArray())
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(channels.toShort())
        bb.putInt(sampleRate)
        bb.putInt(byteRate)
        bb.putShort(blockAlign.toShort())
        bb.putShort(bits.toShort())
        bb.put("data".toByteArray())
        bb.putInt(dataBytes)
        return bb.array()
    }
}
