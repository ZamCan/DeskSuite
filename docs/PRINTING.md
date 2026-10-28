# Printing and physical dimensions

## Design

Canvas geometry is stored in millimetres. One inch is 25.4 mm and one PDF point is 1/72 inch. PNG output uses `round(mm / 25.4 × dpi)` pixels at 150 or 300 dpi; PDF uses the design's physical page size and embeds the rendered page as a flattened image. Text is therefore not searchable or editable in the PDF. Effective placed-image resolution is estimated; very low resolution triggers a confirmation. Pixel dimensions are bounded to 16 MP and 8192 pixels per side.

The design print action renders a 150 dpi PDF and gives its exact page format and bytes to `Printing.layoutPdf` through `PrintGateway`. Print Studio similarly generates an A4 check PDF with a 100 mm measurement line. The retained earlier editor has its own simpler PDF/print path; its rendering and sizing can differ, so prefer the new editor.

## Photo sheets

Choose from the shared media catalogue or custom width/height in millimetres, photo frame width/height, uniform margin, spacing and copy count. The catalogue covers ISO A0–A10, B0–B10 and C0–C10, US Letter/Legal/Tabloid/Ledger and ANSI poster sizes, common photo paper, and poster/large-format presets up to 48 × 72 inches; custom sheet dimensions are supported up to 2500 mm per side. The same catalogue is used by the editable design canvas. A preset describes physical dimensions only: stock weight/finish, printer feed path, borderless support, roll width and printable margins must be checked for the actual printer. The preview and exported PDF use the same top-left grid, with images **contained** inside each frame, not stretched or automatically face-cropped. Copies must fit one page (maximum 100); page sides are 50–1200 mm and photo sides 5–250 mm. A low-resolution image prompts confirmation below 150 dpi. Margin/spacing are layout settings, **not guarantees of printer printable area**. The result is not a passport/visa/ID-photo compliance checker: verify face position, background, dimensions and official requirements independently.

## Verification and limitations

Print using the intended paper and choose **actual size / 100%** rather than fit-to-page where available. Measure a test print; drivers can rescale, add margins, clip, choose different paper or override settings. Colour profiles, CMYK, bleed, crop marks, imposition, printer capability discovery, borderless modes and production queues are not implemented. Large design exports remain subject to an output pixel budget; select an explicitly labelled lower DPI for large-format work where required rather than assuming A0/poster output is safe at 300 dpi. Host tests inspect real PDF headers and physical MediaBox dimensions and use an injectable fake for the print handoff. Native dialogs, spoolers, printer models, margins, colour and physical output have **not** been exercised on a device.
