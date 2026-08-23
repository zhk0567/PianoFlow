package com.pianoflow.android.data

import android.content.res.AssetManager
import android.util.Log
import org.json.JSONObject

data class SongSummary(
    val id: String,
    val title: String,
    val artist: String?,
    val scoreKind: String,
    val genre: String?,
    val difficulty: Int?,
    val bpm: Double?,
    val jsonAsset: String,
    val isUserImport: Boolean = false,
) {
    val scoreKindLabel: String
        get() = when (scoreKind) {
            "formal" -> "正式谱"
            "omrDraft" -> "OMR草稿"
            "simplified" -> "简化谱"
            "userImport" -> "用户导入"
            else -> scoreKind
        }

    val musicXmlAsset: String
        get() = if (isUserImport) "user/musicxml/$id.musicxml" else "scores/musicxml/$id.musicxml"
}

class CatalogRepository(
    private val assets: AssetManager,
    private val userStore: UserStore? = null,
) {
    fun loadSongs(): List<SongSummary> {
        val raw = assets.open("scores/catalog.json").bufferedReader().use { it.readText() }
        val arr = JSONObject(raw).getJSONArray("songs")
        val bundled = buildList {
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val id = o.getString("id")
                val assetPath = o.optString("asset", "assets/scores/$id.json").removePrefix("assets/")
                if (!hasBundledAssets(id, assetPath)) {
                    Log.w("PianoFlow/Catalog", "skip bundled $id")
                    continue
                }
                add(o.toSummary(assetPath))
            }
        }
        val user = userStore?.loadUserCatalogEntries()?.map { it.toSummary(user = true) } ?: emptyList()
        val byId = bundled.associateBy { it.id }.toMutableMap()
        user.forEach { byId[it.id] = it }
        val out = bundled.toMutableList()
        user.filter { u -> bundled.none { it.id == u.id } }.forEach { out.add(it) }
        Log.i("PianoFlow/Catalog", "loaded ${out.size} songs (${user.size} user)")
        return out
    }

    private fun hasBundledAssets(id: String, jsonPath: String): Boolean {
        val json = try { assets.open(jsonPath).close(); true } catch (_: Exception) { false }
        val xml = try { assets.open("scores/musicxml/$id.musicxml").close(); true } catch (_: Exception) { false }
        return json && xml
    }

    fun readMusicXml(song: SongSummary): String {
        if (song.isUserImport) {
            return userStore?.readUserMusicXml(song.id)
                ?: throw IllegalStateException("missing user xml ${song.id}")
        }
        return assets.open(song.musicXmlAsset).bufferedReader().use { it.readText() }
    }

    fun readScoreJson(song: SongSummary): String {
        if (song.isUserImport) {
            return userStore?.readUserScoreJson(song.id)
                ?: throw IllegalStateException("missing user json ${song.id}")
        }
        return assets.open(song.jsonAsset).bufferedReader().use { it.readText() }
    }

    private fun org.json.JSONObject.toSummary(assetPath: String? = null, user: Boolean = false): SongSummary {
        val id = getString("id")
        return SongSummary(
            id = id,
            title = getString("title"),
            artist = if (has("artist") && !isNull("artist")) getString("artist") else null,
            scoreKind = optString("scoreKind", if (user) "userImport" else "omrDraft"),
            genre = if (has("genre") && !isNull("genre")) getString("genre") else null,
            difficulty = if (has("difficulty") && !isNull("difficulty")) getInt("difficulty") else null,
            bpm = if (has("bpm") && !isNull("bpm")) getDouble("bpm") else null,
            jsonAsset = assetPath ?: optString("asset", "scores/$id.json").removePrefix("assets/"),
            isUserImport = user || optString("scoreKind") == "userImport",
        )
    }
}
