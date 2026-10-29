package com.zamcan.desksuite;

public final class CameraCaptureMathTest {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        check(CameraCaptureMath.supportsStillSize(2000, 3000), "6 MP accepted");
        check(!CameraCaptureMath.supportsStillSize(2001, 3000), "over 6 MP rejected");
        check(!CameraCaptureMath.supportsStillSize(0, 1), "zero side rejected");
        check(!CameraCaptureMath.supportsStillSize(8193, 1), "side limit enforced");
        check(!CameraCaptureMath.supportsStillSize(Integer.MAX_VALUE, Integer.MAX_VALUE), "no overflow");
        check(CameraCaptureMath.supportsPreviewSize(1920, 1080), "standard HD preview accepted");
        check(CameraCaptureMath.supportsPreviewSize(2048, 1536), "preview pixel budget accepted");
        check(CameraCaptureMath.supportsPreviewSize(1080, 1920), "portrait preview accepted");
        check(!CameraCaptureMath.supportsPreviewSize(2048, 1537), "over-budget preview rejected");
        check(!CameraCaptureMath.supportsPreviewSize(3840, 2160), "4K preview rejected");
        check(!CameraCaptureMath.supportsPreviewSize(2049, 1), "preview side limit enforced");
        check(!CameraCaptureMath.supportsPreviewSize(0, 1), "zero preview side rejected");
        check(!CameraCaptureMath.supportsPreviewSize(-1, 10), "negative preview side rejected");
        check(!CameraCaptureMath.supportsPreviewSize(Integer.MAX_VALUE, Integer.MAX_VALUE), "preview multiplication cannot overflow");
        int[] rotations = {0, 90, 180, 270};
        int[] rear = {90, 0, 270, 180};
        int[] front = {90, 180, 270, 0};
        for (int i = 0; i < rotations.length; i++) {
            check(CameraCaptureMath.jpegOrientation(90, rotations[i], false) == rear[i], "rear " + rotations[i]);
            check(CameraCaptureMath.jpegOrientation(90, rotations[i], true) == front[i], "front " + rotations[i]);
        }
        boolean rejected = false;
        try { CameraCaptureMath.jpegOrientation(90, 45, false); }
        catch (IllegalArgumentException expected) { rejected = true; }
        check(rejected, "non-right-angle orientation rejected");
        check(CameraCaptureMath.MAX_CAPTURE_BYTES == 8 * 1024 * 1024, "capture byte limit");
        check(Math.abs(CameraCaptureMath.centerCropScaleX(360, 640, 1440, 1080, true) - 4.0 / 3) < 1e-9, "portrait preview covers width");
        check(CameraCaptureMath.centerCropScaleY(360, 640, 1440, 1080, true) == 1.0, "portrait preview keeps height");
        check(CameraCaptureMath.centerCropScaleX(600, 600, 1440, 1080, true) == 1.0, "square preview keeps width");
        check(Math.abs(CameraCaptureMath.centerCropScaleY(600, 600, 1440, 1080, true) - 4.0 / 3) < 1e-9, "square preview covers height");
        check(CameraCaptureMath.centerCropScaleX(800, 600, 1440, 1080, false) == 1.0, "landscape matching width");
        check(CameraCaptureMath.centerCropScaleY(800, 600, 1440, 1080, false) == 1.0, "landscape matching height");
        rejected = false;
        try { CameraCaptureMath.centerCropScaleX(0, 1, 1, 1, true); }
        catch (IllegalArgumentException expected) { rejected = true; }
        check(rejected, "invalid preview dimensions rejected");
        check(CameraCaptureMath.jpegOrientation(-270, 270, false) == 180, "negative sensor normalized");
        check(CameraCaptureMath.jpegOrientation(-270, -270, true) == 180, "negative front display normalized");
        System.out.println("Camera geometry and bounds: 33 checks passed (no Android camera/device used).");
    }
}
