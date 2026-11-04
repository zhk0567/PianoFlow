package com.pianoflow.android.practice

import android.content.Context
import android.util.Log
import com.pianoflow.android.data.CatalogRepository
import com.pianoflow.android.data.SongSummary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class PracticeMode { Auto, Follow }

/**
 * Windows-parity practice controller: JSON timeline + wait freeze/chord/grade +
 * speed/hand/guide/metro + settlement / weak section.
 */
class PracticeController(
    context: Context,
    private val repo: CatalogRepository,
    private val scope: CoroutineScope,
    private val onChanged: () -> Unit,
    private val onSettlement: () -> Unit,
) {
    private val appContext = context.applicationContext
    private val tones = TonePlayer(appContext)
    private val server = VerovioLocalServer(appContext)
    private val examRecorder = ExamPcmRecorder()
    private var mic: MicPitchTracker? = null
    private var tickJob: Job? = null

    var song: SongSummary? = null
        private set
    private var allNotes: List<ScoreNote> = emptyList()
    var notes: List<ScoreNote> = emptyList()
        private set
    var mode: PracticeMode = PracticeMode.Auto
        private set
    var playing: Boolean = false
        private set
    var positionBeats: Float = -PracticeConsts.playbackLeadInBeats.toFloat()
        private set
    var pressedMidi: Set<Int> = emptySet()
        private set
    var waitingFor: Set<Int> = emptySet()
        private set
    var focusMidi: Int? = null
        private set
    var statusHint: String = ""
        private set
    var verovioUrl: String? = null
        private set
    var staffReady: Boolean = false
        private set

    var speed: Float = 1f
        private set
    var hand: Hand = Hand.Both
        private set
    var guideAudio: Boolean = true
        private set
    var metronome: Boolean = false
        private set
    var exam: Boolean = false
        private set
    var examRecord: Boolean = true
        private set
    var examRecordAudio: Boolean = false
        private set
    var lastExamRecordingPath: String? = null
        private set
    var volume: Float = 0.85f
        private set

    var perfects: Int = 0
        private set
    var goods: Int = 0
        private set
    var combo: Int = 0
        private set
    var lastGradeLabel: String? = null
        private set
    var durationBeats: Double = 1.0
        private set

    private var bpm: Double = 72.0
    private var lastAutoFire = -1.0
    private var lastMetroBeat = -1
    private var satisfied = mutableSetOf<Int>()
    private var echoSuppressUntilMs = 0L
    private var lastCueChordStart = -1.0
    private val missBeats = mutableListOf<Double>()
    private var frozenMissLogged = false
    private var settlementArmed = false
    private val guideGate = GuideRetriggerGate()
    private val attackLatch = PracticeAttackLatch()
    private val cueBleed = CueBleedGuard()
    private var echoSuppressedMidis: Set<Int> = emptySet()
    /** Last frame reported an HF onset (for noteOn bleed check). */
    @Volatile private var lastFrameOnset: Boolean = false
    var pitchEngineLabel: String = ""
        private set

    fun load(song: SongSummary) {
        this.song = song
        try {
            val json = repo.readScoreJson(song)
            val (jsonBpm, parsed) = ScoreJsonParser.parse(json)
            bpm = song.bpm ?: jsonBpm
            allNotes = parsed
        } catch (e: Exception) {
            Log.e("PianoFlow/Practice", "read json: $e")
            statusHint = "乐谱 JSON 读取失败，请查看 logcat [PianoFlow/Practice]"
            emitChange()
            return
        }
        recomputeNotes()
        durationBeats =
            (notes.maxOfOrNull { it.start + it.duration } ?: 4.0).coerceAtLeast(1.0)
        restartTransport(clearStats = true)
        staffReady = false
        try {
            val xml = repo.readMusicXml(song)
            val port = server.ensureReady()
            server.writeScore(xml)
            verovioUrl = "http://127.0.0.1:$port/viewer.html?v=${System.currentTimeMillis()}"
            statusHint = "正在加载谱面…"
        } catch (e: Exception) {
            Log.e("PianoFlow/Verovio", "server: $e")
            statusHint = "谱面服务启动失败，请查看 logcat [PianoFlow/Verovio]"
        }
        emitChange()
    }

    private fun recomputeNotes() {
        notes = ScoreJsonParser.filter(allNotes, hand)
    }

    fun invalidateStaffReady() {
        staffReady = false
    }

    fun setStaffReady(ready: Boolean) {
        staffReady = ready
        if (ready) statusHint = "谱面就绪"
        emitChange()
    }

    fun toolkitReadyCheckScript(): String =
        "(function(){try{return pfToolkitReady&&pfToolkitReady();}catch(e){return false;}})()"

    fun setSpeed(v: Float) {
        speed = v.coerceIn(PracticeConsts.speedMin, PracticeConsts.speedMax)
        emitChange()
    }

    fun setHand(h: Hand) {
        hand = h
        recomputeNotes()
        restartTransport(clearStats = false)
        emitChange()
    }

    fun setGuideAudio(on: Boolean) {
        guideAudio = on
        emitChange()
    }

    fun setMetronome(on: Boolean) {
        metronome = on
        emitChange()
    }

    fun setExamMode(on: Boolean, record: Boolean = true, recordAudio: Boolean = false) {
        exam = on
        examRecord = record
        examRecordAudio = recordAudio
        if (on) {
            mode = PracticeMode.Follow
            guideAudio = false
        }
        emitChange()
    }

    fun setVolume(v: Float) {
        volume = v.coerceIn(0.1f, 1f)
        tones.masterVolume = volume
    }

    fun seek(beats: Float) {
        if (exam) return
        // Slider / staff scrub while playing → pause; no auto-resume on release.
        if (playing) pause()
        val b = beats.coerceIn(0f, durationBeats.toFloat())
        positionBeats = if (b <= 0.05f) {
            -PracticeConsts.playbackLeadInBeats.toFloat()
        } else {
            b
        }
        lastAutoFire = positionBeats.toDouble() - 1e-3
        satisfied.clear()
        waitingFor = emptySet()
        pressedMidi = emptySet()
        frozenMissLogged = false
        lastCueChordStart = -1.0
        guideGate.clear()
        attackLatch.clear()
        cueBleed.clear()
        echoSuppressedMidis = emptySet()
        updateFocus()
        emitChange()
    }

    fun togglePlay() {
        if (playing) pause() else play()
    }

    fun play() {
        if (notes.isEmpty()) {
            statusHint = "曲目无音符"
            emitChange()
            return
        }
        val wasPlaying = playing
        playing = true
        settlementArmed = true
        if (sessionStartedAt == null) sessionStartedAt = System.currentTimeMillis()
        if ((mode == PracticeMode.Follow || exam) && !wasPlaying) {
            PracticeHitLatency.reset()
        }
        statusHint = if (mode == PracticeMode.Follow) "跟弹中" else "自动播放"
        if (mode == PracticeMode.Follow) startMic()
        if (exam && examRecordAudio) {
            song?.let { examRecorder.start(it.id, appContext.filesDir) }
        }
        emitChange()
        startClock()
    }

    fun pause() {
        playing = false
        tickJob?.cancel()
        stopMic()
        emitChange()
    }

    fun restart() {
        pause()
        restartTransport(clearStats = true)
        emitChange()
    }

    private fun restartTransport(clearStats: Boolean) {
        positionBeats = -PracticeConsts.playbackLeadInBeats.toFloat()
        lastAutoFire = -1.0
        lastMetroBeat = -1
        pressedMidi = emptySet()
        waitingFor = emptySet()
        satisfied.clear()
        frozenMissLogged = false
        lastCueChordStart = -1.0
        guideGate.clear()
        attackLatch.clear()
        cueBleed.clear()
        echoSuppressedMidis = emptySet()
        if (clearStats) {
            perfects = 0
            goods = 0
            combo = 0
            lastGradeLabel = null
            missBeats.clear()
            sessionStartedAt = null
        }
        updateFocus()
    }

    fun setMode(m: PracticeMode, micGranted: Boolean, onNeedMic: () -> Unit) {
        pause()
        mode = m
        if (m == PracticeMode.Follow) {
            if (!micGranted) {
                statusHint = "跟弹需要麦克风权限"
                emitChange()
                onNeedMic()
                return
            }
            statusHint = "跟弹模式已开启"
        } else {
            stopMic()
            statusHint = "自动播放模式"
        }
        emitChange()
    }

    fun onMicDenied() {
        statusHint = "未授权麦克风，已切回自动播放"
        mode = PracticeMode.Auto
        stopMic()
        emitChange()
    }

    fun applyWeakLoop(start: Double, end: Double) {
        seek(start.toFloat())
        statusHint = WeakLoopLogic.labelZh(start, end)
        play()
    }

    fun weakSuggestion(): Pair<Double, Double>? =
        WeakLoopLogic.suggest(missBeats, durationBeats)

    fun pushPositionScript(snapScroll: Boolean = false): String {
        val b = positionBeats.toDouble()
        val rate =
            if (playing && mode == PracticeMode.Auto) bpm * speed / 60.0
            else if (playing && mode == PracticeMode.Follow && waitingFor.isEmpty()) {
                bpm * speed / 60.0
            } else {
                0.0
            }
        val snapJs = if (snapScroll) "true" else "false"
        return "typeof pfSetPosition==='function'&&pfSetPosition($b,$snapJs,$rate);"
    }

    fun staffScoreReadyCheckScript(): String =
        "(function(){try{return pfTransportReady&&pfTransportReady();}catch(e){return false;}})()"

    fun staffLayoutOptsJson(cssW: Int, cssH: Int): String {
        val w = cssW.coerceAtLeast(200)
        val h = cssH.coerceAtLeast(120)
        // 与 Windows PracticeConstants.verovioScale=60 一致：全曲同一刻度，禁止按谱区高度改 scale
        return """{"cssWidth":$w,"cssHeight":$h,"scale":60,"pageHeight":900,"mobile":true}"""
    }

    fun loadScoreScript(port: Int, cssW: Int, cssH: Int): String {
        val url = "http://127.0.0.1:$port/current_score.musicxml?t=${System.currentTimeMillis()}"
        val opts = staffLayoutOptsJson(cssW, cssH)
        return "typeof pfLoadFromUrlAsync==='function'&&pfLoadFromUrlAsync(${org.json.JSONObject.quote(url)},$opts);"
    }

    fun resizeStaffScript(cssW: Int, cssH: Int): String {
        val opts = staffLayoutOptsJson(cssW, cssH)
        return "typeof pfResize==='function'&&pfResize($opts);"
    }

    fun serverPort(): Int = server.port

    private fun startClock() {
        tickJob?.cancel()
        tickJob = scope.launch(Dispatchers.Main) {
            var last = System.nanoTime()
            while (isActive && playing) {
                delay(16)
                val now = System.nanoTime()
                val dt = (now - last) / 1_000_000_000.0
                last = now
                val beatsPerSec = bpm * speed / 60.0
                if (mode == PracticeMode.Auto) {
                    positionBeats =
                        (positionBeats + (dt * beatsPerSec).toFloat())
                            .coerceAtMost(durationBeats.toFloat())
                    fireAutoNotes()
                    tickMetro()
                    updateFocus()
                    if (positionBeats >= durationBeats) {
                        finishRun()
                    }
                } else {
                    tickFollow(dt, beatsPerSec)
                }
                emitChange()
            }
        }
    }

    private fun tickFollow(dt: Double, beatsPerSec: Double) {
        val pos = positionBeats.toDouble()
        val expected = WaitLogic.expectedAt(notes, pos)
        waitingFor = expected - satisfied
        val chordStart = WaitLogic.chordStart(notes, expected, pos)
        val freeze = chordStart != null &&
            expected.isNotEmpty() &&
            WaitLogic.shouldFreeze(pos, chordStart)

        if (freeze) {
            // Soft guide cue once per chord
            if (guideAudio && chordStart != null && chordStart != lastCueChordStart) {
                lastCueChordStart = chordStart
                val toCue = waitingFor
                if (toCue.isNotEmpty()) {
                    toCue.forEach { tones.playMidi(it) }
                    echoSuppressUntilMs =
                        System.currentTimeMillis() + PracticeConsts.echoSuppressGuideMs
                    echoSuppressedMidis = toCue.toSet()
                    guideGate.arm(toCue)
                    cueBleed.arm(toCue)
                }
            }
            if (!frozenMissLogged && waitingFor.isNotEmpty()) {
                // miss logged when user plays wrong while frozen ? handled in onPitch
            }
            pressedMidi = waitingFor
        } else {
            // Free advance through gaps / early window (waterfall keeps moving)
            positionBeats =
                (positionBeats + (dt * beatsPerSec).toFloat())
                    .coerceAtMost(durationBeats.toFloat())
            if (expected.isEmpty()) {
                satisfied.clear()
                lastCueChordStart = -1.0
                frozenMissLogged = false
            }
            pressedMidi = expected
            tickMetro()
        }
        updateFocus()
        if (positionBeats >= durationBeats) finishRun()
    }

    private fun tickMetro() {
        if (!metronome || !playing) return
        if (mode == PracticeMode.Follow && waitingFor.isNotEmpty()) return
        val beat = positionBeats.toDouble().toInt()
        if (beat >= 0 && beat != lastMetroBeat) {
            lastMetroBeat = beat
            // Soft click via mid C sample at low volume ? use a mid note briefly
            tones.playMidi(60)
        }
    }

    private fun fireAutoNotes() {
        val pos = positionBeats.toDouble()
        val window = notes.filter {
            it.start > lastAutoFire + 1e-6 && it.start <= pos + 1e-4
        }
        if (window.isEmpty()) return
        lastAutoFire = window.maxOf { it.start }
        val midis = window.map { it.midi }.toSet()
        pressedMidi = midis
        midis.forEach { tones.playMidi(it) }
    }

    private fun updateFocus() {
        val pos = positionBeats.toDouble().coerceAtLeast(0.0)
        val n = notes.firstOrNull { it.start >= pos - 0.02 } ?: notes.lastOrNull()
        if (n != null) focusMidi = n.midi
    }

    private fun startMic() {
        stopMic()
        mic = MicPitchTracker(
            context = appContext,
            onNoteOns = { midis, captureAt ->
                scope.launch(Dispatchers.Main) {
                    for (m in midis) onNoteOn(m, captureAt)
                }
            },
            onFrame = { midis, captureAt, onset ->
                scope.launch(Dispatchers.Main) {
                    onPitchFrame(midis, captureAt, onset)
                }
            },
            onError = { msg ->
                scope.launch(Dispatchers.Main) {
                    statusHint = msg
                    Log.w("PianoFlow/Pitch", msg)
                    emitChange()
                }
            },
            onEngine = { label ->
                scope.launch(Dispatchers.Main) {
                    pitchEngineLabel = label
                    Log.i("PianoFlow/Pitch", "follow engine=$label")
                }
            },
            onPcm16 = { buf, n ->
                if (exam && examRecordAudio && examRecorder.isActive) {
                    examRecorder.addPcm16(buf, n)
                }
            },
            priorMidis = { PitchMatch.priorBins(waitingFor) },
        ).also { it.start() }
    }

    private fun stopMic() {
        mic?.stop()
        mic = null
    }

    private fun onPitchFrame(midis: Set<Int>, captureAt: Long, onset: Boolean) {
        if (mode != PracticeMode.Follow || !playing) return
        val now = System.currentTimeMillis()
        val heard = if (now < echoSuppressUntilMs) {
            midis.filter { m ->
                echoSuppressedMidis.none { PitchMatch.isNear(it, m) }
            }.toSet()
        } else {
            midis
        }.let { raw ->
            if (waitingFor.isEmpty()) raw
            else PitchMatch.conditionHeard(raw, waitingFor)
        }
        attackLatch.onHeard(heard)
        lastFrameOnset = onset
        if (onset && heard.isNotEmpty()) {
            val before = attackLatch.spentCount
            attackLatch.releaseOnOnset(heard)
            if (attackLatch.spentCount < before) {
                PracticeHitLatency.noteOnsetRelease()
            }
        }
        pressedMidi = heard
        if (waitingFor.isEmpty()) {
            emitChange()
            return
        }
        val stillSuppressed = if (now < echoSuppressUntilMs) {
            echoSuppressedMidis
        } else {
            emptySet()
        }
        val hits = guideGate.acceptHits(
            heard = heard,
            waitingFor = waitingFor,
            stillSuppressed = stillSuppressed,
        )
        for (m in hits) {
            if (attackLatch.blocks(m)) {
                PracticeHitLatency.noteLatchBlock()
                continue
            }
            if (cueBleed.isBleed(m, hasOnset = onset, heardAll = heard, nowMs = now)) {
                PracticeHitLatency.noteCueBleed()
                continue
            }
            registerWaitHit(m, heardMidi = m, captureAt = captureAt, path = "frame")
        }
        emitChange()
    }

    private fun onNoteOn(midi: Int, captureAt: Long) {
        if (mode != PracticeMode.Follow || !playing) return
        val now = System.currentTimeMillis()
        val echoActive = now < echoSuppressUntilMs &&
            echoSuppressedMidis.any { PitchMatch.isNear(it, midi) }
        if (echoActive) return

        if (cueBleed.isBleed(
                midi,
                hasOnset = lastFrameOnset,
                heardAll = setOf(midi) + pressedMidi,
                nowMs = now,
            )
        ) {
            PracticeHitLatency.noteCueBleed()
            Log.i("PianoFlow/Practice", "cue-bleed block noteOn midi=$midi")
            emitChange()
            return
        }

        val gateBlocks = guideGate.blocks(midi)
        pressedMidi = setOf(midi)

        val expected = WaitLogic.expectedAt(notes, positionBeats.toDouble())
        if (expected.isEmpty()) {
            emitChange()
            return
        }
        val remaining = expected - satisfied
        val chordStart = WaitLogic.chordStart(notes, expected, positionBeats.toDouble())
        val freeze = chordStart != null && WaitLogic.shouldFreeze(positionBeats.toDouble(), chordStart)

        val matched = PitchMatch.matchNoteOn(midi, remaining)
        if (matched != null) {
            if (attackLatch.blocks(midi) || attackLatch.blocks(matched)) {
                PracticeHitLatency.noteLatchBlock()
                Log.i("PianoFlow/Practice", "latch-block noteOn midi=$midi matched=$matched")
                emitChange()
                return
            }
            // Fresh noteOn after suppress: disarm quiet gap (Windows parity).
            guideGate.disarm(listOf(matched))
            if (heardMidiSoft(matched, midi)) PracticeHitLatency.noteSoftMatch()
            registerWaitHit(matched, heardMidi = midi, captureAt = captureAt, path = "noteOn")
            emitChange()
            return
        }

        if (gateBlocks) {
            emitChange()
            return
        }

        if (freeze && remaining.isNotEmpty() &&
            !PitchMatch.isForgivableWrongPitch(midi, remaining)
        ) {
            if (!frozenMissLogged) {
                frozenMissLogged = true
                PracticeHitLatency.noteMiss()
                missBeats.add(chordStart!!)
                combo = 0
                Log.i("PianoFlow/Practice", "miss at=$chordStart heard=$midi want=$remaining")
            }
        }
        emitChange()
    }

    private fun heardMidiSoft(matched: Int, heard: Int): Boolean =
        matched != heard && PitchMatch.isNear(matched, heard)

    private fun registerWaitHit(
        midi: Int,
        heardMidi: Int,
        captureAt: Long,
        path: String,
    ) {
        val pos = positionBeats.toDouble()
        val expected = WaitLogic.expectedAt(notes, pos)
        val remaining = expected - satisfied
        if (midi !in remaining) return
        if (attackLatch.blocks(midi) || attackLatch.blocks(heardMidi)) return

        val chordStart = WaitLogic.chordStart(notes, expected, pos) ?: return
        satisfied.add(midi)
        attackLatch.markConsumed(midi, heardMidi = heardMidi)

        val delta = pos - chordStart
        val grade = JudgeLogic.grade(delta)
        when (grade) {
            HitGrade.Perfect -> {
                perfects++
                combo++
                lastGradeLabel = "完美"
            }
            HitGrade.Good -> {
                goods++
                combo++
                lastGradeLabel = "不错"
            }
        }

        val captureMs = (System.currentTimeMillis() - captureAt).coerceAtLeast(0)
        PracticeHitLatency.record(captureMs.toInt(), guideOn = guideAudio, path = path)
        Log.i(
            "PianoFlow/Practice",
            "hit-capture-ms=$captureMs grade=$grade midi=$midi path=$path guide=$guideAudio",
        )

        val left = expected - satisfied
        waitingFor = left
        if (left.isEmpty()) {
            positionBeats = WaitLogic.nudgePast(notes, chordStart).toFloat()
            satisfied.clear()
            frozenMissLogged = false
            lastCueChordStart = -1.0
            waitingFor = emptySet()
            echoSuppressedMidis = emptySet()
        }
        updateFocus()
    }

    private fun finishRun() {
        playing = false
        tickJob?.cancel()
        stopMic()
        if (exam && examRecordAudio) {
            lastExamRecordingPath = examRecorder.stop()
        }
        if (mode == PracticeMode.Follow || exam) {
            PracticeHitLatency.logIfPractice()
        }
        statusHint = "本段结束"
        emitChange()
        // 跟弹/考试结束都回调：平时只记账不弹窗，考试弹结算（见 PracticeActivity）。
        if (settlementArmed && (mode == PracticeMode.Follow || exam)) {
            settlementArmed = false
            onSettlement()
        }
    }

    private var sessionStartedAt: Long? = null

    fun release() {
        pause()
        tones.shutdown()
        server.stop()
    }

    private fun emitChange() = onChanged()
}
