package com.pianoflow.android

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.pianoflow.android.data.CatalogRepository
import com.pianoflow.android.practice.Hand
import com.pianoflow.android.practice.PracticeController
import com.pianoflow.android.practice.PracticeMode
import com.pianoflow.android.practice.WeakLoopLogic
import com.pianoflow.android.ui.FallingNotesView
import com.pianoflow.android.ui.KeyboardGeo
import com.pianoflow.android.ui.MiniKeyboardView
import com.pianoflow.android.ui.UiUtils
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject

class PracticeActivity : AppCompatActivity() {
    companion object {
        const val EXTRA_ID = "song_id"
        const val EXTRA_EXAM = "exam"
        const val EXTRA_EXAM_RECORD = "exam_record"
        const val EXTRA_EXAM_RECORD_AUDIO = "exam_record_audio"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var ctrl: PracticeController
    private lateinit var userStore: com.pianoflow.android.data.UserStore
    private lateinit var web: WebView
    private lateinit var stageHost: FrameLayout
    private lateinit var falling: FallingNotesView
    private lateinit var keyboard: MiniKeyboardView
    private lateinit var seekBar: SeekBar
    private lateinit var fxOverlay: com.pianoflow.android.ui.PracticeFxOverlay
    private var visualFxEnabled = true
    private var geo: KeyboardGeo? = null
    private var lastComboFx = 0
    private var lastGradeNonce = 0
    private var gradeClearJob: Job? = null
    private var pushJob: Job? = null
    private var lastStaffPushAtMs = 0L
    private var lastStaffPushBeats = Float.NaN
    private var seekUserDragging = false
    private var staffLoadToken = 0
    private var resizeDebounceJob: Job? = null
    private var staffScrubbing = false
    private var staffScrubOriginX = 0f
    private var staffScrubOriginBeats = 0f
    private var staffScrubPxPerBeat = 40f
    private var recentPromoteJob: Job? = null

    private fun scheduleRecentPromote(songId: String) {
        recentPromoteJob?.cancel()
        recentPromoteJob = scope.launch {
            delay(5 * 60 * 1000L)
            if (!isActive || isDestroyed) return@launch
            userStore.pushRecent(songId)
            android.util.Log.i("PianoFlow/Library", "recent promote after 5min open: $songId")
        }
    }

    private val micLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            ctrl.setMode(PracticeMode.Follow, micGranted = true) {}
            ctrl.play()
            bindUi()
        } else {
            ctrl.onMicDenied()
            bindUi()
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_practice)
        val practiceRoot = findViewById<View>(R.id.practiceRoot)
        val practiceTopBar = findViewById<View>(R.id.practiceTopBar)
        val bottomBar = findViewById<View>(R.id.bottomBar)
        UiUtils.applyImmersivePractice(this, practiceRoot, practiceTopBar, bottomBar)
        userStore = com.pianoflow.android.data.UserStore(this)
        val repo = CatalogRepository(assets, userStore)
        ctrl = PracticeController(this, repo, scope, onChanged = { bindUi() }) {
            runOnUiThread { showSettlement() }
        }
        val exam = intent.getBooleanExtra(EXTRA_EXAM, false)
        val examRecord = intent.getBooleanExtra(EXTRA_EXAM_RECORD, true)
        val examRecordAudio = intent.getBooleanExtra(EXTRA_EXAM_RECORD_AUDIO, false)
        if (exam) ctrl.setExamMode(true, examRecord, examRecordAudio)

