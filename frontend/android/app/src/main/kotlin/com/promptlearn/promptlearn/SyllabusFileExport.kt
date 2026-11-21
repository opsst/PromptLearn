package com.promptlearn.promptlearn

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebView
import android.widget.Toast
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

internal class SyllabusFileExport(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "promptlearn/syllabus_export")
    private var pending: PendingExport? = null
    private var preview: AlertDialog? = null

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    @Suppress("DEPRECATION")
    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveHtml") {
            result.notImplemented()
            return
        }
        val fileName = call.argument<String>("fileName")
        val contents = call.argument<ByteArray>("contents")
        if (fileName.isNullOrBlank() || contents == null || contents.isEmpty()) {
            result.error("invalid_document", "An HTML filename and document are required.", null)
            return
        }
        if (pending != null) {
            result.error("export_in_progress", "Another syllabus export is in progress.", null)
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("text/html")
            .putExtra(Intent.EXTRA_TITLE, fileName)
        pending = PendingExport(contents, result)
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (exception: ActivityNotFoundException) {
            pending = null
            result.error("file_picker_unavailable", "Android could not open the file picker.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val export = pending ?: return
        if (resultCode != Activity.RESULT_OK) {
            pending = null
            export.result.success(false)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pending = null
            export.result.error("missing_document", "Android did not return a file destination.", null)
            return
        }

        Thread {
            val saved = runCatching {
                val stream = activity.contentResolver.openOutputStream(uri, "w")
                    ?: throw IOException("Could not open the file destination")
                stream.use { it.write(export.contents) }
            }
            activity.runOnUiThread {
                if (pending !== export) return@runOnUiThread
                pending = null
                if (saved.isSuccess) {
                    export.result.success(true)
                    showPreview(export.contents)
                } else {
                    export.result.error("write_failed", "Could not write the syllabus file.", null)
                }
            }
        }.start()
    }

    private fun showPreview(contents: ByteArray) {
        if (activity.isFinishing || activity.isDestroyed) return
        preview?.dismiss()
        var webView: WebView? = null
        try {
            val document = WebView(activity)
            webView = document
            document.settings.allowFileAccess = false
            document.settings.allowContentAccess = false
            document.settings.blockNetworkLoads = true
            document.loadDataWithBaseURL(null, contents.toString(Charsets.UTF_8), "text/html", "UTF-8", null)
            val dialog = AlertDialog.Builder(activity, android.R.style.Theme_Material_Light_Dialog_Alert)
                .setTitle("Course syllabus")
                .setView(document)
                .setPositiveButton("Close", null)
                .create()
            dialog.setOnDismissListener {
                if (preview === dialog) preview = null
                destroyPreview(document)
            }
            dialog.show()
            dialog.window?.setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
            )
            preview = dialog
        } catch (_: RuntimeException) {
            webView?.let(::destroyPreview)
            Toast.makeText(activity, "File saved. Could not open the preview.", Toast.LENGTH_LONG).show()
        }
    }

    private fun destroyPreview(document: WebView) {
        (document.parent as? ViewGroup)?.removeView(document)
        document.destroy()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pending?.result?.success(false)
        pending = null
        preview?.dismiss()
    }

    private data class PendingExport(val contents: ByteArray, val result: MethodChannel.Result)

    private companion object {
        const val REQUEST_CODE = 403
    }
}
