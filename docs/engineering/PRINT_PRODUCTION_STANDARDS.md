# DeskSuite print production and media standards

**Reviewed:** 2026-10-28. This is an engineering policy, not a claim of formal certification.

## Non-negotiable separation

Every print workflow must model these independently:

1. **Finished item** — final trimmed photograph, card, badge, flyer, poster, certificate or label; finished width/height, orientation, crop, safe area, bleed and finishing.
2. **Print medium** — source sheet or roll, nominal/measured dimensions, feed direction, printable area, margins, bleed/trim and cut plan.
3. **Substrate** — photo paper, coated/uncoated paper, card stock, board, label, synthetic or roll media; finish, grammage (g/m²), caliper/thickness, coating and process compatibility.
4. **Device profile** — supported dimensions/media types, printable area, feed path, maximum thickness/weight, borderless mode, resolution, colour handling and scaling behavior.
5. **Authority/customer specification** — jurisdiction, issuing body, document/channel, source URL, rule type (exact/maximum/recommended/unspecified), review date, dimensions, portrait rules, background and digital upload constraints.

A4 is a paper format, not a passport-photo standard. 35 × 45 mm is not a universal passport-photo standard. A4 can be a production sheet if the stock and device support it, but must not be assumed for every photo job. Dedicated small-format stock such as 4 × 6 inch (101.6 × 152.4 mm) is common for photo printing; the correct medium depends on the job, available stock and printer/press.

## Standards: scope matters

- **ISO 216:2007** defines trimmed A- and B-series paper sizes for writing paper and certain printed matter. A4 is 210 × 297 mm; A3 is 297 × 420 mm. It does not necessarily cover all posters, books, newspapers or special products.
- **ISO/IEC 23385:2022** defines a measurement method for digital photo-printer print time across sizes including 2 × 3 inch, 4 × 6 inch, A6, A4, 11 × 17 inch, A3 and A3+. It is not a passport-photo compliance standard.
- **ICAO Doc 9303, Part 3** provides machine-readable travel-document portrait quality guidance. National authorities and application channels can impose different dimensions and upload requirements; do not turn ICAO guidance into a universal preset.
- **ISO/IEC 7810:2019** covers physical characteristics and dimensions for identification-card formats. ID-1 is nominally 85.60 × 53.98 mm × 0.76 mm. A printable badge design is not proof that the manufactured card conforms to that standard.
- Printer manufacturers' supported-media documentation determines whether a given device accepts a stock's weight, thickness, finish, feed path and borderless mode. GSM alone does not define thickness or compatibility.

References:
- ISO 216: https://www.iso.org/standard/36631.html
- ISO/IEC 23385: https://www.iso.org/standard/75388.html
- ICAO Doc 9303: https://www.icao.int/Security/FAL/TRIP/PublishingImages/Pages/Publications/Doc%209303%20Machine%20Readable%20Travel%20Documents%20%20%28Unedited%208th%20Edition%29.pdf
- ISO/IEC 7810: https://www.iso.org/standard/70483.html

## Substrate catalogue: required distinction

| Media family | Examples | Production attributes |
| --- | --- | --- |
| Office/uncoated paper | copier paper, forms, letterhead | size, gsm, feed/grain where relevant, tray and duplex constraints |
| Coated print paper | coated matte, silk/satin, gloss | gsm, caliper, coating, ink/toner process, colour profile |
| Photo media | glossy, semi-gloss/lustre, satin, matte | sheet/roll size, surface/coating, gsm and caliper if supplied, ink/dye-sublimation compatibility, borderless support |
| Card/cover stock | business cards, invitations, covers | gsm **and** caliper, rigidity, grain, printer feed path and maximum thickness, duplex/finishing compatibility |
| Board/rigid stock | display panels, rigid signage | thickness, rigidity, maximum device/media path and supported process; never assume a consumer printer can feed it |
| Labels/synthetic media | adhesive labels, waterproof polyester | adhesive/liner, heat/ink compatibility, surface, thickness and die-cut requirements |
| Large-format sheet/roll | posters, banners, canvas, signage | roll width or sheet dimensions, printable width/length, bleed/trim, media/ink profile and finishing/cutting limits |

“Glossy” is a surface finish, not a paper size or guarantee of printer compatibility. “Hard paper” is too vague for production; retain actual stock type and thickness where available.

## Passport, visa and ID-photo rules

- Keep **portrait specification** separate from **print-sheet specification**. The portrait rule describes the finished photo; the sheet rule controls copies per selected medium.
- Every authority profile must identify source URL, authority/jurisdiction, document and submission channel, review date and rule type.
- If an authority does not publish physical dimensions in the verified source, store **unspecified**. Do not infer a passport print size from another country, an e-Visa upload rule, a generic 35 × 45 mm example or a recommendation.
- A maximum envelope is not an exact required size; a recommendation is not a mandatory rule. Distinguish paper submission from digital upload.
- Validate head/face proportions, background, pose, recency, file size/format and paper properties only when the relevant authority profile specifies them. Background compositing or cropping alone is not biometric/authority compliance.
- The selected sheet/roll must never silently change finished photo dimensions. Exact-size output must preserve scale; warn against “fit to page”. Printer printable margins and borderless capability vary.
- ICAO printed-portrait guidance describes photo-quality paper and a low-roughness, non-structured surface; verify the current issuing authority's specific requirements.

## Imposition and export acceptance criteria

1. Use physical units (mm/in), never screen pixels, for production geometry.
2. Compute usable area after non-printable margins, bleed, trim, spacing/gutter and cut marks.
3. Calculate row/column capacity from actual dimensions and orientation; rotate only when allowed.
4. Reject impossible layouts; never silently clip or scale.
5. Show copies that fit, remaining copies, effective image resolution at target size and margin/borderless caveats.
6. Make image fit behavior explicit: contain, crop-to-fill or stretch (stretch is not the default).
7. Set PDF page dimensions from the chosen sheet/roll section and verify the resulting MediaBox. Keep finished item geometry separate from page geometry.
8. Preserve the real image data and editability where promised.
9. Test orientation, margins, edge cases, over-capacity and physical page dimensions.
10. Provide production preview and “actual size / 100%” instruction where exact dimensions matter.

## Poster, stationery and larger formats

A4/A3 are paper presets, not universal poster dimensions. Offer B-series, US Letter/Tabloid, photo sizes, custom cut-sheet and roll media only when supported by the export/device path. Finished poster size can differ from source sheet/roll due to bleed, trimming, tiling or mounting. Business/ID card layout must distinguish printable design from compliant card manufacture, including bleed, safe area, corner/trim allowances, material and device capability. A PDF canvas alone does not prove colour accuracy, exact size, cut precision or media compatibility.

## Current implementation decisions

- Photo Sheet defaults to 4 × 6 inch as a convenient small-format starting medium, not a universal rule. A4/A5/custom remain explicit independent choices.
- Tanzania passport dimensions remain unspecified because the cited online guideline does not state physical width × height. The separate Tanzania e-Visa digital-upload limit is not reused as a passport print dimension.
- The A4 template is labelled as a multi-photo layout example, not a passport preset.
- Printer/media capability profiles, trim/bleed/safe areas, actual-size controls and physical printer validation are still required before claiming production readiness.
