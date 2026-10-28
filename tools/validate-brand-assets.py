#!/usr/bin/env python3
"""Validate DeskSuite vector brand assets and Android icon resource references."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets/brand"
RES = ROOT / "android/app/src/main/res"
COLORS = ("#fbf8f1", "#ed9a7a")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Brand asset validation failed: {message}")


for name in ("desksuite-mark.svg", "desksuite-app-icon.svg"):
    path = BRAND / name
    require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    root = ET.parse(path).getroot()
    require(root.tag.endswith("svg"), f"{name} is not SVG")
    require(root.attrib.get("viewBox") == "0 0 512 512", f"{name} viewBox changed")
    content = path.read_text(encoding="utf-8").lower()
    for color in COLORS:
        require(color in content, f"{name} lost canonical color {color}")
    if name == "desksuite-app-icon.svg":
        require("#292824" in content, "desktop icon lost the ink background")

manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
require('android:icon="@mipmap/ic_launcher"' in manifest, "manifest icon reference changed")

for path in (
    RES / "drawable/ic_launcher_foreground.xml",
    RES / "drawable/ic_launcher_monochrome.xml",
    RES / "mipmap-anydpi-v26/ic_launcher.xml",
    RES / "mipmap-anydpi-v33/ic_launcher.xml",
    RES / "drawable/launch_background.xml",
    RES / "drawable-v21/launch_background.xml",
    RES / "values-v31/styles.xml",
    RES / "values-night-v31/styles.xml",
):
    require(path.is_file(), f"missing {path.relative_to(ROOT)}")
    ET.parse(path)

print("DeskSuite vector brand sources and Android icon/splash XML references are consistent.")
