package com.zamcan.desksuite;

/** Allocation-free bounds and orientation used by the in-app document camera. */
public final class CameraCaptureMath {
    private CameraCaptureMath() {}

    // Deliberately stricter than the shared 12-megapixel photo decoder budget.
    public static final long MAX_STILL_PIXELS = 6_000_000L;
    public static final int MAX_STILL_SIDE = 8192;
    public static final int MAX_CAPTURE_BYTES = 8 * 1024 * 1024;

    public static boolean supportsStillSize(int width, int height) {
        return width > 0 && height > 0 && width <= MAX_STILL_SIDE
                && height <= MAX_STILL_SIDE
                && (long) width * height <= MAX_STILL_PIXELS;
    }


    /** Center-crop multipliers for a pre-rotated preview in a viewport. */
    public static double centerCropScaleX(int viewWidth, int viewHeight,
            int bufferWidth, int bufferHeight, boolean swapDimensions) {
        if (viewWidth <= 0 || viewHeight <= 0 || bufferWidth <= 0 || bufferHeight <= 0) {
            throw new IllegalArgumentException("Preview dimensions must be positive.");
        }
        double sourceRatio = swapDimensions
                ? (double) bufferHeight / bufferWidth : (double) bufferWidth / bufferHeight;
        double viewRatio = (double) viewWidth / viewHeight;
        return Math.max(1.0, sourceRatio / viewRatio);
    }

    public static double centerCropScaleY(int viewWidth, int viewHeight,
            int bufferWidth, int bufferHeight, boolean swapDimensions) {
        if (viewWidth <= 0 || viewHeight <= 0 || bufferWidth <= 0 || bufferHeight <= 0) {
            throw new IllegalArgumentException("Preview dimensions must be positive.");
        }
        double sourceRatio = swapDimensions
                ? (double) bufferHeight / bufferWidth : (double) bufferWidth / bufferHeight;
        double viewRatio = (double) viewWidth / viewHeight;
        return Math.max(1.0, viewRatio / sourceRatio);
    }

    /**
     * Camera2 JPEG orientation from display rotation and sensor orientation.
     * Display rotation is opposite to the device-orientation sensor direction.
     * External cameras require separate hardware verification.
     */
    public static int jpegOrientation(int sensorDegrees, int displayDegrees, boolean frontFacing) {
        if (sensorDegrees % 90 != 0 || displayDegrees % 90 != 0) {
            throw new IllegalArgumentException("Camera rotations must be multiples of 90 degrees.");
        }
        final int signedDisplay = frontFacing ? displayDegrees : -displayDegrees;
        int raw = (sensorDegrees % 360 + signedDisplay % 360) % 360;
        return (raw + 360) % 360;
    }
}
