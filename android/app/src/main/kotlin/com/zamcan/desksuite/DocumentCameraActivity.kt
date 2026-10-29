package com.zamcan.desksuite

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.ImageFormat
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
import android.hardware.camera2.CaptureFailure
import android.media.ImageReader
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.view.Gravity
import android.view.OrientationEventListener
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
import java.io.FileOutputStream
import java.util.UUID
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
    private lateinit var zoomOutButton: TextView
    private lateinit var zoomInButton: TextView
    private var cameraDevice: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var previewRequest: CaptureRequest.Builder? = null
    private var previewSurface: Surface? = null
    private var imageReader: ImageReader? = null
    private var previewSize: Size? = null
    private var stillSize: Size? = null
    private var frontFacing = false
    private var sensorOrientation = 90
    private var activeArray: Rect? = null
    private var maxZoom = 1f
    private var zoom = 1f
    private var hasFlash = false
    private var flashOn = false
    private var autofocusMode = CaptureRequest.CONTROL_AF_MODE_OFF
    // Camera-device/session callbacks are delivered on the main looper. A
    // generation prevents a late open/configure callback from reviving the
    // camera after pause or after its TextureView has been destroyed.
    private var opening = false
    private var permissionRequestPending = false
    private var cameraResumed = false
    private var cameraGeneration = 0L
    private val capturing = AtomicBoolean(false)
    private var physicalOrientation = OrientationEventListener.ORIENTATION_UNKNOWN
    private val orientationListener by lazy {
        object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation != OrientationEventListener.ORIENTATION_UNKNOWN) {
                    physicalOrientation = ((orientation + 45) / 90 * 90) % 360
                }
            }
        }
    }
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
        cameraResumed = true
        physicalOrientation = OrientationEventListener.ORIENTATION_UNKNOWN
        if (orientationListener.canDetectOrientation()) orientationListener.enable()
        startCameraThread()
        if (::preview.isInitialized && preview.isAvailable) startCameraIfReady()
    }

    override fun onPause() {
        cameraResumed = false
        orientationListener.disable()
        cameraGeneration++
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
        flashButton = textButton("Checking…", 13).apply {
            isEnabled = false
            alpha = .55f
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
        zoomOutButton = textButton("−", 28).apply {
            contentDescription = "Zoom out"
            isEnabled = false
            alpha = .45f
            setOnClickListener { changeZoom(-0.25f) }
        }
        controls.addView(zoomOutButton, LinearLayout.LayoutParams(dp(64), dp(62)))
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
        zoomInButton = textButton("+", 26).apply {
            contentDescription = "Zoom in"
            isEnabled = false
            alpha = .45f
            setOnClickListener { changeZoom(0.25f) }
        }
        controls.addView(zoomInButton, LinearLayout.LayoutParams(dp(64), dp(62)))
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
        if (!cameraResumed || isFinishing || !preview.isAvailable || cameraDevice != null || opening) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED
        ) {
            // onResume and SurfaceTexture callbacks can arrive together. Only
            // one system permission request may be outstanding at a time.
            if (!permissionRequestPending) {
                permissionRequestPending = true
                try {
                    requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA_PERMISSION)
                } catch (_: RuntimeException) {
                    permissionRequestPending = false
                    finishWithError("camera_permission_denied")
                }
            }
            return
        }
        try {
            val id = cameraManager.cameraIdList.firstOrNull { candidate ->
                cameraManager.getCameraCharacteristics(candidate)
                    .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: cameraManager.cameraIdList.firstOrNull()
                ?: return finishWithError("camera_unavailable")
            val characteristics = cameraManager.getCameraCharacteristics(id)
            frontFacing = characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            activeArray = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            val reportedZoom = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1f
            maxZoom = if (reportedZoom.isFinite()) max(1f, reportedZoom) else 1f
            zoom = zoom.coerceIn(1f, maxZoom)
            hasFlash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            val afModes = characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES) ?: intArrayOf()
            autofocusMode = when {
                afModes.contains(CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) -> CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                afModes.contains(CaptureRequest.CONTROL_AF_MODE_AUTO) -> CaptureRequest.CONTROL_AF_MODE_AUTO
                else -> CaptureRequest.CONTROL_AF_MODE_OFF
            }
            flashOn = false
            flashButton.text = if (hasFlash) "Flash off" else "No flash"
            flashButton.isEnabled = hasFlash
            flashButton.alpha = if (hasFlash) 1f else .55f

            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return finishWithError("camera_unavailable")
            val jpegs = map.getOutputSizes(ImageFormat.JPEG)?.toList().orEmpty()
            stillSize = jpegs.filter { CameraCaptureMath.supportsStillSize(it.width, it.height) }
                .maxByOrNull { it.width.toLong() * it.height }
                ?: return finishWithError("camera_unavailable")
            val ratio = stillSize!!.width.toDouble() / stillSize!!.height
            val previews = map.getOutputSizes(SurfaceTexture::class.java)?.toList().orEmpty()
                .filter { it.width > 0 && it.height > 0 }
            previewSize = previews.minByOrNull {
                abs(it.width.toDouble() / it.height - ratio) * 10000.0 +
                    abs(it.width.toLong() * it.height - 1280L * 720L).toDouble() / 1000.0
            } ?: return finishWithError("camera_unavailable")
            val generation = cameraGeneration
            opening = true
            // null handler delivers these lifecycle callbacks on the caller's
            // main looper; image bytes are still saved on the worker thread.
            cameraManager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (!cameraResumed || generation != cameraGeneration || isFinishing || !preview.isAvailable) {
                        camera.close()
                        return
                    }
                    opening = false
                    cameraDevice = camera
                    createPreviewSession(generation)
                }
                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    if (generation != cameraGeneration) return
                    opening = false
                    if (cameraDevice === camera) cameraDevice = null
                    if (cameraResumed) finishWithError("camera_unavailable")
                }
                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    if (generation != cameraGeneration) return
                    opening = false
                    if (cameraDevice === camera) cameraDevice = null
                    if (cameraResumed) finishWithError("camera_unavailable")
                }
            }, null)
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

    private fun createPreviewSession(generation: Long) {
        val device = cameraDevice ?: return
        val texture = preview.surfaceTexture ?: return
        val buffer = previewSize ?: return
        val still = stillSize ?: return
        try {
            texture.setDefaultBufferSize(buffer.width, buffer.height)
            previewSurface?.release()
            val target = Surface(texture)
            previewSurface = target
            imageReader?.close()
            val reader = ImageReader.newInstance(still.width, still.height, ImageFormat.JPEG, 2)
            imageReader = reader
            reader.setOnImageAvailableListener({ source ->
                val image = try { source.acquireNextImage() } catch (_: IllegalStateException) { null }
                    ?: return@setOnImageAvailableListener
                var temporary: File? = null
                try {
                    val plane = image.planes[0].buffer
                    val length = plane.remaining()
                    // Check before allocating: never copy an unbounded JPEG.
                    if (length <= 0 || length > CameraCaptureMath.MAX_CAPTURE_BYTES) {
                        throw IllegalStateException("Captured image exceeds the camera budget.")
                    }
                    val bytes = ByteArray(length).also { plane.get(it) }
                    val pendingFile = File.createTempFile("desksuite-writing-", ".tmp", cacheDir)
                    temporary = pendingFile
                    FileOutputStream(pendingFile).use { output ->
                        output.write(bytes)
                        output.flush()
                        output.fd.sync()
                    }
                    val file = File(cacheDir, "desksuite-capture-${UUID.randomUUID()}.jpg")
                    if (!pendingFile.renameTo(file)) throw IllegalStateException("Capture commit failed.")
                    temporary = null
                    runOnUiThread {
                        // If already closed, retain the complete file for the
                        // app's interrupted-capture recovery instead of deleting it.
                        if (!isFinishing && !isDestroyed) {
                            setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_CAPTURE_PATH, file.absolutePath))
                            finish()
                        }
                    }
                } catch (_: Exception) {
                    // A write/sync failure can leave a recoverable prefix or
                    // even a complete JPEG. Retain non-empty private files for
                    // the app's interrupted-capture recovery; remove only empty
                    // placeholders. Android may still clear its cache.
                    if (temporary?.length() == 0L) temporary?.delete()
                    runOnUiThread {
                        capturing.set(false)
                        if (cameraResumed && generation == cameraGeneration && !isFinishing) {
                            shutter.isEnabled = session != null
                            shutter.text = "●"
                            Toast.makeText(this, "Could not save this capture. A private partial copy may remain. Try again or import an image.", Toast.LENGTH_LONG).show()
                        }
                    }
                } finally {
                    image.close()
                }
            }, handler)

            device.createCaptureSession(
                listOf(target, reader.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(configured: CameraCaptureSession) {
                        if (!cameraResumed || generation != cameraGeneration || cameraDevice !== device || isFinishing) {
                            configured.close()
                            return
                        }
                        try {
                            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                            builder.addTarget(target)
                            builder.set(CaptureRequest.CONTROL_AF_MODE, autofocusMode)
                            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                            applyPreviewControls(builder)
                            configured.setRepeatingRequest(builder.build(), null, null)
                            session = configured
                            previewRequest = builder
                            shutter.isEnabled = true
                            shutter.contentDescription = "Capture page"
                            updateZoomControls()
                        } catch (_: CameraAccessException) {
                            configured.close()
                            finishWithError("camera_unavailable")
                        } catch (_: RuntimeException) {
                            configured.close()
                            finishWithError("camera_unavailable")
                        }
                    }
                    override fun onConfigureFailed(configured: CameraCaptureSession) {
                        configured.close()
                        if (cameraResumed && generation == cameraGeneration) finishWithError("camera_unavailable")
                    }
                },
                null,
            )
        } catch (_: CameraAccessException) {
            finishWithError("camera_unavailable")
        } catch (_: IllegalArgumentException) {
            finishWithError("camera_unavailable")
        } catch (_: IllegalStateException) {
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

    private fun updateZoomControls() {
        val available = cameraResumed && session != null && activeArray != null
        zoomOutButton.isEnabled = available && zoom > 1f
        zoomInButton.isEnabled = available && zoom < maxZoom
        zoomOutButton.alpha = if (zoomOutButton.isEnabled) 1f else .45f
        zoomInButton.alpha = if (zoomInButton.isEnabled) 1f else .45f
    }

    private fun changeZoom(delta: Float) {
        if (!cameraResumed || session == null || activeArray == null) return
        zoom = (zoom + delta).coerceIn(1f, maxZoom)
        zoomLabel.text = String.format("%.1f×", zoom)
        updateZoomControls()
        previewRequest?.let { builder ->
            try {
                applyPreviewControls(builder)
                session?.setRepeatingRequest(builder.build(), null, handler)
            } catch (_: CameraAccessException) {
                finishWithError("camera_unavailable")
            } catch (_: RuntimeException) {
                finishWithError("camera_unavailable")
            }
        }
    }

    private fun toggleFlash() {
        if (!hasFlash) return
        flashOn = !flashOn
        flashButton.text = if (flashOn) "Flash on" else "Flash off"
        previewRequest?.let { builder ->
            try {
                applyPreviewControls(builder)
                session?.setRepeatingRequest(builder.build(), null, handler)
            } catch (_: CameraAccessException) {
                finishWithError("camera_unavailable")
            } catch (_: RuntimeException) {
                finishWithError("camera_unavailable")
            }
        }
    }

    private fun captureStill() {
        val device = cameraDevice ?: return
        val reader = imageReader ?: return
        val activeSession = session ?: return
        if (!cameraResumed || isFinishing || !shutter.isEnabled || !capturing.compareAndSet(false, true)) return
        shutter.isEnabled = false
        shutter.text = "…"
        try {
            val request = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                addTarget(reader.surface)
                set(CaptureRequest.CONTROL_AF_MODE, autofocusMode)
                set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation())
                set(CaptureRequest.JPEG_QUALITY, 92.toByte())
                applyPreviewControls(this)
            }
            activeSession.capture(request.build(), object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureFailed(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    failure: CaptureFailure,
                ) {
                    runOnUiThread {
                        capturing.set(false)
                        if (cameraResumed && !isFinishing) {
                            shutter.isEnabled = this@DocumentCameraActivity.session != null
                            shutter.text = "●"
                            Toast.makeText(this@DocumentCameraActivity, "Capture failed. Hold steady and retry.", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }, handler)
        } catch (_: CameraAccessException) {
            captureUnavailable()
        } catch (_: RuntimeException) {
            captureUnavailable()
        }
    }

    private fun captureUnavailable() {
        capturing.set(false)
        if (cameraResumed && !isFinishing) {
            shutter.isEnabled = session != null
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
        // The camera UI is portrait-locked, but physical device orientation can
        // still change. Sensor readings run in the opposite direction to
        // display rotation. Fall back to display rotation without a sensor.
        val effectiveRotation = if (physicalOrientation == OrientationEventListener.ORIENTATION_UNKNOWN) {
            rotation
        } else {
            (360 - physicalOrientation) % 360
        }
        return CameraCaptureMath.jpegOrientation(sensorOrientation, effectiveRotation, frontFacing)
    }

    private fun configureTransform(width: Int, height: Int) {
        val buffer = previewSize ?: return
        if (width <= 0 || height <= 0) return
        val rotation = windowManager.defaultDisplay.rotation
        val matrix = Matrix()
        val view = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val centerX = view.centerX()
        val centerY = view.centerY()
        if (rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) {
            // Camera2's sample transform for a display whose natural and
            // current rotations differ. Verify on landscape-natural devices.
            val bufferRect = RectF(0f, 0f, buffer.height.toFloat(), buffer.width.toFloat())
            bufferRect.offset(centerX - bufferRect.centerX(), centerY - bufferRect.centerY())
            matrix.setRectToRect(view, bufferRect, Matrix.ScaleToFit.FILL)
            val scale = max(height.toFloat() / buffer.height, width.toFloat() / buffer.width)
            matrix.postScale(scale, scale, centerX, centerY)
            matrix.postRotate((90 * (rotation - 2)).toFloat(), centerX, centerY)
        } else {
            // TextureView fills its bounds; compensate its aspect distortion
            // with a center crop while keeping the whole view covered.
            val swap = sensorOrientation == 90 || sensorOrientation == 270
            val scaleX = CameraCaptureMath.centerCropScaleX(width, height, buffer.width, buffer.height, swap).toFloat()
            val scaleY = CameraCaptureMath.centerCropScaleY(width, height, buffer.width, buffer.height, swap).toFloat()
            matrix.postScale(scaleX, scaleY, centerX, centerY)
            if (rotation == Surface.ROTATION_180) matrix.postRotate(180f, centerX, centerY)
        }
        preview.setTransform(matrix)
    }

    private fun closeCamera() {
        // Close independently so one failure cannot leave a later resource open.
        shutter.isEnabled = false
        shutter.text = "●"
        capturing.set(false)
        try { session?.close() } catch (_: Exception) { }
        session = null
        previewRequest = null
        // A resumed camera starts with the torch off, matching its label.
        flashOn = false
        flashButton.isEnabled = false
        flashButton.alpha = .55f
        flashButton.text = "Checking…"
        updateZoomControls()
        try { cameraDevice?.close() } catch (_: Exception) { }
        cameraDevice = null
        try { imageReader?.close() } catch (_: Exception) { }
        imageReader = null
        try { previewSurface?.release() } catch (_: Exception) { }
        previewSurface = null
        opening = false
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
            permissionRequestPending = false
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

    override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
        cameraGeneration++
        closeCamera()
        return true
    }

    override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

    companion object {
        const val EXTRA_CAPTURE_PATH = "com.zamcan.desksuite.EXTRA_CAPTURE_PATH"
        const val EXTRA_ERROR = "com.zamcan.desksuite.EXTRA_ERROR"
        private const val REQUEST_CAMERA_PERMISSION = 6042
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
