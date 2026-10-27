package com.zamcan.desksuite

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var ocr: OcrChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = OcrChannel(applicationContext)
        ocr = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OcrChannel.CHANNEL)
            .setMethodCallHandler(channel)
    }

    override fun onDestroy() {
        ocr?.close()
        ocr = null
        super.onDestroy()
    }
}
