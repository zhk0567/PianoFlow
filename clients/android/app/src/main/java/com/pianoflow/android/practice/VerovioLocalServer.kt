package com.pianoflow.android.practice

import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * Serves Verovio viewer + MusicXML on 127.0.0.1 (same pattern as Flutter Windows).
 */
class VerovioLocalServer(private val context: Context) {
    private var server: ServerSocket? = null
    private val alive = AtomicBoolean(false)
    var port: Int = 0
        private set
    private var root: File? = null

    fun ensureReady(): Int {
        if (alive.get() && port > 0 && root != null) return port
        val dir = File(context.cacheDir, "verovio_host").apply { mkdirs() }
        copyAsset("verovio/viewer.html", File(dir, "viewer.html"))
        copyAsset("verovio/verovio-toolkit-wasm.js", File(dir, "verovio-toolkit-wasm.js"))
        root = dir
        val sock = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        port = sock.localPort
        server = sock
        alive.set(true)
        thread(name = "pf-verovio-http", isDaemon = true) {
            Log.i("PianoFlow/Verovio", "HTTP http://127.0.0.1:$port/")
            while (alive.get()) {
                try {
                    val client = sock.accept()
                    thread(isDaemon = true) { serve(client) }
                } catch (e: Exception) {
                    if (alive.get()) Log.e("PianoFlow/Verovio", "accept: $e")
                }
            }
        }
        return port
    }

    fun writeScore(xml: String) {
        val r = root ?: return
        File(r, "current_score.musicxml").writeText(xml)
    }

    fun stop() {
        alive.set(false)
        try {
            server?.close()
        } catch (_: Exception) {
        }
        server = null
    }

    private fun copyAsset(name: String, out: File) {
        if (out.exists() && out.length() > 1000) return
        context.assets.open(name).use { input ->
            out.outputStream().use { input.copyTo(it) }
        }
    }

    private fun serve(client: java.net.Socket) {
        client.use { c ->
            val input = c.getInputStream().bufferedReader()
            val req = input.readLine() ?: return
            val path = req.split(" ").getOrNull(1)?.substringBefore("?") ?: "/viewer.html"
            val rel = when {
                path == "/" || path.isEmpty() -> "viewer.html"
                path.startsWith("/") -> path.substring(1)
                else -> path
            }
            val rootDir = root ?: return
            val file = File(rootDir, rel).canonicalFile
            if (!file.path.startsWith(rootDir.canonicalPath) || !file.exists()) {
                val out = c.getOutputStream()
                out.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n".toByteArray())
                return
            }
            val bytes = file.readBytes()
            val ctype = when {
                rel.endsWith(".html") -> "text/html; charset=utf-8"
                rel.endsWith(".js") -> "application/javascript; charset=utf-8"
                rel.endsWith(".wasm") -> "application/wasm"
                rel.endsWith(".musicxml") || rel.endsWith(".xml") -> "application/xml; charset=utf-8"
                else -> "application/octet-stream"
            }
            val header =
                "HTTP/1.1 200 OK\r\nContent-Type: $ctype\r\nContent-Length: ${bytes.size}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            val out = c.getOutputStream()
            out.write(header.toByteArray())
            out.write(bytes)
            out.flush()
        }
    }
}
