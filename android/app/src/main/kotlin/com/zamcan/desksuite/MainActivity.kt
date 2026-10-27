package com.zamcan.desksuite

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.zamcan.desksuite/external_files",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val name = call.argument<String>("name") ?: "document"
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) {
                result.error("EMPTY_FILE", "The selected file is empty.", null)
                return@setMethodCallHandler
            }
            if (bytes.size > 50 * 1024 * 1024) {
                result.error("FILE_TOO_LARGE", "The selected file exceeds 50 MB.", null)
                return@setMethodCallHandler
            }

            try {
                val directory = File(cacheDir, "external_documents")
                if (!directory.exists() && !directory.mkdirs()) {
                    result.error("CACHE_ERROR", "Could not prepare temporary file storage.", null)
                    return@setMethodCallHandler
                }
                val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(120)
                    .ifBlank { "document" }
                val output = File(directory, "${System.currentTimeMillis()}_$safeName")
                output.writeBytes(bytes)

                // Keep only a small recent cache; never write into shared user folders.
                directory.listFiles()
                    ?.filter { it != output && System.currentTimeMillis() - it.lastModified() > 2L * 24 * 60 * 60 * 1000 }
                    ?.forEach { it.delete() }

                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    output,
                )
                val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(viewIntent, "Open with"))
                result.success(null)
            } catch (error: ActivityNotFoundException) {
                result.error(
                    "NO_VIEWER",
                    "No installed app can open this file type. Install a compatible viewer or editor and try again.",
                    null,
                )
            } catch (error: Exception) {
                result.error("OPEN_FAILED", "Could not open the selected file: ${error.message}", null)
            }
        }
    }
}
