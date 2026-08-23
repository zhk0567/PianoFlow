package com.pianoflow.android.data

import android.content.Context
import java.io.File

/** PDF staging — full OMR requires Windows Audiveris pipeline. */
object PdfWorkshopStage {
    fun stage(ctx: Context, srcPath: String, fileName: String): String {
        val dir = File(ctx.filesDir, "pdf_inbox").apply { mkdirs() }
        val id = "user_pdf_${fileName.replace(Regex("[^a-zA-Z0-9\\u4e00-\\u9fff]"), "_").take(30)}"
        val dest = File(dir, "$id.pdf")
        File(srcPath).copyTo(dest, overwrite = true)
        android.util.Log.i("PianoFlow/Workshop", "PDF staged ${dest.absolutePath}")
        return "PDF 已暂存：${dest.name}\n\n完整 OMR 一键请用 Windows：\n将 PDF 放入 user_import/pdf_inbox 后运行 scripts/omr-from-pdf.ps1\n（Web/Android 无法本机 Audiveris）"
    }
}
