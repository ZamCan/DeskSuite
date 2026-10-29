package com.zamcan.desksuite

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.SurfaceTexture
import android.graphics.Matrix
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageFormat
import android.media.ImageReader
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.view.Gravity
import android.view.Surface
import android.view.TextureView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.drawable.GradientDrawable
import android.util.Size
import android.widget.Toast
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/// A first-party Camera2 screen. It owns the live preview and still capture,
/// rather than invoking the device's external camera application.
class DocumentCameraActivity : Activity(), TextureView.SurfaceTextureListener {
    private lateinit var preview: TextureView
    private lateinit var guide: ScanGuideView
    private lateinit var cameraManager: CameraManager
    private lateinit var flashButton: TextView
    private lateinit var shutter: TextView
    private lateinit var zoomLabel: TextView
    private var cameraDevice: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var previewRequest: CaptureRequest.Builder? = null
    private var previewSurface: Surface? = null
    private var imageReader: ImageReader? = null
    private var previewSize: Size? = null
    private var stillSize: Size? = null
    private var cameraId: String? = null
    private var sensorOrientation = 90
    private var activeArray: Rect? = null
    private var maxZoom = 1f
    private var zoom = 1f
    private var hasFlash = false
    private var flashOn = false
    private var opening = false
    private val capturing = AtomicBoolean(false)
    private var thread: HandlerThread? = null
    private var handler: Handler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.rgb(11, 21, 37)
        window.navigationBarColor = Color.rgb(11, 21, 37)
        window.decorView.systemUiVisibility = 0
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        buildInterface()
    }

    override fun onResume() {
        super.onResume()
        startCameraThread()
        if (::preview.isInitialized && preview.isAvailable) startCameraIfReady()
    }

    override fun onPause() {
        closeCamera()
        super.onPause()
    }

    override fun onDestroy() {
        stopCameraThread()
        super.onDestroy()
    }

    private fun buildInterface() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        preview = TextureView(this).also { it.surfaceTextureListener = this }
        root.addView(preview, FrameLayout.LayoutParams(-1, -1))

        guide = ScanGuideView(this)
        root.addView(guide, FrameLayout.LayoutParams(-1, -1))

        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(8), dp(10), dp(8))
            background = rounded(Color.argb(206, 15, 29, 47), 22)
        }
        val back = textButton("Back", 16).apply {
            setOnClickListener { finishCancelled() }
        }
        top.addView(back, LinearLayout.LayoutParams(dp(70), dp(48)))
        val title = TextView(this).apply {
            text = "Scan document"
            setTextColor(Color.WHITE)
            textSize = 17f
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
        }
        top.addView(title, LinearLayout.LayoutParams(0, dp(48), 1f))
        flashButton = textButton("Flash off", 13).apply {
            setOnClickListener { toggleFlash() }
        }
        top.addView(flashButton, LinearLayout.LayoutParams(dp(88), dp(48)))
        val topParams = FrameLayout.LayoutParams(-1, -2, Gravity.TOP)
        topParams.setMargins(dp(14), dp(18), dp(14), 0)
        root.addView(top, topParams)

        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(18), dp(12), dp(18), dp(16))
            background = rounded(Color.argb(224, 15, 29, 47), 26)
        }
        val hint = TextView(this).apply {
            text = "Keep all four page edges visible"
            setTextColor(Color.rgb(231, 241, 249))
            textSize = 13f
            gravity = Gravity.CENTER
        }
        bottom.addView(hint, LinearLayout.LayoutParams(-1, dp(28)))
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val minus = textButton("−", 28).apply {
            setOnClickListener { changeZoom(-0.25f) }
        }
        controls.addView(minus, LinearLayout.LayoutParams(dp(64), dp(62)))
        shutter = TextView(this).apply {
            text = "●"
            textSize = 45f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(21, 59, 102))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(dp(4), Color.rgb(38, 198, 218))
            }
            contentDescription = "Capture page"
            isClickable = true
            isFocusable = true
            isEnabled = false
            setOnClickListener { captureStill() }
        }
        val shutterParams = LinearLayout.LayoutParams(dp(76), dp(76))
        shutterParams.setMargins(dp(22), 0, dp(22), 0)
        controls.addView(shutter, shutterParams)
        val plus = textButton("+", 26).apply {
            setOnClickListener { changeZoom(0.25f) }
        }
        controls.addView(plus, LinearLayout.LayoutParams(dp(64), dp(62)))
        bottom.addView(controls, LinearLayout.LayoutParams(-1, dp(84)))
        zoomLabel = TextView(this).apply {
            text = "1.0×"
            setTextColor(Color.rgb(165, 233, 240))
            textSize = 12f
            gravity = Gravity.CENTER
        }
        bottom.addView(zoomLabel, LinearLayout.LayoutParams(-1, dp(20)))
        val bottomParams = FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM)
        bottomParams.setMargins(dp(14), 0, dp(14), dp(16))
        root.addView(bottom, bottomParams)
        setContentView(root)
    }

    private fun textButton(label: String, size: Int) = TextView(this).apply {
        text = label
        textSize = size.toFloat()
        setTextColor(Color.WHITE)
        gravity = Gravity.CENTER
        isClickable = true
        isFocusable = true
        background = rounded(Color.argb(74, 255, 255, 255), 16)
    }

    private fun rounded(color: Int, radius: Int) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = dp(radius).toFloat()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun startCameraThread() {
        if (thread != null) return
        thread = HandlerThread("DeskSuiteCamera2").also { it.start() }
        handler = Handler(thread!!.looper)
    }

    private fun stopCameraThread() {
        thread?.quitSafely()
        try {
            thread?.join()
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        thread = null
        handler = null
    }

    private fun startCameraIfReady() {
        if (!preview.isAvailable || cameraDevice != null || opening) return
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA_PERMISSION)
            return
        }
        try {
            val id = cameraManager.cameraIdList.firstOrNull { candidate ->
                cameraManager.getCameraCharacteristics(candidate)
                    .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: cameraManager.cameraIdList.firstOrNull()
                ?: return finishWithError("camera_unavailable")
            cameraId = id
            val characteristics = cameraManager.getCameraCharacteristics(id)
            sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            activeArray = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            maxZoom = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
            hasFlash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            flashButton.text = if (hasFlash) "Flash off" else "No flash"
            flashButton.isEnabled = hasFlash

            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return finishWithError("camera_unavailable")
            val jpegs = map.getOutputSizes(ImageFormat.JPEG)?.toList().orEmpty()
            stillSize = jpegs.filter { it.width.toLong() * it.height <= MAX_STILL_PIXELS }
                .maxByOrNull { it.width.toLong() * it.height }
                ?: jpegs.maxByOrNull { it.width.toLong() * it.height }
                ?: return finishWithError("camera_unavailable")
            val ratio = stillSize!!.width.toDouble() / stillSize!!.height
            val previews = map.getOutputSizes(SurfaceTexture::class.java)?.toList().orEmpty()
            previewSize = previews.minByOrNull {
                abs(it.width.toDouble() / it.height - ratio) * 10000.0 +
                    abs(it.width.toLong() * it.height - 1280L * 720L).toDouble() / 1000.0
            } ?: stillSize
            opening = true
            cameraManager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    opening = false
                    cameraDevice = camera
                    if (!isFinishing && preview.isAvailable) createPreviewSession()
                    else camera.close()
                }
                override fun onDisconnected(camera: CameraDevice) {
                    opening = false
                    camera.close()
                    if (cameraDevice === camera) cameraDevice = null
                    finishWithError("camera_unavailable")
                }
                override fun onError(camera: CameraDevice, error: Int) {
                    opening = false
                    camera.close()
                    if (cameraDevice === camera) cameraDevice = null
                    finishWithError("camera_unavailable")
                }
            }, handler)
            configureTransform(preview.width, preview.height)
        } catch (_: SecurityException) {
            opening = false
            finishWithError("camera_permission_denied")
        } catch (_: CameraAccessException) {
            opening = false
            finishWithError("camera_unavailable")
        } catch (_: RuntimeException) {
            opening = false
            finishWithError("camera_unavailable")
        }
    }

    private fun createPreviewSession() {
        val device = cameraDevice ?: return
        val texture = preview.surfaceTexture ?: return
        val buffer = previewSize ?: return
        val still = stillSize ?: return
        try {
            texture.setDefaultBufferSize(buffer.width, buffer.height)
            previewSurface?.release()
            previewSurface = Surface(texture)
            imageReader?.close()
            imageReader = ImageReader.newInstance(still.width, still.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                val image = reader.acquireNextImage() ?: return@setOnImageAvailableListener
                val bytes = try {
                    val plane = image.planes[0].buffer
                    ByteArray(plane.remaining()).also { plane.get(it) }
                } finally {
                    image.close()
                }
                try {
                    if (bytes.isEmpty() || bytes.size > MAX_CAPTURE_BYTES) {
                        throw IllegalStateException("Captured image exceeded the scanner limit.")
                    }
                    val file = File(cacheDir, "desksuite-capture-${System.currentTimeMillis()}.jpg")
                    file.writeBytes(bytes)
                    runOnUiThread {
                        setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_CAPTURE_PATH, file.absolutePath))
                        finish()
                    }
                } catch (_: Exception) {
                    runOnUiThread {
                        capturing.set(false)
                        shutter.isEnabled = true
                        Toast.makeText(this, "Could not save the capture. Try again.", Toast.LENGTH_LONG).show()
                    }
                }
            }, handler)

            device.createCaptureSession(
                listOf(previewSurface!!, imageReader!!.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(configured: CameraCaptureSession) {
                        if (cameraDevice !== device || isFinishing) {
                            configured.close()
                            return
                        }
                        session = configured
                        val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                        builder.addTarget(previewSurface!!)
                        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                        previewRequest = builder
                        applyPreviewControls(builder)
                        try {
                            configured.setRepeatingRequest(builder.build(), null, handler)
                            runOnUiThread {
                                shutter.isEnabled = true
                                shutter.contentDescription = "Capture page"
                            }
                        } catch (_: CameraAccessException) {
                            finishWithError("camera_unavailable")
                        }
                    }
                    override fun onConfigureFailed(configured: CameraCaptureSession) {
                        configured.close()
                        finishWithError("camera_unavailable")
                    }
                },
                handler,
            )
        } catch (_: CameraAccessException) {
            finishWithError("camera_unavailable")
        } catch (_: IllegalArgumentException) {
            finishWithError("camera_unavailable")
        }
    }

    private fun applyPreviewControls(builder: CaptureRequest.Builder) {
        activeArray?.let { active ->
            val factor = zoom.coerceIn(1f, maxZoom)
            val width = (active.width() / factor).toInt()
            val height = (active.height() / factor).toInt()
            val left = active.centerX() - width / 2
            val top = active.centerY() - height / 2
            builder.set(CaptureRequest.SCALER_CROP_REGION, Rect(left, top, left + width, top + height))
        }
        builder.set(
            CaptureRequest.FLASH_MODE,
            if (hasFlash && flashOn) CaptureRequest.FLASH_MODE_TORCH else CaptureRequest.FLASH_MODE_OFF,
        )
    }

    private fun changeZoom(delta: Float) {
        zoom = (zoom + delta).coerceIn(1f, maxZoom)
        zoomLabel.text = String.format("%.1f×", zoom)
        previewRequest?.let { builder ->
            applyPreviewControls(builder)
            try {
                session?.setRepeatingRequest(builder.build(), null, handler)
            } catch (_: CameraAccessException) {
                finishWithError("camera_unavailable")
            }
        }
    }

    private fun toggleFlash() {
        if (!hasFlash) return
        flashOn = !flashOn
        flashButton.text = if (flashOn) "Flash on" else "Flash off"
        previewRequest?.let { builder ->
            applyPreviewControls(builder)
            try {
                session?.setRepeatingRequest(builder.build(), null, handler)
            } catch (_: CameraAccessException) {
                finishWithError("camera_unavailable")
            }
        }
    }

    private fun captureStill() {
        val device = cameraDevice ?: return
        val reader = imageReader ?: return
        val activeSession = session ?: return
        if (!shutter.isEnabled || !capturing.compareAndSet(false, true)) return
        shutter.isEnabled = false
        shutter.text = "…"
        try {
            val request = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                addTarget(reader.surface)
                set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation())
                applyPreviewControls(this)
            }
            activeSession.capture(request.build(), object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureFailed(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    failure: CameraCaptureSession.CaptureFailure,
                ) {
                    runOnUiThread {
                        capturing.set(false)
                        shutter.isEnabled = true
                        shutter.text = "●"
                        Toast.makeText(this@DocumentCameraActivity, "Capture failed. Hold steady and retry.", Toast.LENGTH_LONG).show()
                    }
                }
            }, handler)
        } catch (_: CameraAccessException) {
            capturing.set(false)
            shutter.isEnabled = true
            shutter.text = "●"
            Toast.makeText(this, "Camera is temporarily unavailable.", Toast.LENGTH_LONG).show()
        }
    }

    private fun jpegOrientation(): Int {
        val rotation = when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
        return (sensorOrientation + rotation + 360) % 360
    }

    private fun configureTransform(width: Int, height: Int) {
        val buffer = previewSize ?: return
        if (width == 0 || height == 0) return
        val matrix = Matrix()
        val view = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val rotated = windowManager.defaultDisplay.rotation == Surface.ROTATION_90 ||
            windowManager.defaultDisplay.rotation == Surface.ROTATION_270
        val bufferRect = if (rotated) {
            RectF(0f, 0f, buffer.height.toFloat(), buffer.width.toFloat())
        } else {
            RectF(0f, 0f, buffer.width.toFloat(), buffer.height.toFloat())
        }
        bufferRect.offset(view.centerX() - bufferRect.centerX(), view.centerY() - bufferRect.centerY())
        matrix.setRectToRect(view, bufferRect, Matrix.ScaleToFit.FILL)
        val scale = max(
            height.toFloat() / if (rotated) buffer.height else buffer.height,
            width.toFloat() / if (rotated) buffer.width else buffer.width,
        )
        matrix.postScale(scale, scale, view.centerX(), view.centerY())
        val degrees = when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90f
            Surface.ROTATION_180 -> 180f
            Surface.ROTATION_270 -> 270f
            else -> 0f
        }
        matrix.postRotate(degrees, view.centerX(), view.centerY())
        preview.setTransform(matrix)
    }

    private fun closeCamera() {
        try {
            session?.close()
            session = null
            cameraDevice?.close()
            cameraDevice = null
            imageReader?.close()
            imageReader = null
            previewSurface?.release()
            previewSurface = null
            opening = false
        } catch (_: Exception) {
            // Closing resources is best-effort during Activity recreation.
        }
    }

    private fun finishCancelled() {
        setResult(Activity.RESULT_CANCELED, Intent().putExtra(EXTRA_ERROR, "cancelled"))
        finish()
    }

    private fun finishWithError(code: String) {
        if (isFinishing) return
        setResult(Activity.RESULT_CANCELED, Intent().putExtra(EXTRA_ERROR, code))
        finish()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CAMERA_PERMISSION) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCameraIfReady()
            } else {
                finishWithError("camera_permission_denied")
            }
        }
    }

    override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
        startCameraIfReady()
    }

    override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
        configureTransform(width, height)
    }

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean = true

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    companion object {
        const val EXTRA_CAPTURE_PATH = "com.zamcan.desksuite.EXTRA_CAPTURE_PATH"
        const val EXTRA_ERROR = "com.zamcan.desksuite.EXTRA_ERROR"
        private const val REQUEST_CAMERA_PERMISSION = 6042
        private const val MAX_STILL_PIXELS = 6_000_000L
        private const val MAX_CAPTURE_BYTES = 8 * 1024 * 1024
    }
}

private class ScanGuideView(context: Context) : View(context) {
    private val framePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(145, 255, 255, 255)
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * resources.displayMetrics.density
    }
    private val cornerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(38, 198, 218)
        style = Paint.Style.STROKE
        strokeWidth = 4.5f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val left = width * .10f
        val right = width * .90f
        val top = height * .20f
        val bottom = height * .77f
        val radius = 16f * resources.displayMetrics.density
        canvas.drawRoundRect(RectF(left, top, right, bottom), radius, radius, framePaint)
        val length = min(width, height) * .09f
        drawCorner(canvas, left, top, 1f, 1f, length)
        drawCorner(canvas, right, top, -1f, 1f, length)
        drawCorner(canvas, right, bottom, -1f, -1f, length)
        drawCorner(canvas, left, bottom, 1f, -1f, length)
    }

    private fun drawCorner(canvas: Canvas, x: Float, y: Float, dx: Float, dy: Float, length: Float) {
        canvas.drawLine(x, y, x + dx * length, y, cornerPaint)
        canvas.drawLine(x, y, x, y + dy * length, cornerPaint)
    }
}
