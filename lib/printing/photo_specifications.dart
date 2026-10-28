enum PhotoDimensionRule { exact, maximum, recommended, unspecified }

class PhotoSpecification {
  const PhotoSpecification({
    required this.id,
    required this.label,
    required this.authority,
    required this.documentType,
    required this.dimensionRule,
    required this.background,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.verifiedOn,
    required this.notes,
    this.widthMm,
    this.heightMm,
    this.headHeightMinMm,
    this.headHeightMaxMm,
    this.headHeightMinFraction,
    this.headHeightMaxFraction,
    this.maxFileBytes,
    this.fileFormats = const [],
  });
  final String id, label, authority, documentType;
  final PhotoDimensionRule dimensionRule;
  final double? widthMm, heightMm, headHeightMinMm, headHeightMaxMm;
  final double? headHeightMinFraction, headHeightMaxFraction;
  final String background;
  final int? maxFileBytes;
  final List<String> fileFormats;
  final String sourceTitle, sourceUrl, verifiedOn, notes;
  bool get hasPublishedDimensions => widthMm != null && heightMm != null;
}

const photoSpecifications = <PhotoSpecification>[
  PhotoSpecification(
    id: 'tz-passport',
    label: 'Tanzania · passport application',
    authority: 'Tanzania Immigration Services Department',
    documentType: 'Passport application',
    dimensionRule: PhotoDimensionRule.unspecified,
    background: 'Light blue (not dark blue)',
    sourceTitle: 'Tanzania Passport Application Guidelines',
    sourceUrl:
        'https://eservices.immigration.go.tz/online/web/passport/guidelines',
    verifiedOn: '2026-10-28',
    notes: 'The current online guideline calls for a recent photo with a light-blue background but does not state physical width × height on that page. Do not invent a passport print size; confirm any further dimensions or upload rules in the live application form.',
  ),
  PhotoSpecification(
    id: 'tz-evisa',
    label: 'Tanzania · e-Visa upload',
    authority: 'Tanzania Immigration Services Department',
    documentType: 'Visa application digital upload',
    dimensionRule: PhotoDimensionRule.maximum,
    widthMm: 35,
    heightMm: 45,
    background: 'Plain background',
    maxFileBytes: 500 * 1024,
    fileFormats: ['JPG', 'JPEG'],
    sourceTitle: 'Tanzania eVisa Photo Specifications',
    sourceUrl: 'https://visa.immigration.go.tz/guidelines',
    verifiedOn: '2026-10-28',
    notes: 'The authority says the image should not exceed 35 mm wide × 45 mm high, must be JPG/JPEG and no more than 500 KB. This is an e-Visa upload rule, not proof of the physical print size for a Tanzania passport.',
  ),
  PhotoSpecification(
    id: 'icao-mrtd-portrait',
    label: 'ICAO · MRTD portrait guidance',
    authority: 'International Civil Aviation Organization (ICAO)',
    documentType: 'Machine-readable travel document portrait guidance',
    dimensionRule: PhotoDimensionRule.recommended,
    widthMm: 35,
    heightMm: 45,
    background: 'Plain, light-coloured background',
    sourceTitle: 'ICAO Doc 9303 — Machine Readable Travel Documents',
    sourceUrl: 'https://www.icao.int/sites/default/files/publications/DocSeries/9303_p3_cons_en.pdf',
    verifiedOn: '2026-10-28',
    notes: 'Doc 9303 describes 45 × 35 mm submitted portraits. Its 70–80% crown-to-chin guidance refers to the portrait zone in the travel document, not a universal fraction of the submitted photo. National authorities and digital channels may differ.',
  ),
  PhotoSpecification(
    id: 'us-passport-paper',
    label: 'United States · passport paper photo',
    authority: 'U.S. Department of State',
    documentType: 'Passport paper application photo',
    dimensionRule: PhotoDimensionRule.exact,
    widthMm: 51,
    heightMm: 51,
    headHeightMinMm: 25,
    headHeightMaxMm: 35,
    background: 'Plain white or off-white',
    sourceTitle: 'U.S. Department of State — Passport Photos',
    sourceUrl: 'https://travel.state.gov/en/passports/apply/help/photos.html',
    verifiedOn: '2026-10-28',
    notes: 'Paper photo is 2 × 2 inches (about 51 × 51 mm); chin-to-crown head height must be 25–35 mm. Submit the original, unedited photo without filters or digital changes. Online renewal has a separate digital upload path.',
  ),
  PhotoSpecification(
    id: 'canada-passport-paper',
    label: 'Canada · passport photo',
    authority: 'Government of Canada',
    documentType: 'Passport application photo',
    dimensionRule: PhotoDimensionRule.exact,
    widthMm: 50,
    heightMm: 70,
    headHeightMinMm: 31,
    headHeightMaxMm: 36,
    background: 'Plain white or light-coloured background',
    sourceTitle: 'Government of Canada — Passport Photos',
    sourceUrl: 'https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/photos.html',
    verifiedOn: '2026-10-28',
    notes: 'For in-person or mail applications: 50 × 70 mm, with chin-to-crown face height 31–36 mm. Photos must be taken and professionally printed by a commercial photographer or studio; home printing and any photo editing are not accepted. Online renewals differ.',
  ),
];
// List.length is not a Dart constant expression, even for a const list.
// Deriving the index at runtime keeps it in sync as profiles are added.
final int customPhotoSpecificationIndex = photoSpecifications.length;
