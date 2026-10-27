package com.zamcan.desksuite

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Offline OCR bridge over Tesseract 5 (Tesseract4Android).
 *
 * Everything runs on the device. The language models are shipped as Flutter
 * assets and copied once into app-private storage, because Tesseract requires a
 * readable `tessdata` directory and, from Android 10, only app-private paths are
 * reliably usable.
 */
class OcrChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.zamcan.desksuite/ocr"

        /** Bundled language models, kept in sync with assets/tessdata/. */
        val LANGUAGES = listOf("eng", "swa")

        /** Refuse images beyond this so recognition cannot exhaust memory. */
        const val MAX_PIXELS = 24_000_000L
        const val MAX_DIMENSION = 4000
    }

    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "desksuite-ocr").apply { isDaemon = true }
    }
    private val mainThread = Handler(Looper.getMainLooper())

    /** TessBaseAPI is not thread-safe; one instance, used from [worker] only. */
    private var engine: TessBaseAPI? = null
    private var engineLanguages: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(verifyModels())
            "availableLanguages" -> result.success(installedLanguages())
            "recognize" -> recognize(call, result)
            else -> result.notImplemented()
        }
    }

    /** Releases the native engine and the worker thread. */
    fun close() {
        try {
            engine?.recycle()
        } catch (_: Throwable) {
            // The engine may already be released by the native layer.
        }
        engine = null
        engineLanguages = null
        worker.shutdownNow()
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val language = call.argument<String>("language") ?: "eng"
        if (bytes == null || bytes.isEmpty()) {
            result.error("empty", "The image is empty.", null)
            return
        }
        val requested = language.split('+').filter { it.isNotBlank() }
        if (requested.isEmpty() || requested.any { it !in LANGUAGES }) {
            result.error("language", "Unsupported recognition language: $language", null)
            return
        }
        worker.execute {
            try {
                val outcome = runRecognition(bytes, language)
                mainThread.post { result.success(outcome) }
            } catch (error: RecognitionException) {
                mainThread.post { result.error(error.code, error.message, null) }
            } catch (error: Throwable) {
                mainThread.post {
                    result.error("ocr_failed", "Recognition failed: ${error.javaClass.simpleName}", null)
                }
            }
        }
    }

    private class RecognitionException(val code: String, message: String) : Exception(message)

    private fun runRecognition(bytes: ByteArray, language: String): Map<String, Any> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw RecognitionException("decode", "The image could not be decoded.")
        }
        val pixels = bounds.outWidth.toLong() * bounds.outHeight.toLong()
        if (pixels > MAX_PIXELS) {
            throw RecognitionException("too_large", "The image is too large for offline recognition.")
        }
        var sample = 1
        while ((bounds.outWidth / sample) > MAX_DIMENSION || (bounds.outHeight / sample) > MAX_DIMENSION) {
            sample *= 2
        }
        val bitmap = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
        ) ?: throw RecognitionException("decode", "The image could not be decoded.")

        val api = obtainEngine(language)
        api.setImage(bitmap)
        val text = api.utF8Text ?: ""
        val words = ArrayList<Map<String, Any>>()
        val iterator = api.resultIterator
        if (iterator != null) {
            try {
                iterator.begin()
                do {
                    val word = iterator.getUTF8Text(TessBaseAPI.PageIteratorLevel.RIL_WORD)?.trim()
                    val box = iterator.getBoundingBox(TessBaseAPI.PageIteratorLevel.RIL_WORD)
                    if (!word.isNullOrEmpty() && box != null && box.size == 4) {
                        words.add(
                            mapOf(
                                "text" to word,
                                "left" to box[0],
                                "top" to box[1],
                                "right" to box[2],
                                "bottom" to box[3],
                                "confidence" to iterator.confidence(TessBaseAPI.PageIteratorLevel.RIL_WORD).toDouble(),
                            )
                        )
                    }
                } while (iterator.next(TessBaseAPI.PageIteratorLevel.RIL_WORD))
            } finally {
                iterator.delete()
            }
        }
        val width = bitmap.width
        val height = bitmap.height
        api.clear()
        bitmap.recycle()
        return mapOf(
            "text" to text.trimEnd('\n'),
            "words" to words,
            "width" to width,
            "height" to height,
            "language" to language,
        )
    }

    /** Reuses one initialized engine; reinitializes only when the language set changes. */
    private fun obtainEngine(language: String): TessBaseAPI {
        engine?.let { existing ->
            if (engineLanguages == language) return existing
            existing.recycle()
            engine = null
        }
        ensureModels(language.split('+'))
        val directory = tessdataRoot()
        val created = TessBaseAPI()
        if (!created.init(directory.absolutePath, language)) {
            created.recycle()
            throw RecognitionException(
                "model",
                "The offline OCR model for '$language' could not be loaded."
            )
        }
        created.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
        engine = created
        engineLanguages = language
        return created
    }

    private fun tessdataRoot(): File = File(context.filesDir, "tesseract")

    private fun tessdataDirectory(): File = File(tessdataRoot(), "tessdata")

    private fun installedLanguages(): List<String> =
        LANGUAGES.filter { File(tessdataDirectory(), "$it.traineddata").exists() }

    private fun verifyModels(): Boolean {
        return try {
            ensureModels(LANGUAGES)
            installedLanguages().isNotEmpty()
        } catch (error: IOException) {
            false
        }
    }

    /**
     * Copies bundled models out of the APK once. A truncated previous copy is
     * detected by size and replaced, so a failed first run cannot poison later
     * attempts.
     */
    private fun ensureModels(languages: List<String>) {
        val target = tessdataDirectory()
        if (!target.exists() && !target.mkdirs()) {
            throw IOException("App-private OCR model directory could not be created.")
        }
        for (language in languages) {
            if (language !in LANGUAGES) continue
            val assetName = "flutter_assets/assets/tessdata/$language.traineddata"
            val destination = File(target, "$language.traineddata")
            val marker = File(target, "$language.complete")
            if (destination.exists() && marker.exists() &&
                marker.readText().trim() == destination.length().toString() &&
                destination.length() > 0
            ) {
                continue
            }
            val partial = File(target, "$language.traineddata.part")
            var copied = 0L
            try {
                context.assets.open(assetName).use { input ->
                    partial.outputStream().use { output ->
                        copied = input.copyTo(output, DEFAULT_BUFFER_SIZE)
                    }
                }
            } catch (error: IOException) {
                partial.delete()
                throw IOException("Bundled OCR model $language is missing from this build.")
            }
            if (copied <= 0L || partial.length() != copied) {
                partial.delete()
                throw IOException("Bundled OCR model $language could not be copied completely.")
            }
            if (destination.exists() && !destination.delete()) {
                partial.delete()
                throw IOException("The previous OCR model copy could not be replaced.")
            }
            if (!partial.renameTo(destination)) {
                partial.delete()
                throw IOException("The OCR model could not be moved into place.")
            }
            marker.writeText(copied.toString())
        }
    }
}
