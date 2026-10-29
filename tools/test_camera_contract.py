#!/usr/bin/env python3
"""Static checks for the in-app camera boundary; not a device or build test."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class CameraContractTest(unittest.TestCase):
    def test_manifest_keeps_camera_optional_and_activity_private(self):
        root = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
        features = {item.get(ANDROID + 'name'): item.get(ANDROID + 'required')
                    for item in root.findall('uses-feature')}
        self.assertEqual(features.get('android.hardware.camera'), 'false')
        self.assertEqual(features.get('android.hardware.camera.autofocus'), 'false')
        activities = root.findall('./application/activity')
        camera = next(item for item in activities
                      if item.get(ANDROID + 'name') == '.DocumentCameraActivity')
        self.assertEqual(camera.get(ANDROID + 'exported'), 'false')

    def test_new_capture_opens_only_the_app_activity(self):
        main = (ROOT / 'android/app/src/main/kotlin/com/zamcan/desksuite/MainActivity.kt').read_text()
        activity = (ROOT / 'android/app/src/main/kotlin/com/zamcan/desksuite/DocumentCameraActivity.kt').read_text()
        self.assertIn('Intent(this, DocumentCameraActivity::class.java)', main)
        self.assertIn('import android.graphics.ImageFormat', activity)
        self.assertIn('import android.hardware.camera2.CaptureFailure', activity)
        self.assertNotIn('android.media.ImageFormat', activity)
        self.assertNotIn('CameraCaptureSession.CaptureFailure', activity)
        for path in (ROOT / 'lib').rglob('*.dart'):
            self.assertNotIn('ImageSource.camera', path.read_text(), str(path))

    def test_jpeg_budget_precedes_copy_and_file_is_committed_after_sync(self):
        activity = (ROOT / 'android/app/src/main/kotlin/com/zamcan/desksuite/DocumentCameraActivity.kt').read_text()
        self.assertLess(activity.index('length > CameraCaptureMath.MAX_CAPTURE_BYTES'),
                        activity.index('ByteArray(length)'))
        self.assertLess(activity.index('output.fd.sync()'), activity.index('pendingFile.renameTo(file)'))
        self.assertIn('generation != cameraGeneration', activity)
        self.assertIn('camera.close()', activity)

    def test_private_recovery_is_acknowledged_only_after_matching_draft_commit(self):
        gateway = (ROOT / 'lib/document_scan/camera_gateway.dart').read_text()
        page = (ROOT / 'lib/document_scan/scan_studio_page.dart').read_text()
        self.assertIn('followLinks: false', gateway)
        self.assertIn('safeFile.parent.path != cacheRoot', gateway)
        self.assertIn('discardPendingCapture()', gateway)
        persist = page.split('Future<bool> _persist()', 1)[1].split('void _checkCapacity', 1)[0]
        self.assertLess(persist.index('store!.save'), persist.index('acknowledgeCaptureSaved'))
        self.assertIn('page.id == recoveryPageId', persist)
        self.assertIn('captureCommitted && widget.camera is CommittedCaptureGateway', persist)


if __name__ == '__main__':
    unittest.main(verbosity=2)
