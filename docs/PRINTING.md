# Print preparation

A design has a physical width and height in millimetres. The editor preview and export use the same design renderer. The PDF page box is calculated as `mm × 72 / 25.4` points. PNG dimensions are rounded from `mm × dpi / 25.4` pixels. Presets include A4 (210 × 297 mm), A5, A3, 85 × 55 mm business card, and custom 10–1200 mm dimensions.

The current PDF export is a **single raster page** with no added margin, crop marks, bleed, imposition or colour profile. A source-image resolution warning compares the image's effective dpi at its placed size with the chosen output dpi. A 300 dpi raster does not increase the detail in a low-resolution source. Images are fitted within their boxes without distortion.

No physical printer, print service or device has been tested. Export the PDF and use a compatible system print application; validate actual page scale, margins, colour and trimming on the intended printer. Borderless printing is not guaranteed. Direct printer integration, printer queue status, multi-photo sheets, saved print presets and production costing are planned, not implemented.
