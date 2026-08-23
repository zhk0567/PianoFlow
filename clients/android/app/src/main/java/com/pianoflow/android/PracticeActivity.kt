package com.pianoflow.android

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.os.Bundle
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
    private lateinit var speedBar: SeekBar
    private lateinit var volumeBar: SeekBar
    private lateinit var fxOverlay: com.pianoflow.android.ui.PracticeFxOverlay
    private var geo: KeyboardGeo? = null
    private var lastComboFx = 0
    private var pushJob: Job? = null
    private var lastFocusMidi: Int? = null
    private var seekUserDragging = false
    private var staffLoadToken = 0
    private var resizeDebounceJob: Job? = null

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
        speedBar = findViewById(R.id.speedBar)
        volumeBar = findViewById(R.id.volumeBar)
        fxOverlay = findViewById(R.id.fxOverlay)
        fxOverlay.visibility = View.GONE
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
            findViewById<Button>(R.id.btnFav).text = if (on) "已藏" else "收藏"
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
        findViewById<Button>(R.id.btnGuide).setOnClickListener {
            ctrl.setGuideAudio(!ctrl.guideAudio)
            bindUi()
        }
        findViewById<Button>(R.id.btnMetro).setOnClickListener {
            ctrl.setMetronome(!ctrl.metronome)
            bindUi()
        }

        // speed: progress 0..160 → 0.4..2.0
        speedBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val speed = 0.4f + progress / 100f
                ctrl.setSpeed(speed)
                findViewById<TextView>(R.id.speedLabel).text =
                    "速度 ${(ctrl.speed * 100).toInt()}%"
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {}
        })

        val savedVol = (userStore.getMasterVolume() * 100).toInt().coerceIn(10, 100)
        volumeBar.progress = savedVol
        ctrl.setVolume(savedVol / 100f)
        volumeBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val v = progress.coerceIn(10, 100) / 100f
                ctrl.setVolume(v)
                userStore.setMasterVolume(v)
                findViewById<TextView>(R.id.volumeLabel).text = "音量 ${progress}%"
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {}
            override fun onStopTrackingTouch(sb: SeekBar?) {}
        })

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                if (!fromUser) return
                val t = progress / 1000f * ctrl.durationBeats.toFloat()
                ctrl.seek(t)
            }
            override fun onStartTrackingTouch(sb: SeekBar?) {
                seekUserDragging = true
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
            findViewById<TextView>(R.id.status).text = "曲目不存在"
            return
        }
        ctrl.load(song)
        findViewById<Button>(R.id.btnFav).text =
            if (userStore.getFavorites().contains(song.id)) "已藏" else "收藏"
        findViewById<TextView>(R.id.volumeLabel).text = "音量 ${volumeBar.progress}%"
        if (examLoad) {
            requestFollow()
        }
        bindUi()
        ensurePushLoop()
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
                text = "谱面加载超时，正在重试…"
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
                ctrl.sessionSeconds(),
                ctrl.exam,
                ctrl.examRecord,
                ctrl.perfects,
                ctrl.goods,
                ctrl.combo,
            )
        }
        val weak = ctrl.weakSuggestion()
        val msg = buildString {
            append("完美 ${ctrl.perfects} · 不错 ${ctrl.goods} · 连击 ${ctrl.combo}")
            if (weak != null) append("\n可再练：${WeakLoopLogic.labelZh(weak.first, weak.second)}")
        }
        val builder = AlertDialog.Builder(this)
            .setTitle("本段结算")
            .setMessage(msg)
            .setPositiveButton("再练一次") { _, _ ->
                ctrl.restart()
                ctrl.play()
                bindUi()
            }
            .setNegativeButton("回曲库") { _, _ -> finish() }
        val rec = ctrl.lastExamRecordingPath
        val extras = mutableListOf<String>()
        if (!rec.isNullOrBlank()) extras.add("聆听录音")
        if (weak != null) extras.add("练薄弱段")
        if (extras.isNotEmpty()) {
            builder.setItems(extras.toTypedArray()) { _, which ->
                when (extras[which]) {
                    "聆听录音" -> try {
                        android.media.MediaPlayer().apply {
                            setDataSource(rec)
                            prepare()
                            start()
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("PianoFlow/ExamPcm", "play failed", e)
                    }
                    "练薄弱段" -> {
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
        findViewById<TextView>(R.id.title).text = ctrl.song?.title ?: "练习"
        findViewById<TextView>(R.id.meta).text =
            "${ctrl.song?.artist.orEmpty()} · ${ctrl.song?.scoreKindLabel.orEmpty()} · " +
                when (ctrl.hand) {
                    Hand.Both -> "双手"
                    Hand.Left -> "左手"
                    Hand.Right -> "右手"
                }
        findViewById<TextView>(R.id.status).apply {
            val hint = ctrl.statusHint
            val showError = hint.contains("失败") || hint.contains("错误") ||
                hint.contains("异常") || hint.contains("超时") || hint.contains("无音符")
            if (showError) {
                text = hint
                visibility = View.VISIBLE
            } else {
                visibility = View.GONE
            }
        }
        val grade = ctrl.lastGradeLabel
        findViewById<TextView>(R.id.grade).text =
            if (grade != null) "$grade · 连击 ${ctrl.combo}" else ""
        if (ctrl.combo > lastComboFx && grade != null) {
            lastComboFx = ctrl.combo
        }
        seekBar.isEnabled = !ctrl.exam
        findViewById<Button>(R.id.btnPlay).text = if (ctrl.playing) "暂停" else "播放"
        findViewById<Button>(R.id.btnGuide).text =
            if (ctrl.guideAudio) "示范音·开" else "示范音·关"
        findViewById<Button>(R.id.btnMetro).text =
            if (ctrl.metronome) "节拍器·开" else "节拍器·关"
        findViewById<TextView>(R.id.speedLabel).text =
            "速度 ${(ctrl.speed * 100).toInt()}%"
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
                delay(33)
                if (!ctrl.staffReady) continue
                val script = ctrl.pushPositionScript()
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