        stageHost = findViewById(R.id.stageHost)
        falling = findViewById(R.id.falling)
        falling.visibility = View.GONE
        keyboard = findViewById(R.id.keyboard)
        seekBar = findViewById(R.id.seekBar)
        fxOverlay = findViewById(R.id.fxOverlay)
        visualFxEnabled = userStore.getVisualFxEnabled()
        fxOverlay.fxEnabled = visualFxEnabled
        fxOverlay.visibility = if (visualFxEnabled) View.VISIBLE else View.GONE
        web = findViewById(R.id.staffWeb)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.cacheMode = WebSettings.LOAD_NO_CACHE
        web.settings.builtInZoomControls = false
        web.settings.displayZoomControls = false
        web.setBackgroundColor(0xFFFFFBF5.toInt())
        web.webChromeClient = WebChromeClient()
        web.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                val pageUrl = url ?: return
                if (!pageUrl.contains("/viewer.html")) return
                val token = staffLoadToken
                view?.postDelayed({ beginStaffLoad(token) }, 300)
            }
        }
        installStaffScrubOverlay()

        stageHost.viewTreeObserver.addOnGlobalLayoutListener(
            object : ViewTreeObserver.OnGlobalLayoutListener {
                override fun onGlobalLayout() {
                    if (stageHost.width <= 0) return
                    stageHost.viewTreeObserver.removeOnGlobalLayoutListener(this)
                    applyGeometry()
                }
            },
        )
        stageHost.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            if (stageHost.width > 0) applyGeometry()
        }

        findViewById<Button>(R.id.btnBack).setOnClickListener { finish() }
        findViewById<Button>(R.id.btnFav).setOnClickListener {
            val song = ctrl.song ?: return@setOnClickListener
            val on = userStore.toggleFavorite(song.id)
            findViewById<Button>(R.id.btnFav).text = if (on) "\u5DF2\u85CF" else "\u6536\u85CF"
        }
        findViewById<Button>(R.id.btnAuto).setOnClickListener {
            ctrl.setMode(PracticeMode.Auto, micGranted = true) {}
            bindUi()
        }
        findViewById<Button>(R.id.btnFollow).setOnClickListener { requestFollow() }
        findViewById<Button>(R.id.btnPlay).setOnClickListener {
            ctrl.togglePlay()
            bindUi()
            ensurePushLoop()
        }
        findViewById<Button>(R.id.btnRestart).setOnClickListener {
            ctrl.restart()
            bindUi()
        }
        findViewById<Button>(R.id.btnHandBoth).setOnClickListener {
            ctrl.setHand(Hand.Both)
            bindUi()
        }
        findViewById<Button>(R.id.btnHandLeft).setOnClickListener {
            ctrl.setHand(Hand.Left)
            bindUi()
        }
        findViewById<Button>(R.id.btnHandRight).setOnClickListener {
            ctrl.setHand(Hand.Right)
            bindUi()
        }
        findViewById<Button>(R.id.btnFx).setOnClickListener {
            visualFxEnabled = !visualFxEnabled
            userStore.setVisualFxEnabled(visualFxEnabled)
            fxOverlay.fxEnabled = visualFxEnabled
            fxOverlay.visibility = if (visualFxEnabled) View.VISIBLE else View.GONE
            bindUi()
        }
        findViewById<Button>(R.id.btnSettings).setOnClickListener {
            showPracticeSettings()
        }

        val savedVol = userStore.getMasterVolume().coerceIn(0.1f, 1f)
        ctrl.setVolume(savedVol)

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val t = progress / 1000f * ctrl.durationBeats.toFloat()
                ctrl.seek(t)
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {
                seekUserDragging = true
                if (ctrl.playing) ctrl.pause()
            }
            override fun onStopTrackingTouch(sb: SeekBar?) {
                seekUserDragging = false
                web.evaluateJavascript(ctrl.pushPositionScript(snapScroll = true), null)
            }
        })

        val id = intent.getStringExtra(EXTRA_ID).orEmpty()
        val examLoad = intent.getBooleanExtra(EXTRA_EXAM, false)
        val song = repo.loadSongs().firstOrNull { it.id == id }
        if (song == null) {
            findViewById<TextView>(R.id.status).text = "\u66F2\u76EE\u4E0D\u5B58\u5728"
            return
        }
        ctrl.load(song)
        scheduleRecentPromote(song.id)
        findViewById<Button>(R.id.btnFav).text =
            if (userStore.getFavorites().contains(song.id)) "\u5DF2\u85CF" else "\u6536\u85CF"
        if (examLoad) {
            requestFollow()
        }
        bindUi()
        ensurePushLoop()
    }

    private fun installStaffScrubOverlay() {
        val host = findViewById<FrameLayout>(R.id.staffHost)
        val overlay = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            isClickable = true
            contentDescription = "staff scrub"
        }
        host.addView(overlay)
        overlay.setOnTouchListener { v, ev ->
            if (ctrl.exam) return@setOnTouchListener false
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    staffScrubbing = true
                    seekUserDragging = true
                    if (ctrl.playing) ctrl.pause()
                    staffScrubOriginX = ev.x
                    staffScrubOriginBeats = ctrl.positionBeats
                    val w = v.width.coerceAtLeast(1).toFloat()
                    staffScrubPxPerBeat = (w / 12f).coerceIn(12f, 200f)
                    web.evaluateJavascript(
                        "(function(){try{return window.pfScrubMetrics?window.pfScrubMetrics():'{}';}catch(e){return '{}';}})()",
                    ) { raw ->
                        if (!staffScrubbing) return@evaluateJavascript
                        try {
                            val jsonStr = decodeJsJsonString(raw) ?: return@evaluateJavascript
                            val o = JSONObject(jsonStr)
                            val contentW = o.optDouble("contentW", 0.0)
                            val endQ = o.optDouble("endQ", 0.0)
                            val dur = if (ctrl.durationBeats > 0.5) {
                                ctrl.durationBeats
                            } else {
                                endQ
                            }
                            if (contentW > 32 && dur > 0.5) {
                                staffScrubPxPerBeat =
                                    (contentW / dur).toFloat().coerceIn(12f, 400f)
                            }
                        } catch (_: Exception) {
                        }
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (!staffScrubbing) return@setOnTouchListener false
                    val dx = ev.x - staffScrubOriginX
                    val px = staffScrubPxPerBeat.coerceAtLeast(1f)
                    val next = (staffScrubOriginBeats - dx / px)
                        .coerceIn(0f, ctrl.durationBeats.toFloat())
                    ctrl.seek(next)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (staffScrubbing) {
                        staffScrubbing = false
                        seekUserDragging = false
                        web.evaluateJavascript(ctrl.pushPositionScript(snapScroll = true), null)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun decodeJsJsonString(raw: String?): String? {
        if (raw.isNullOrBlank() || raw == "null") return null
        return try {
            when (val v = org.json.JSONTokener(raw).nextValue()) {
                is String -> v
                is JSONObject -> v.toString()
                else -> raw
            }
        } catch (_: Exception) {
            raw
        }
    }

    private fun showPracticeSettings() {
        val pad = (16 * resources.displayMetrics.density).toInt()
        val col = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
        }
        fun label(t: String) = TextView(this).apply {
            text = t
            setTextColor(0xFFE8EEF4.toInt())
            textSize = 13f
            setPadding(0, pad / 2, 0, pad / 4)
        }
        val speedLbl = label("\u901F\u5EA6" + " ${(ctrl.speed * 100).toInt()}%")
        col.addView(speedLbl)
        col.addView(
            SeekBar(this).apply {
                max = 160
                progress = ((ctrl.speed - 0.4f) * 100f).toInt().coerceIn(0, 160)
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                        if (!fromUser) return
                        ctrl.setSpeed(0.4f + progress / 100f)
                        speedLbl.text = "\u901F\u5EA6" + " ${(ctrl.speed * 100).toInt()}%"
                    }
                    override fun onStartTrackingTouch(sb: SeekBar?) {}
                    override fun onStopTrackingTouch(sb: SeekBar?) {}
                })
            },
        )
        val volLbl = label("\u97F3\u91CF" + " ${(ctrl.volume * 100).toInt()}%")
        col.addView(volLbl)
        col.addView(
            SeekBar(this).apply {
                max = 100
                progress = (ctrl.volume * 100).toInt().coerceIn(10, 100)
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                        if (!fromUser) return
                        val v = progress.coerceIn(10, 100) / 100f
                        ctrl.setVolume(v)
                        userStore.setMasterVolume(v)
                        volLbl.text = "\u97F3\u91CF" + " ${(v * 100).toInt()}%"
                    }
                    override fun onStartTrackingTouch(sb: SeekBar?) {}
                    override fun onStopTrackingTouch(sb: SeekBar?) {}
                })
            },
        )
        if (!ctrl.exam) {
            col.addView(
                Button(this).apply {
                    text = if (ctrl.guideAudio) "\u793A\u8303\u97F3\u00B7\u5F00" else "\u793A\u8303\u97F3\u00B7\u5173"
                    setOnClickListener {
                        ctrl.setGuideAudio(!ctrl.guideAudio)
                        text = if (ctrl.guideAudio) "\u793A\u8303\u97F3\u00B7\u5F00" else "\u793A\u8303\u97F3\u00B7\u5173"
                    }
                },
            )
            col.addView(
                Button(this).apply {
                    text = if (ctrl.metronome) "\u8282\u62CD\u5668\u00B7\u5F00" else "\u8282\u62CD\u5668\u00B7\u5173"
                    setOnClickListener {
                        ctrl.setMetronome(!ctrl.metronome)
                        text = if (ctrl.metronome) "\u8282\u62CD\u5668\u00B7\u5F00" else "\u8282\u62CD\u5668\u00B7\u5173"
                    }
                },
            )
        }
        AlertDialog.Builder(this)
            .setTitle("\u7EC3\u4E60\u8BBE\u7F6E")
            .setView(col)
            .setPositiveButton("\u5173\u95ED", null)
            .show()
    }

    private fun beginStaffLoad(token: Int) {
        if (token != staffLoadToken || isDestroyed) return
        val port = ctrl.serverPort()
        if (port <= 0) {
            web.postDelayed({ beginStaffLoad(token) }, 200)
            return
        }
        val host = findViewById<View>(R.id.staffHost)
        if (host.width < 50 || host.height < 50) {
            web.postDelayed({ beginStaffLoad(token) }, 100)
            return
        }
        web.evaluateJavascript(ctrl.toolkitReadyCheckScript()) { raw ->
            if (token != staffLoadToken || isDestroyed) return@evaluateJavascript
            val toolkitOk = raw?.trim()?.equals("true", ignoreCase = true) == true
            if (!toolkitOk) {
                web.postDelayed({ beginStaffLoad(token) }, 150)
                return@evaluateJavascript
            }
            val sw = host.width.coerceAtLeast(200)
            val sh = host.height.coerceAtLeast(120)
            web.evaluateJavascript(
                "typeof pfClearScore==='function'&&pfClearScore();" +
                    ctrl.loadScoreScript(port, sw, sh),
                null,
            )
            pollStaffScoreReady(token, 0)
        }
    }

    private fun pollStaffScoreReady(token: Int, attempt: Int) {
        if (token != staffLoadToken || isDestroyed) return
        if (attempt > 100) {
            android.util.Log.e("PianoFlow/Practice", "staff load timeout token=$token")
            findViewById<TextView>(R.id.status).apply {
                text = "\u8C31\u9762\u52A0\u8F7D\u8D85\u65F6\uFF0C\u6B63\u5728\u91CD\u8BD5\u2026"
                visibility = View.VISIBLE
            }
            staffLoadToken++
            ctrl.invalidateStaffReady()
            val url = ctrl.verovioUrl
            if (url != null) web.loadUrl(url)
            return
        }
        web.evaluateJavascript(ctrl.staffScoreReadyCheckScript()) { raw ->
            if (token != staffLoadToken || isDestroyed) return@evaluateJavascript
            val ok = raw?.trim()?.equals("true", ignoreCase = true) == true
            if (ok) {
                ctrl.setStaffReady(true)
                web.evaluateJavascript(ctrl.pushPositionScript(snapScroll = true), null)
                bindUi()
            } else {
                web.postDelayed({ pollStaffScoreReady(token, attempt + 1) }, 150)
            }
        }
    }

    private fun showSettlement() {
        val song = ctrl.song
        if (song != null) {
            userStore.recordSession(
                song.id,
                ctrl.exam,
                ctrl.examRecord,
                ctrl.perfects,
                ctrl.goods,
                ctrl.combo,
            )
        }
        val weak = ctrl.weakSuggestion()
        val msg = buildString {
            append("\u5B8C\u7F8E")
            append(" ${ctrl.perfects} ")
            append("\u00B7")
            append(" ")
            append("\u4E0D\u9519")
            append(" ${ctrl.goods} ")
            append("\u00B7")
            append(" ")
            append("\u8FDE\u51FB")
            append(" ${ctrl.combo}")
            if (weak != null) {
                append("\n")
                append("\u53EF\u518D\u7EC3\uFF1A")
                append(WeakLoopLogic.labelZh(weak.first, weak.second))
            }
        }
        val builder = AlertDialog.Builder(this)
            .setTitle(if (ctrl.exam) "\u8003\u8BD5\u7ED3\u7B97" else "\u672C\u6BB5\u7ED3\u7B97")
            .setMessage(msg)
            .setPositiveButton(if (ctrl.exam) "\u518D\u8003\u4E00\u6B21" else "\u518D\u7EC3\u4E00\u6B21") { _, _ ->
                ctrl.restart()
                ctrl.play()
                bindUi()
            }
            .setNegativeButton("\u56DE\u66F2\u5E93") { _, _ -> finish() }
        val rec = ctrl.lastExamRecordingPath
        val extras = mutableListOf<String>()
        if (!rec.isNullOrBlank()) extras.add("\u8046\u542C\u5F55\u97F3")
        if (weak != null && !ctrl.exam) extras.add("\u7EC3\u8584\u5F31\u6BB5")
        if (extras.isNotEmpty()) {
            builder.setItems(extras.toTypedArray()) { _, which ->
                when (extras[which]) {
                    "\u8046\u542C\u5F55\u97F3" -> try {
                        android.media.MediaPlayer().apply {
                            setDataSource(rec)
                            prepare()
                            start()
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("PianoFlow/ExamPcm", "play failed", e)
                    }
                    "\u7EC3\u8584\u5F31\u6BB5" -> {
                        ctrl.applyWeakLoop(weak!!.first, weak.second)
                        bindUi()
                    }
                }
            }
        }
        builder.show()
    }

    private fun applyGeometry() {
        val vw = stageHost.width.coerceAtLeast(1)
        val g = KeyboardGeo(KeyboardGeo.contentWidthFor(this, vw))
        geo = g
        keyboard.setGeometry(g)
        if (!ctrl.staffReady) return
        resizeDebounceJob?.cancel()
        resizeDebounceJob = scope.launch {
            delay(200)
            val host = findViewById<View>(R.id.staffHost)
            val sw = host.width.coerceAtLeast(200)
            val sh = host.height.coerceAtLeast(120)
            web.evaluateJavascript(ctrl.resizeStaffScript(sw, sh), null)
            web.postDelayed({
                web.evaluateJavascript(ctrl.pushPositionScript(snapScroll = true), null)
            }, 350)
        }
    }

    private fun requestFollow() {
        val ok = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ctrl.setMode(PracticeMode.Follow, micGranted = ok) {
            micLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
        if (ok) ctrl.play()
        bindUi()
        ensurePushLoop()
    }

    private fun bindUi() {
        findViewById<TextView>(R.id.title).text = ctrl.song?.title ?: "\u7EC3\u4E60"
        findViewById<TextView>(R.id.meta).text =
            "${ctrl.song?.artist.orEmpty()} " + "\u00B7" + " ${ctrl.song?.scoreKindLabel.orEmpty()} " + "\u00B7" + " " +
                when (ctrl.hand) {
                    Hand.Both -> "\u53CC\u624B"
                    Hand.Left -> "\u5DE6\u624B"
                    Hand.Right -> "\u53F3\u624B"
                }
        findViewById<TextView>(R.id.status).apply {
            val hint = ctrl.statusHint
            val showError = hint.contains("\u5931\u8D25") || hint.contains("\u9519\u8BEF") ||
                hint.contains("\u5F02\u5E38") || hint.contains("\u8D85\u65F6") || hint.contains("\u65E0\u97F3\u7B26")
            if (showError) {
                text = hint
                visibility = View.VISIBLE
            } else {
                visibility = View.GONE
            }
        }
        val gradeView = findViewById<TextView>(R.id.grade)
        val grade = ctrl.lastGradeLabel
        // Windows HitFeedbackOverlay parity: flash 完美/不错 on each successful hit.
        if (ctrl.combo > lastComboFx && grade != null) {
            lastComboFx = ctrl.combo
            lastGradeNonce++
            gradeView.text = grade
            gradeView.alpha = 1f
            gradeClearJob?.cancel()
            gradeClearJob = scope.launch {
                delay(420)
                if (!isActive || isDestroyed) return@launch
                gradeView.animate().alpha(0f).setDuration(180).withEndAction {
                    gradeView.text = ""
                    gradeView.alpha = 1f
                }.start()
            }
            if (visualFxEnabled) {
                val midis = ctrl.pressedMidi.ifEmpty { ctrl.waitingFor }
                val g = geo
                val cx = midis.firstOrNull()?.let { m ->
                    g?.midiCenterX(m) ?: (stageHost.width / 2f)
                } ?: (stageHost.width / 2f)
                fxOverlay.hit(cx, perfect = grade == "完美", combo = ctrl.combo, label = grade)
                // Keep overlay visible for grade flash even if decorative FX off.
                if (fxOverlay.visibility != View.VISIBLE) fxOverlay.visibility = View.VISIBLE
            }
        } else if (grade == null && ctrl.combo == 0) {
            gradeView.text = ""
        }
        seekBar.isEnabled = !ctrl.exam
        findViewById<Button>(R.id.btnPlay).text = if (ctrl.playing) "\u6682\u505C" else "\u64AD\u653E"
        findViewById<Button>(R.id.btnFx).text =
            if (visualFxEnabled) "\u88C5\u9970\u7279\u6548\u00B7\u5F00" else "\u88C5\u9970\u7279\u6548\u00B7\u5173"
        val lit = ctrl.pressedMidi.ifEmpty { ctrl.waitingFor }
        keyboard.setPressed(lit)
        if (!seekUserDragging && ctrl.durationBeats > 0) {
            val p = (ctrl.positionBeats.coerceAtLeast(0f) / ctrl.durationBeats.toFloat() * 1000f)
                .toInt()
                .coerceIn(0, 1000)
            seekBar.progress = p
        }
        val url = ctrl.verovioUrl
        if (url != null) {
            val current = web.url.orEmpty()
            if (!current.contains("/viewer.html") || current.substringBefore('?') != url.substringBefore('?')) {
                staffLoadToken++
                ctrl.invalidateStaffReady()
                web.loadUrl(url)
            }
        }
    }

    private fun ensurePushLoop() {
        if (pushJob?.isActive == true) return
        pushJob = scope.launch {
            while (isActive) {
                delay(16)
                if (!ctrl.staffReady) continue
                val force = staffScrubbing || seekUserDragging
                val now = System.currentTimeMillis()
                val pos = ctrl.positionBeats
                val posDelta = if (lastStaffPushBeats.isNaN()) 1f else kotlin.math.abs(pos - lastStaffPushBeats)
                // Align Windows VerovioTransportSync.playPushMinIntervalMs = 32
                if (!force &&
                    posDelta <= 0.01f &&
                    now - lastStaffPushAtMs < 32L
                ) {
                    continue
                }
                if (!force &&
                    posDelta <= 0.35f &&
                    now - lastStaffPushAtMs < 32L &&
                    ctrl.playing
                ) {
                    continue
                }
                lastStaffPushAtMs = now
                lastStaffPushBeats = pos
                val script = ctrl.pushPositionScript(snapScroll = force)
                web.post { web.evaluateJavascript(script, null) }
            }
        }
    }

    private fun immersiveChrome() {
        UiUtils.applyImmersivePractice(
            this,
            findViewById(R.id.practiceRoot),
            findViewById(R.id.practiceTopBar),
            findViewById(R.id.bottomBar),
        )
    }

    override fun onPause() {
        if (::web.isInitialized) web.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::web.isInitialized) web.onResume()
        immersiveChrome()
        if (ctrl.staffReady) {
            web.post { web.evaluateJavascript(ctrl.pushPositionScript(snapScroll = true), null) }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            immersiveChrome()
        }
    }

    override fun onDestroy() {
        pushJob?.cancel()
        recentPromoteJob?.cancel()
        resizeDebounceJob?.cancel()
        staffLoadToken++
        if (::web.isInitialized) {
            try {
                web.stopLoading()
                (web.parent as? ViewGroup)?.removeView(web)
                web.loadUrl("about:blank")
                web.destroy()
            } catch (e: Exception) {
                android.util.Log.w("PianoFlow/Practice", "web destroy: $e")
            }
        }
        ctrl.release()
        scope.cancel()
        super.onDestroy()
    }
}
