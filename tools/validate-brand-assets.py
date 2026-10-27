#!/usr/bin/env python3
"""Static consistency checks for DeskSuite brand, launcher and splash assets."""
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android/app/src/main/res"
BRAND = ROOT / "assets/brand"
INK, PAPER, TERRACOTTA = "#292824", "#fbf8f1", "#ed9a7a"


def require(condition, message):
    if not condition:
        raise SystemExit(f"Brand asset validation failed: {message}")


def png_size(path):
    data = path.read_bytes()
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), f"{path.relative_to(ROOT)} is not a PNG")
    require(len(data) >= 24, f"{path.relative_to(ROOT)} has a truncated PNG header")
    return struct.unpack(">II", data[16:24])


for name in ("desksuite-mark.svg", "desksuite-app-icon.svg"):
    path = BRAND / name
    require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    svg = ET.parse(path).getroot()
    require(svg.tag.endswith("svg"), f"{name} root is not SVG")
    require(svg.attrib.get("viewBox") == "0 0 512 512", f"{name} viewBox changed")
    text = path.read_text(encoding="utf-8").lower()
    require(PAPER in text and TERRACOTTA in text, f"{name} lost the paper/terracotta mark")
    if name == "desksuite-app-icon.svg":
        require(INK in text, "desktop app icon must use the canonical ink background")

master = BRAND / "desksuite-mark.png"
width, height = png_size(master)
require(width >= 512 and width == height, "transparent master PNG must be square and at least 512px")

expected = {
    "mdpi": (48, 48),
    "hdpi": (72, 72),
    "xhdpi": (96, 96),
    "xxhdpi": (144, 144),
    "xxxhdpi": (192, 192),
}
for density, size in expected.items():
    icon = RES / f"mipmap-{density}/ic_launcher.png"
    require(icon.is_file(), f"missing {icon.relative_to(ROOT)}")
    require(png_size(icon) == size, f"{icon.relative_to(ROOT)} must be {size[0]}x{size[1]}")

for folder in ("mipmap-anydpi-v26", "mipmap-anydpi-v33"):
    path = RES / folder / "ic_launcher.xml"
    require(path.is_file(), f"missing adaptive icon {path.relative_to(ROOT)}")
    root = ET.parse(path).getroot()
    require(root.tag.endswith("adaptive-icon"), f"{folder} is not an adaptive icon")
    serialized = path.read_text(encoding="utf-8")
    require("@color/launcher_background" in serialized, f"{folder} lost its background")
    require("@drawable/ic_launcher_foreground" in serialized, f"{folder} lost its foreground")
    if folder.endswith("v33"):
        require("@drawable/ic_launcher_monochrome" in serialized, "Android 13 monochrome icon is missing")

colors = ET.parse(RES / "values/launcher_colors.xml").getroot()
launcher_color = next((e.text for e in colors if e.attrib.get("name") == "launcher_background"), None)
require(launcher_color and launcher_color.lower() == INK, "launcher background color diverges from brand ink")

for folder in ("drawable", "drawable-v21"):
    path = RES / folder / "launch_background.xml"
    require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    require("@color/launcher_background" in text and "@drawable/ic_launcher_foreground" in text,
            f"{folder} splash does not use the canonical launcher palette/mark")

for folder in ("values-v31", "values-night-v31"):
    path = RES / folder / "styles.xml"
    require(path.is_file(), f"missing Android 12 splash theme {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    require("windowSplashScreenAnimatedIcon" in text and "@drawable/ic_launcher_foreground" in text,
            f"{folder} splash theme is missing the canonical mark")

manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
require('android:icon="@mipmap/ic_launcher"' in manifest, "Android manifest does not use the canonical launcher icon")
print("DeskSuite brand assets, Android launcher densities, adaptive/monochrome icons and splash references are consistent.")
