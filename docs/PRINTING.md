# Printing and physical dimensions

## Design

Canvas geometry is stored in millimetres, from 10 to 2500 mm per side. One inch is 25.4 mm and one PDF point is 1/72 inch. PNG output uses `round(mm / 25.4 × dpi)` pixels; it does not embed a reliable physical print size. PDF uses the design's physical page size and embeds a flattened raster image, so its text is not searchable or editable. Effective placed-image detail is estimated; low resolution prompts a confirmation.

Raster output is capped at **16 million pixels and 8192 pixels per side**. The export menu offers 150 or 300 dpi where they fit. For larger pages, it offers the highest whole-number DPI at or below 150 that fits the budget, plus eligible 100, 72, 60 or 36 dpi options for PDF/PNG. These are explicitly lower-detail choices, not a guarantee of quality or sufficient device memory. For example, a 48 × 72 inch canvas fits at 68 dpi, not 72 or 150 dpi. Inspect the output at its intended viewing distance and choose a different workflow if it is not adequate.

The design print action renders a raster PDF at the selected permitted DPI and gives its physical page format and bytes to `Printing.layoutPdf` through `PrintGateway`. Print Studio separately generates an A4 check PDF with a 100 mm measurement line. The retained earlier editor has its own simpler PDF/print path; its rendering and sizing can differ, so prefer the new editor.

## Photo sheets

Choose a sheet preset or custom width/height in millimetres, photo frame width/height, uniform margin, spacing and copy count. The shared catalogue covers ISO A/B/C, US and photo sizes, card/badge/label examples and poster formats. It describes **physical dimensions only**, not supported substrates or printers. Stock weight/finish, feed path, borderless support, roll width and printable margins must be checked for the actual printer.

The default 4 × 6 inch sheet has four 35 × 45 mm frames with 10 mm margins and 3 mm spacing. The preview and exported PDF use the same top-left grid, with images **contained** inside each frame, not stretched or automatically face-cropped. Copies must fit one page (maximum 100). Sheet sides are 10–2500 mm and photo sides 5–250 mm; smaller sheets require correspondingly smaller photo frames/margins. A low-resolution image prompts confirmation below 150 dpi. Margin/spacing are layout settings, **not guarantees of printer printable area**. The result is not a passport/visa/ID-photo compliance checker: verify face position, background, dimensions, photo-editing restrictions and official requirements independently.

## Verification and limitations

Print using the intended paper and choose **actual size / 100%** rather than fit-to-page where available. Measure a test print; drivers can rescale, add margins, clip, choose different paper or override settings. Colour profiles, CMYK, bleed, crop marks, imposition, printer capability discovery, borderless modes and production queues are not implemented. Host tests from earlier revisions inspect real PDF headers and physical MediaBox dimensions and use an injectable fake for the print handoff; new large-format and sheet changes still require the complete Flutter suite. Native dialogs, spoolers, printer models, margins, colour and physical output have **not** been exercised on a device in this environment.
