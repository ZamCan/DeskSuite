# Formats and printing

Editable designs use versioned JSON project files with the .dsproject extension. Back up important projects while the format evolves.

Current workflows: image import; JPEG export; plain-text notes export; PDF export for current canvas text/shapes/images; A4 print test PDF and operating-system print dialog.

The initial design canvas uses logical units and a fixed conversion for PDF output. Commercial production needs explicit physical units (mm/inches/points), DPI validation and measured print tests. Advanced font fidelity, colour management, bleed, crop marks, vector fidelity and imposition are not implemented.

DOCX, XLSX, SVG, multi-page PDF operations and additional image formats require dedicated adapters and compatibility tests. Opening a file is not equivalent to full editing support.
