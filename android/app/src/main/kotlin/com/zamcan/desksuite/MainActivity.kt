package com.zamcan.desksuite

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var ocr: OcrChannel? = null
    private var documentCameraResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = OcrChannel(applicationContext)
        ocr = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OcrChannel.CHANNEL)
            .setMethodCallHandler(channel)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOCUMENT_CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capture" -> {
                        if (documentCameraResult != null) {
                            result.error("camera_busy", "A capture is already in progress.", null)
                        } else {
                            documentCameraResult = result
                            try {
                                startActivityForResult(
                                    Intent(this, DocumentCameraActivity::class.java),
                                    DOCUMENT_CAMERA_REQUEST,
                                )
                            } catch (_: Exception) {
                                documentCameraResult = null
                                result.error(
                                    "camera_unavailable",
                                    "DeskSuite could not start its document camera.",
                                    null,
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Required to receive the app-owned document camera result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == DOCUMENT_CAMERA_REQUEST) {
            val pending = documentCameraResult
            documentCameraResult = null
            if (pending != null) {
                if (resultCode == Activity.RESULT_OK) {
                    val path = data?.getStringExtra(DocumentCameraActivity.EXTRA_CAPTURE_PATH)
                    if (path.isNullOrBlank()) {
                        pending.error("camera_result_missing", "The captured image was not returned.", null)
                    } else {
                        pending.success(path)
                    }
                } else {
                    val reason = data?.getStringExtra(DocumentCameraActivity.EXTRA_ERROR) ?: "cancelled"
                    if (reason == "cancelled") {
                        pending.success(null)
                    } else {
                        pending.error(reason, "The document camera could not complete the capture.", null)
                    }
                }
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        ocr?.close()
        ocr = null
        documentCameraResult = null
        super.onDestroy()
    }

    private companion object {
        const val DOCUMENT_CAMERA_CHANNEL = "com.zamcan.desksuite/document_camera"
        const val DOCUMENT_CAMERA_REQUEST = 6041
    }
}
