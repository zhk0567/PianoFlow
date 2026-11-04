package com.pianoflow.android.practice

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer

/**
 * Spotify Basic Pitch ONNX — same I/O contract as Dart BasicPitchEstimator.
 */
class BasicPitchEstimator private constructor(
    private val env: OrtEnvironment,
    private val session: OrtSession,
    private val frameThresh: Double = 0.42,
    private val relativeThresh: Double = 0.60,
) {
    @Volatile private var closed = false

    fun close() {
        if (closed) return
        closed = true
        try {
            session.close()
        } catch (e: Exception) {
            Log.w(TAG, "session close: $e")
        }
    }

    /**
     * Active MIDI notes from 22.05 kHz mono float PCM.
     * Short buffers are right-aligned and zero-padded on the left.
     */
    fun estimateActiveMidi(
        audio22050: FloatArray,
        priorMidis: Set<Int>? = null,
    ): Set<Int> {
        if (closed || audio22050.isEmpty()) return emptySet()
        val window = FloatArray(AUDIO_N_SAMPLES)
        if (audio22050.size >= AUDIO_N_SAMPLES) {
            System.arraycopy(
                audio22050,
                audio22050.size - AUDIO_N_SAMPLES,
                window,
                0,
                AUDIO_N_SAMPLES,
            )
        } else {
            System.arraycopy(
                audio22050,
                0,
                window,
                AUDIO_N_SAMPLES - audio22050.size,
                audio22050.size,
            )
        }

        var input: OnnxTensor? = null
        var results: OrtSession.Result? = null
        try {
            val shape = longArrayOf(1, AUDIO_N_SAMPLES.toLong(), 1)
            input = OnnxTensor.createTensor(env, FloatBuffer.wrap(window), shape)
            results = session.run(mapOf(INPUT_NAME to input))
            val out = results.get(OUTPUT_NAME).orElse(null) as? OnnxTensor
                ?: run {
                    Log.w(TAG, "missing output $OUTPUT_NAME")
                    return emptySet()
                }
            val frames = asFrameBins(out)
            if (frames.isEmpty()) return emptySet()
            val scores = BasicPitchSelect.tailMeanScores(frames, tail = 4)
            return BasicPitchSelect.selectNotes(
                scores,
                frameThresh = frameThresh,
                relativeThresh = relativeThresh,
                priorMidis = priorMidis,
            )
        } catch (e: Exception) {
            Log.e(TAG, "infer failed: $e")
            return emptySet()
        } finally {
            try { input?.close() } catch (_: Exception) {}
            try { results?.close() } catch (_: Exception) {}
        }
    }

    private fun asFrameBins(tensor: OnnxTensor): Array<DoubleArray> {
        val shape = tensor.info.shape // e.g. [1, T, 88] or [T, 88]
        val buf = tensor.floatBuffer
        if (shape.size < 2) return emptyArray()
        val nBins = shape[shape.size - 1].toInt()
        val nFrames = shape[shape.size - 2].toInt()
        if (nBins <= 0 || nFrames <= 0) return emptyArray()
        val out = Array(nFrames) { DoubleArray(nBins) }
        // FloatBuffer may not be at position 0 after previous reads.
        buf.rewind()
        for (t in 0 until nFrames) {
            for (b in 0 until nBins) {
                out[t][b] = buf.get().toDouble()
            }
        }
        return out
    }

    companion object {
        private const val TAG = "PianoFlow/Pitch"
        const val ASSET_PATH = "models/basic_pitch.onnx"
        const val SAMPLE_RATE = 22050
        const val AUDIO_N_SAMPLES = 43844
        private const val INPUT_NAME = "serving_default_input_2:0"
        private const val OUTPUT_NAME = "StatefulPartitionedCall:1"

        fun create(context: Context): BasicPitchEstimator? {
            return try {
                Log.i(TAG, "loading Basic Pitch ONNX ($ASSET_PATH)…")
                val env = OrtEnvironment.getEnvironment()
                val bytes = context.assets.open(ASSET_PATH).use { it.readBytes() }
                val opts = OrtSession.SessionOptions()
                val session = env.createSession(bytes, opts)
                BasicPitchEstimator(env, session)
            } catch (e: Exception) {
                Log.e(TAG, "Basic Pitch load failed: $e")
                null
            }
        }
    }
}
