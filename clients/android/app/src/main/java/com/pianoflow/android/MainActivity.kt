package com.pianoflow.android

import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.pianoflow.android.data.CatalogRepository
import com.pianoflow.android.data.SongSummary
import com.pianoflow.android.data.UserStore
import com.pianoflow.android.data.MidiImport
import com.pianoflow.android.data.AudioWorkshopImport
import com.pianoflow.android.data.PdfWorkshopStage
import java.io.File
import com.pianoflow.android.data.WorkshopImport
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class MainActivity : AppCompatActivity() {
    private lateinit var store: UserStore
    private lateinit var repo: CatalogRepository
    private var songs: List<SongSummary> = emptyList()
    private lateinit var tabContent: FrameLayout
    private var libQuery = ""
    private var libKind: String? = null
    private var libDifficulty: Int? = null
    private var libGenre: String? = null
    private var libFavoritesOnly = false
    private var examQuery = ""
    private var selectedExamId: String? = null
    private var examRecord = true
    private var examRecordAudio = false

    private val importAudioLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@registerForActivityResult
        val status = currentWorkshopStatus()
        try {
            val tmp = File(cacheDir, "import_audio_${System.currentTimeMillis()}")
            contentResolver.openInputStream(uri)?.use { inp -> tmp.outputStream().use { inp.copyTo(it) } }
            val name = uri.lastPathSegment ?: "import.wav"
            AudioWorkshopImport.importFile(this, tmp.absolutePath, name, store)
            status?.text = "音频已导入：$name"
            reloadSongs()
            showLibrary()
        } catch (e: Exception) {
            android.util.Log.e("PianoFlow/Workshop", "audio import failed", e)
            status?.text = "音频导入失败：${e.message}"
        }
    }

    private val importPdfLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@registerForActivityResult
        val status = currentWorkshopStatus()
        try {
            val tmp = File(cacheDir, "import.pdf")
            contentResolver.openInputStream(uri)?.use { inp -> tmp.outputStream().use { inp.copyTo(it) } }
            val name = uri.lastPathSegment ?: "score.pdf"
            val msg = PdfWorkshopStage.stage(this, tmp.absolutePath, name)
            status?.text = msg
        } catch (e: Exception) {
            android.util.Log.e("PianoFlow/Workshop", "pdf stage failed", e)
            status?.text = "PDF 暂存失败：${e.message}"
        }
    }

    private val importXmlLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@registerForActivityResult
        val status = currentWorkshopStatus()
        try {
            val name = uri.lastPathSegment ?: "import.musicxml"
            val xml = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                ?: throw IllegalStateException("无法读取文件")
            WorkshopImport.importMusicXml(xml, name, store)
            status?.text = "已导入：$name"
            reloadSongs()
            showLibrary()
        } catch (e: Exception) {
            android.util.Log.e("PianoFlow/Workshop", "XML import failed", e)
            status?.text = "导入失败：${e.message}"
        }
    }

    private val importMidiLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri == null) return@registerForActivityResult
        val status = currentWorkshopStatus()
        try {
            val name = uri.lastPathSegment ?: "import.mid"
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("无法读取文件")
            MidiImport.importBytes(bytes, name, store)
            status?.text = "MIDI 已导入：$name"
            reloadSongs()
            showLibrary()
        } catch (e: Exception) {
            android.util.Log.e("PianoFlow/Workshop", "MIDI import failed", e)
            status?.text = "MIDI 导入失败：${e.message}"
        }
    }

    private var workshopStatusView: TextView? = null
    private fun currentWorkshopStatus() = workshopStatusView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        store = UserStore(this)
        repo = CatalogRepository(assets, store)
        reloadSongs()
        tabContent = findViewById(R.id.tabContent)
        findViewById<BottomNavigationView>(R.id.bottomNav).setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> showHome()
                R.id.nav_library -> showLibrary()
                R.id.nav_exam -> showExam()
                R.id.nav_workshop -> showWorkshop()
                R.id.nav_profile -> showProfile()
            }
            true
        }
        findViewById<BottomNavigationView>(R.id.bottomNav).selectedItemId = R.id.nav_home
        showHome()
    }

    override fun onResume() {
        super.onResume()
        if (!::store.isInitialized || !::tabContent.isInitialized) return
        val nav = findViewById<BottomNavigationView>(R.id.bottomNav)
        if (nav.selectedItemId == R.id.nav_home) showHome()
    }

    private fun reloadSongs() {
        songs = repo.loadSongs()
    }

    private fun inflateTab(layout: Int): View {
        tabContent.removeAllViews()
        val view = layoutInflater.inflate(layout, tabContent, false)
        tabContent.addView(view)
        return view
    }

    private fun selectBottomNav(itemId: Int, block: () -> Unit = {}) {
        tabContent.post {
            block()
            findViewById<BottomNavigationView>(R.id.bottomNav).selectedItemId = itemId
        }
    }

    private fun openPractice(song: SongSummary, exam: Boolean = false) {
        startActivity(
            Intent(this, PracticeActivity::class.java)
                .putExtra(PracticeActivity.EXTRA_ID, song.id)
                .putExtra(PracticeActivity.EXTRA_EXAM, exam)
                .putExtra(PracticeActivity.EXTRA_EXAM_RECORD, examRecord)
                .putExtra(PracticeActivity.EXTRA_EXAM_RECORD_AUDIO, examRecordAudio),
        )
    }

    private fun confirmDeleteImport(song: SongSummary, onDone: () -> Unit) {
        AlertDialog.Builder(this)
            .setTitle("删除自导入")
            .setMessage("删除「${song.title}」？不可恢复。")
            .setPositiveButton("删除") { _, _ ->
                store.deleteUserImport(song.id)
                reloadSongs()
                onDone()
            }
            .setNegativeButton("取消", null)
            .show()
    }

    private fun showHome() {
        val root = inflateTab(R.layout.tab_home)
        val recent = store.getRecent().mapNotNull { id -> songs.find { it.id == id } }
        val beginner = songs.firstOrNull { it.difficulty == 1 } ?: songs.firstOrNull()
        root.findViewById<Button>(R.id.homeCta).apply {
            text = when {
                recent.isNotEmpty() -> "继续：${recent.first().title}"
                beginner != null -> "从入门曲开始"
                else -> "去曲库看看"
            }
            setOnClickListener {
                when {
                    recent.isNotEmpty() -> openPractice(recent.first())
                    beginner != null -> openPractice(beginner)
                    else -> findViewById<BottomNavigationView>(R.id.bottomNav).selectedItemId = R.id.nav_library
                }
            }
        }
        root.findViewById<TextView>(R.id.homeRecent).apply {
            text = if (recent.isEmpty()) "暂无 · 去曲库开练" else recent.take(3).joinToString("\n") { it.title }
            isClickable = recent.isNotEmpty()
            setOnClickListener {
                if (recent.isNotEmpty()) openPractice(recent.first())
            }
        }
        val favIds = store.getFavorites()
        val favSongs = favIds.mapNotNull { id -> songs.find { it.id == id } }
        root.findViewById<TextView>(R.id.homeFavorites).apply {
            text = if (favSongs.isEmpty()) {
                "暂无 · 曲库点星标收藏"
            } else {
                favSongs.take(3).joinToString("\n") { "★ ${it.title}" }
            }
            isClickable = true
            setOnClickListener {
                selectBottomNav(R.id.nav_library) {
                    libFavoritesOnly = favSongs.isNotEmpty()
                }
            }
        }
        root.findViewById<TextView>(R.id.homeToday).apply {
            val today = songs.firstOrNull()
            text = today?.let { "${it.title}\n${it.artist.orEmpty()}" } ?: "无曲目"
            setOnClickListener { today?.let { openPractice(it) } }
        }
    }

    private fun showLibrary() {
        val root = inflateTab(R.layout.tab_library)
        val list = root.findViewById<RecyclerView>(R.id.songList)
        val count = root.findViewById<TextView>(R.id.libCount)
        val filters = root.findViewById<LinearLayout>(R.id.libFilters)
        list.layoutManager = GridLayoutManager(this, 2)
        val gap = (6 * resources.displayMetrics.density).toInt()
        if (list.itemDecorationCount == 0) {
            list.addItemDecoration(object : androidx.recyclerview.widget.RecyclerView.ItemDecoration() {
                override fun getItemOffsets(
                    outRect: android.graphics.Rect,
                    view: View,
                    parent: RecyclerView,
                    state: RecyclerView.State,
                ) {
                    outRect.set(gap / 2, gap / 2, gap / 2, gap / 2)
                }
            })
            list.setPadding(gap, 0, gap, gap)
            list.clipToPadding = false
        }
        fun filtered() = songs.filter { s ->
            if (libFavoritesOnly && !store.getFavorites().contains(s.id)) return@filter false
            if (libKind != null && s.scoreKind != libKind) return@filter false
            if (libDifficulty != null && s.difficulty != libDifficulty) return@filter false
            if (libGenre != null && s.genre != libGenre) return@filter false
            val q = libQuery.trim().lowercase()
            q.isEmpty() || "${s.title} ${s.artist} ${s.genre} ${s.scoreKindLabel}".lowercase().contains(q)
        }
        fun bind() {
            val f = filtered()
            count.text = when {
                f.isEmpty() && libFavoritesOnly -> "暂无收藏"
                f.isEmpty() -> "无匹配"
                libFavoritesOnly -> "${f.size} 首收藏"
                else -> "${f.size} 张唱片"
            }
            root.findViewById<TextView>(R.id.libOmrHint).visibility =
                if (libKind == "omrDraft") View.VISIBLE else View.GONE
            list.adapter = AlbumAdapter(f, store, onClick = { openPractice(it) }) { song ->
                confirmDeleteImport(song) { bind() }
            }
            rebuildFilters(filters)
        }
        root.findViewById<EditText>(R.id.libSearch).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: Editable?) { libQuery = s?.toString().orEmpty(); bind() }
        })
        bind()
    }

    private fun rebuildFilters(host: LinearLayout) {
        host.removeAllViews()
        fun chip(label: String, active: Boolean, click: () -> Unit) {
            val tv = TextView(this)
            val pad = (10 * resources.displayMetrics.density).toInt()
            tv.setPadding(pad, pad / 2, pad, pad / 2)
            tv.text = label
            tv.textSize = 12f
            tv.setTextColor(if (active) Color.BLACK else 0xFF9AA3B2.toInt())
            val bg = GradientDrawable().apply { cornerRadius = 999f; setColor(if (active) 0xFFE8A849.toInt() else 0xFF1A212C.toInt()) }
            tv.background = bg
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.marginEnd = pad / 2
            tv.layoutParams = lp
            tv.setOnClickListener { click(); showLibrary() }
            host.addView(tv)
        }
        chip("全部", libKind == null && libDifficulty == null && libGenre == null && !libFavoritesOnly) {
            libKind = null; libDifficulty = null; libGenre = null; libFavoritesOnly = false
        }
        val favCount = store.getFavorites().size
        chip(if (favCount > 0) "★ 收藏 ($favCount)" else "★ 收藏", libFavoritesOnly) {
            libFavoritesOnly = !libFavoritesOnly
        }
        for (k in listOf("formal", "omrDraft", "simplified", "userImport")) {
            if (songs.none { it.scoreKind == k }) continue
            chip(songs.first { it.scoreKind == k }.scoreKindLabel, libKind == k) { libKind = if (libKind == k) null else k }
        }
        val diffLabels = mapOf(1 to "入门", 2 to "初级", 3 to "中级", 4 to "高级")
        for (d in listOf(1, 2, 3, 4)) {
            if (songs.none { it.difficulty == d }) continue
            chip(diffLabels[d] ?: "$d", libDifficulty == d) { libDifficulty = if (libDifficulty == d) null else d }
        }
        for (g in songs.mapNotNull { it.genre }.distinct().sorted()) {
            chip(g, libGenre == g) { libGenre = if (libGenre == g) null else g }
        }
    }

    private fun showExam() {
        val root = inflateTab(R.layout.tab_exam)
        val list = root.findViewById<RecyclerView>(R.id.examList)
        val start = root.findViewById<Button>(R.id.examStart)
        list.layoutManager = LinearLayoutManager(this)
        if (selectedExamId == null) selectedExamId = songs.firstOrNull()?.id
        val histView = root.findViewById<TextView>(R.id.examHistory)
        val histDetail = root.findViewById<TextView>(R.id.examHistoryDetail)
        fun examFiltered() = songs.filter { s ->
            val q = examQuery.trim().lowercase()
            q.isEmpty() || "${s.title} ${s.artist.orEmpty()}".lowercase().contains(q)
        }.sortedBy { it.difficulty ?: 99 }

        fun bindExam() {
            val examSongs = examFiltered()
            if (selectedExamId != null && examSongs.none { it.id == selectedExamId }) {
                selectedExamId = examSongs.firstOrNull()?.id
            }
            list.adapter = SimpleAdapter(examSongs, selectedExamId) { s ->
                selectedExamId = s.id
                start.text = "开始考试 · ${s.title}"
                bindExam()
            }
            val sel = examSongs.firstOrNull { it.id == selectedExamId }
            start.isEnabled = sel != null
            start.text = if (sel == null) "开始考试" else "开始考试 · ${sel.title}"
            start.setOnClickListener { sel?.let { openPractice(it, exam = true) } }
            val hist = store.getStats().optJSONArray("examHistory")
            if (hist == null || hist.length() == 0) {
                histView.text = "暂无考试记录"
                histDetail.visibility = View.GONE
            } else {
                val last = hist.getJSONObject(0)
                val at = Instant.ofEpochMilli(last.optLong("at"))
                    .atZone(ZoneId.systemDefault())
                    .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))
                histView.text = "最近考试 ${hist.length()} 次 · 上次 $at"
                val lines = buildList {
                    for (i in 0 until hist.length().coerceAtMost(5)) {
                        val e = hist.getJSONObject(i)
                        val sid = e.optString("songId")
                        val title = songs.firstOrNull { it.id == sid }?.title ?: sid
                        val whenAt = Instant.ofEpochMilli(e.optLong("at"))
                            .atZone(ZoneId.systemDefault())
                            .format(DateTimeFormatter.ofPattern("MM-dd HH:mm"))
                        add("$title · 完美${e.optInt("perfects")} 不错${e.optInt("goods")} · $whenAt")
                    }
                }
                histDetail.text = lines.joinToString("\n")
                histDetail.visibility = View.VISIBLE
            }
        }
        root.findViewById<EditText>(R.id.examSearch).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: Editable?) {
                examQuery = s?.toString().orEmpty()
                bindExam()
            }
        })
        root.findViewById<android.widget.CheckBox>(R.id.examRecord).apply {
            isChecked = examRecord
            setOnCheckedChangeListener { _, checked -> examRecord = checked }
        }
        root.findViewById<android.widget.CheckBox>(R.id.examRecordAudio).apply {
            isChecked = examRecordAudio
            setOnCheckedChangeListener { _, checked -> examRecordAudio = checked }
        }
        bindExam()
    }

    private fun showWorkshop() {
        val root = inflateTab(R.layout.tab_workshop)
        workshopStatusView = root.findViewById(R.id.workshopStatus)
        root.findViewById<Button>(R.id.btnImportXml).setOnClickListener {
            importXmlLauncher.launch("*/*")
        }
        root.findViewById<Button>(R.id.btnImportMidi).setOnClickListener {
            importMidiLauncher.launch("*/*")
        }
        root.findViewById<Button>(R.id.btnImportAudio).setOnClickListener {
            importAudioLauncher.launch("audio/*")
        }
        root.findViewById<Button>(R.id.btnImportPdf).setOnClickListener {
            importPdfLauncher.launch("application/pdf")
        }
        val imports = songs.filter { it.isUserImport }
        root.findViewById<RecyclerView>(R.id.userImportList).apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = UserImportAdapter(imports, onOpen = { openPractice(it) }) { song ->
                confirmDeleteImport(song) { showWorkshop() }
            }
        }
    }

    private fun showProfile() {
        val root = inflateTab(R.layout.tab_profile)
        val auth = store.getAuth()
        root.findViewById<TextView>(R.id.profileName).text = auth.name
        root.findViewById<TextView>(R.id.profileSub).text = if (auth.guest) "访客 · 本地练习" else auth.email.orEmpty()
        root.findViewById<TextView>(R.id.profileAvatar).text = auth.name.take(1)
        root.findViewById<Button>(R.id.btnLogin).visibility = if (auth.guest) View.VISIBLE else View.GONE
        root.findViewById<Button>(R.id.btnLogout).visibility = if (auth.guest) View.GONE else View.VISIBLE
        val stats = store.getStats()
        root.findViewById<TextView>(R.id.statSessions).text = stats.optInt("totalSessions").toString()
        root.findViewById<TextView>(R.id.statSongs).text =
            (stats.optJSONObject("bySong")?.length() ?: 0).toString()
        root.findViewById<Button>(R.id.btnLogin).setOnClickListener { showLoginDialog { showProfile() } }
        root.findViewById<Button>(R.id.btnLogout).setOnClickListener { store.logout(); showProfile() }
        root.findViewById<Button>(R.id.btnConstellation).setOnClickListener {
            startActivity(Intent(this, ConstellationActivity::class.java))
        }
        root.findViewById<Button>(R.id.btnSandbox).setOnClickListener {
            startActivity(Intent(this, SandboxActivity::class.java))
        }
        root.findViewById<Button>(R.id.btnPitchTest).setOnClickListener {
            startActivity(Intent(this, PitchTestActivity::class.java))
        }
        root.findViewById<Button>(R.id.btnSettings).setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }
    }

    private fun showLoginDialog(onDone: () -> Unit) {
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(48, 24, 48, 0) }
        val email = EditText(this).apply { hint = "邮箱" }
        val pass = EditText(this).apply { hint = "密码"; inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD }
        val name = EditText(this).apply { hint = "昵称" }
        layout.addView(email); layout.addView(pass); layout.addView(name)
        AlertDialog.Builder(this)
            .setTitle("登录")
            .setView(layout)
            .setPositiveButton("登录") { _, _ ->
                val err = store.login(email.text.toString(), pass.text.toString(), name.text.toString())
                if (err != null) android.widget.Toast.makeText(this, err, android.widget.Toast.LENGTH_SHORT).show()
                else onDone()
            }
            .setNegativeButton("访客") { _, _ -> store.enterGuest(); onDone() }
            .show()
    }

    private inner class AlbumAdapter(
        private val data: List<SongSummary>,
        private val userStore: UserStore,
        private val onClick: (SongSummary) -> Unit,
        private val onDelete: (SongSummary) -> Unit,
    ) : RecyclerView.Adapter<AlbumAdapter.VH>() {
        inner class VH(v: View) : RecyclerView.ViewHolder(v) {
            val bg: LinearLayout = v.findViewById(R.id.albumBg)
            val title: TextView = v.findViewById(R.id.songTitle)
            val artist: TextView = v.findViewById(R.id.songArtist)
            val kind: TextView = v.findViewById(R.id.songKind)
            val meta: TextView = v.findViewById(R.id.songMeta)
            val favBtn: TextView = v.findViewById(R.id.songFav)
            val favBadge: TextView = v.findViewById(R.id.songFavBadge)
        }
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            VH(LayoutInflater.from(parent.context).inflate(R.layout.item_song, parent, false))
        override fun getItemCount() = data.size
        override fun onBindViewHolder(holder: VH, position: Int) {
            val s = data[position]
            holder.title.text = s.title
            holder.artist.text = s.artist.orEmpty().ifBlank { "未知艺术家" }
            val fav = userStore.getFavorites().contains(s.id)
            holder.kind.text = s.scoreKindLabel
            holder.favBadge.visibility = if (fav) View.VISIBLE else View.GONE
            holder.favBtn.text = if (fav) "★" else "☆"
            holder.favBtn.setTextColor(if (fav) 0xFF4A6B4C.toInt() else 0xFF6B6258.toInt())
            holder.favBtn.setBackgroundColor(if (fav) 0xFFDCE8C8.toInt() else 0xE6FAF6EE.toInt())
            val density = holder.itemView.resources.displayMetrics.density
            holder.bg.background = GradientDrawable().apply {
                cornerRadius = 14f * density
                setColor(albumTintFor(s))
                if (fav) {
                    setStroke((2 * density).toInt(), 0xFF4A6B4C.toInt())
                } else {
                    setStroke((1 * density).toInt(), 0xFFD9CFC0.toInt())
                }
            }
            holder.title.setTextColor(0xFF1F1A16.toInt())
            holder.artist.setTextColor(0xFF4A433C.toInt())
            holder.kind.setTextColor(0xFF4A6B4C.toInt())
            holder.kind.setBackgroundColor(0xE6DCE8C8.toInt())
            holder.meta.setTextColor(0xFF6B6258.toInt())
            holder.favBadge.setBackgroundColor(0xEB4A6B4C.toInt())
            holder.favBadge.setTextColor(0xFFFFF9F0.toInt())
            val diff = when (s.difficulty) {
                1 -> "入门"
                2 -> "初级"
                3 -> "中级"
                4 -> "高级"
                else -> "难度 ?"
            }
            val bpm = s.bpm?.let { "$it BPM" } ?: "— BPM"
            holder.meta.text = "$diff · $bpm"
            holder.itemView.setOnClickListener { onClick(s) }
            holder.favBtn.setOnClickListener {
                val on = userStore.toggleFavorite(s.id)
                android.widget.Toast.makeText(
                    holder.itemView.context,
                    if (on) "已收藏" else "已取消收藏",
                    android.widget.Toast.LENGTH_SHORT,
                ).show()
                // 刷新整表，确保收藏筛选 / chip 计数同步
                showLibrary()
            }
            holder.itemView.setOnLongClickListener {
                if (s.isUserImport) {
                    val favLabel = if (userStore.getFavorites().contains(s.id)) "取消收藏" else "收藏"
                    AlertDialog.Builder(this@MainActivity)
                        .setTitle(s.title)
                        .setItems(arrayOf(favLabel, "删除自导入")) { _, which ->
                            when (which) {
                                0 -> {
                                    val on = userStore.toggleFavorite(s.id)
                                    android.widget.Toast.makeText(
                                        this@MainActivity,
                                        if (on) "已收藏" else "已取消收藏",
                                        android.widget.Toast.LENGTH_SHORT,
                                    ).show()
                                    showLibrary()
                                }
                                1 -> onDelete(s)
                            }
                        }
                        .show()
                } else {
                    val on = userStore.toggleFavorite(s.id)
                    android.widget.Toast.makeText(
                        holder.itemView.context,
                        if (on) "已收藏" else "已取消收藏",
                        android.widget.Toast.LENGTH_SHORT,
                    ).show()
                    showLibrary()
                }
                true
            }
        }
    }

    private fun albumTintFor(s: SongSummary): Int {
        // Echo warm-paper washes (match Flutter RecordAlbumCard — readable on page bg).
        val palette = intArrayOf(
            0xFFB5CFA0.toInt(),
            0xFFD4B090.toInt(),
            0xFFE0B090.toInt(),
            0xFF9CBCBC.toInt(),
            0xFFC0C890.toInt(),
            0xFFD0A890.toInt(),
            0xFFD0BC90.toInt(),
            0xFFA0BC9C.toInt(),
        )
        return palette[kotlin.math.abs(s.id.hashCode()) % palette.size]
    }

    private inner class UserImportAdapter(
        private val data: List<SongSummary>,
        private val onOpen: (SongSummary) -> Unit,
        private val onDelete: (SongSummary) -> Unit,
    ) : RecyclerView.Adapter<UserImportAdapter.VH>() {
        inner class VH(v: View) : RecyclerView.ViewHolder(v) {
            val title: TextView = v.findViewById(R.id.songTitle)
            val artist: TextView = v.findViewById(R.id.songArtist)
            val kind: TextView = v.findViewById(R.id.songKind)
            val meta: TextView = v.findViewById(R.id.songMeta)
            val bg: LinearLayout = v.findViewById(R.id.albumBg)
        }
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            VH(LayoutInflater.from(parent.context).inflate(R.layout.item_song, parent, false))
        override fun getItemCount() = data.size
        override fun onBindViewHolder(holder: VH, position: Int) {
            val s = data[position]
            holder.title.text = s.title
            holder.artist.text = s.artist.orEmpty()
            holder.kind.text = s.scoreKindLabel
            holder.meta.text = "自导入"
            holder.bg.setBackgroundColor(0xFFFAF6EE.toInt())
            holder.title.setTextColor(0xFF1F1A16.toInt())
            holder.artist.setTextColor(0xFF4A433C.toInt())
            holder.kind.setTextColor(0xFF4A6B4C.toInt())
            holder.kind.setBackgroundColor(0xE6DCE8C8.toInt())
            holder.meta.setTextColor(0xFF6B6258.toInt())
            holder.itemView.findViewById<TextView>(R.id.songFav)?.visibility = View.GONE
            holder.itemView.findViewById<TextView>(R.id.songFavBadge)?.visibility = View.GONE
            holder.itemView.setOnClickListener { onOpen(s) }
            holder.itemView.setOnLongClickListener {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle(s.title)
                    .setItems(arrayOf("练习", "删除")) { _, which ->
                        when (which) {
                            0 -> onOpen(s)
                            1 -> onDelete(s)
                        }
                    }
                    .show()
                true
            }
        }
    }

    private class SimpleAdapter(
        private val data: List<SongSummary>,
        private val selectedId: String?,
        private val onClick: (SongSummary) -> Unit,
    ) : RecyclerView.Adapter<SimpleAdapter.VH>() {
        class VH(v: View) : RecyclerView.ViewHolder(v) {
            val title: TextView = v.findViewById(R.id.songTitle)
            val artist: TextView = v.findViewById(R.id.songArtist)
            val kind: TextView = v.findViewById(R.id.songKind)
            val bg: LinearLayout = v.findViewById(R.id.albumBg)
        }
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            VH(LayoutInflater.from(parent.context).inflate(R.layout.item_song, parent, false))
        override fun getItemCount() = data.size
        override fun onBindViewHolder(holder: VH, position: Int) {
            val s = data[position]
            holder.title.text = s.title
            holder.artist.text = s.scoreKindLabel
            holder.kind.text = if (s.id == selectedId) "已选" else ""
            holder.bg.setBackgroundColor(if (s.id == selectedId) 0x33E8A849 else 0xFF141920.toInt())
            holder.itemView.findViewById<TextView>(R.id.songFav)?.visibility = View.GONE
            holder.itemView.findViewById<TextView>(R.id.songFavBadge)?.visibility = View.GONE
            holder.itemView.setOnClickListener { onClick(s) }
        }
    }
}
