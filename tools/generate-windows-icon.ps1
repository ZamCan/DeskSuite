$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source = Join-Path $root "assets/brand/desksuite-mark.png"
$runner = Join-Path $root "windows/runner/resources"
$pngPath = Join-Path $runner "desksuite-app-icon.generated.png"
$icoPath = Join-Path $runner "app_icon.ico"

if (-not (Test-Path $source)) { throw "Canonical DeskSuite mark PNG is missing: $source" }
if (-not (Test-Path $runner)) { throw "Flutter Windows runner resources are missing: $runner" }

$size = 256
$bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$background = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 41, 40, 36))
$mark = [System.Drawing.Image]::FromFile($source)

try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $radius = 56
    $diameter = $radius * 2
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($size - $diameter, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($size - $diameter, $size - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $size - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    $graphics.FillPath($background, $path)
    $graphics.DrawImage($mark, 0, 0, $size, $size)
    $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $mark.Dispose()
    $background.Dispose()
    $path.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

# ICO supports a PNG-compressed 256x256 image. Write the 22-byte ICO header
# and directory entry followed by the exact PNG payload; no lossy resampling.
$png = [System.IO.File]::ReadAllBytes($pngPath)
$stream = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = [System.IO.BinaryWriter]::new($stream)
try {
    $writer.Write([UInt16]0)       # reserved
    $writer.Write([UInt16]1)       # icon resource
    $writer.Write([UInt16]1)       # one image
    $writer.Write([Byte]0)         # width 0 means 256
    $writer.Write([Byte]0)         # height 0 means 256
    $writer.Write([Byte]0)         # no palette
    $writer.Write([Byte]0)         # reserved
    $writer.Write([UInt16]1)       # color planes
    $writer.Write([UInt16]32)      # bits per pixel
    $writer.Write([UInt32]$png.Length)
    $writer.Write([UInt32]22)      # image offset after header and entry
    $writer.Write([Byte[]]$png)
}
finally {
    $writer.Dispose()
    $stream.Dispose()
    Remove-Item -LiteralPath $pngPath -Force -ErrorAction SilentlyContinue
}
Write-Host "Generated Windows app icon from the canonical DeskSuite brand mark: $icoPath"
