package com.pianoflow.android.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Local persistence — mirrors Windows SharedPreferences + UserImportStore. */
class UserStore(ctx: Context) {
    private val prefs = ctx.getSharedPreferences("pianoflow", Context.MODE_PRIVATE)
    private val userDir = ctx.filesDir.resolve("user_import").apply { mkdirs() }

    fun getAuth(): AuthState {
        val email = prefs.getString("auth_email", null)
        val name = prefs.getString("auth_name", null)
        return if (email.isNullOrBlank()) AuthState.guest() else AuthState(email, name ?: email, false)
    }

    fun login(email: String, password: String, name: String?): String? {
        val trimmed = email.trim()
        if (!trimmed.contains("@")) return "请输入有效邮箱"
        if (password.length < 4) return "密码至少 4 位"
        val display = (name?.trim()?.takeIf { it.isNotEmpty() } ?: trimmed.substringBefore("@"))
        prefs.edit().putString("auth_email", trimmed).putString("auth_name", display).apply()
        return null
    }

    fun enterGuest() {
        prefs.edit().remove("auth_email").remove("auth_name").apply()
    }

    fun logout() = enterGuest()

    fun getMasterVolume(): Float = prefs.getFloat("master_volume", 0.85f)

    fun setMasterVolume(v: Float) {
        prefs.edit().putFloat("master_volume", v.coerceIn(0.1f, 1f)).apply()
    }

    fun getVisualFxEnabled(): Boolean = prefs.getBoolean("visual_fx", true)

    fun setVisualFxEnabled(on: Boolean) {
        prefs.edit().putBoolean("visual_fx", on).apply()
    }

    fun getFavorites(): Set<String> =
        HashSet(prefs.getStringSet("favorites", emptySet()) ?: emptySet())

    fun toggleFavorite(id: String): Boolean {
        val f = HashSet(getFavorites())
        val on = if (f.contains(id)) {
            f.remove(id)
            false
        } else {
            f.add(id)
            true
        }
        prefs.edit().putStringSet("favorites", HashSet(f)).apply()
        return on
    }

    fun getRecent(): List<String> {
        val arr = prefs.getString("recent", "[]") ?: "[]"
        return try {
            val ja = JSONArray(arr)
            buildList { for (i in 0 until ja.length()) add(ja.getString(i)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun pushRecent(id: String) {
        val r = listOf(id) + getRecent().filter { it != id }
        prefs.edit().putString("recent", JSONArray(r.take(12)).toString()).apply()
    }

    fun getStats(): JSONObject {
        val raw = prefs.getString("stats", "{}") ?: "{}"
        return try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
    }

    fun recordSession(
        songId: String,
        exam: Boolean,
        recordExam: Boolean,
        perfects: Int,
        goods: Int,
        combo: Int,
    ) {
        val s = getStats()
        s.put("totalSessions", s.optInt("totalSessions") + 1)
        val bySong = s.optJSONObject("bySong") ?: JSONObject()
        val cur = bySong.optJSONObject(songId) ?: JSONObject()
        cur.put("sessions", cur.optInt("sessions") + 1)
        if (!cur.has("seconds")) cur.put("seconds", 0)
        cur.put("lit", true)
        if (exam && recordExam) {
            cur.put("examSessions", cur.optInt("examSessions") + 1)
            val hist = s.optJSONArray("examHistory") ?: JSONArray()
            val entry = JSONObject()
            entry.put("songId", songId)
            entry.put("at", System.currentTimeMillis())
            entry.put("perfects", perfects)
            entry.put("goods", goods)
            entry.put("combo", combo)
            val newHist = JSONArray()
            newHist.put(entry)
            for (i in 0 until hist.length().coerceAtMost(49)) newHist.put(hist.get(i))
            s.put("examHistory", newHist)
        }
        bySong.put(songId, cur)
        s.put("bySong", bySong)
        prefs.edit().putString("stats", s.toString()).apply()
        pushRecent(songId)
    }

    fun userImportDir() = userDir

    fun loadUserCatalogEntries(): List<JSONObject> {
        val f = userDir.resolve("user_catalog.json")
        if (!f.exists()) return emptyList()
        return try {
            val arr = JSONObject(f.readText()).getJSONArray("songs")
            buildList { for (i in 0 until arr.length()) add(arr.getJSONObject(i)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun saveUserImport(id: String, catalogEntry: JSONObject, scoreJson: String, musicXml: String) {
        userDir.resolve("$id.json").writeText(scoreJson)
        userDir.resolve("musicxml/$id.musicxml").parentFile?.mkdirs()
        userDir.resolve("musicxml/$id.musicxml").writeText(musicXml)
        val existing = loadUserCatalogEntries().filter { it.getString("id") != id }
        val all = JSONArray()
        existing.forEach { all.put(it) }
        all.put(catalogEntry)
        userDir.resolve("user_catalog.json").writeText(JSONObject().put("songs", all).toString(2))
    }

    fun deleteUserImport(id: String) {
        userDir.resolve("$id.json").delete()
        userDir.resolve("musicxml/$id.musicxml").delete()
        val remaining = loadUserCatalogEntries().filter { it.getString("id") != id }
        val all = JSONArray()
        remaining.forEach { all.put(it) }
        userDir.resolve("user_catalog.json").writeText(JSONObject().put("songs", all).toString(2))
        val fav = HashSet(getFavorites())
        if (fav.remove(id)) prefs.edit().putStringSet("favorites", HashSet(fav)).apply()
    }

    fun readUserScoreJson(id: String): String? =
        userDir.resolve("$id.json").takeIf { it.exists() }?.readText()

    fun readUserMusicXml(id: String): String? =
        userDir.resolve("musicxml/$id.musicxml").takeIf { it.exists() }?.readText()
}

data class AuthState(val email: String?, val name: String, val guest: Boolean) {
    companion object {
        fun guest() = AuthState(null, "访客", true)
    }
}
