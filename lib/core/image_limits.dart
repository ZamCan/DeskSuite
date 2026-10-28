/// Shared bounds for the offline first-frame photo/scan image pipeline.
/// Native pickers can cache data before these Dart-side checks run.
const int maxPhotoInputBytes = 8 * 1024 * 1024;
const int maxPhotoWorkingBytes = 16 * 1024 * 1024;
const int maxPhotoPixels = 12000000;
const int maxPhotoSide = 8192;
