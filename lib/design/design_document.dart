import 'dart:convert';
import 'dart:typed_data';

import '../core/ids.dart';
import '../core/physical_page_limits.dart';

const int currentDesignVersion = 1;
const int maxProjectBytes = 32 * 1024 * 1024;
const int maxImportedImageBytes = 8 * 1024 * 1024;
const int maxDesignElements = 100;

/// All physical geometry is measured in millimetres, independent of the screen.
enum ElementKind { text, rectangle, ellipse, image }

enum TextAlignment { left, center, right }

class DesignElement {
  DesignElement({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.color = 0xff292722,
    this.opacity = 1,
    this.text = '',
    this.fontSizePt = 28,
    this.bold = false,
    this.textAlignment = TextAlignment.left,
    this.imageBytes,
  }) {
    if (!isSafeId(id) ||
        ![
          x,
          y,
          width,
          height,
          rotation,
          opacity,
          fontSizePt,
        ].every((n) => n.isFinite) ||
        width < 1 ||
        height < 1 ||
        width > 4000 ||
        height > 4000 ||
        x.abs() > 10000 ||
        y.abs() > 10000 ||
        rotation.abs() > 36000 ||
        opacity < 0 ||
        opacity > 1 ||
        fontSizePt < 4 ||
        fontSizePt > 500 ||
        color < 0 ||
        color > 0xffffffff ||
        text.length > 4000) {
      throw const FormatException('Invalid design object.');
    }
    if (kind == ElementKind.image &&
        (imageBytes == null ||
            imageBytes!.isEmpty ||
            imageBytes!.length > maxImportedImageBytes)) {
      throw const FormatException('Image data is missing or exceeds 8 MB.');
    }
  }

  final String id;
  final ElementKind kind;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int color;
  final double opacity;
  final String text;
  final double fontSizePt;
  final bool bold;
  final TextAlignment textAlignment;
  final Uint8List? imageBytes;

  DesignElement copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? color,
    double? opacity,
    String? text,
    double? fontSizePt,
    bool? bold,
    TextAlignment? textAlignment,
  }) => DesignElement(
    id: id ?? this.id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
    text: text ?? this.text,
    fontSizePt: fontSizePt ?? this.fontSizePt,
    bold: bold ?? this.bold,
    textAlignment: textAlignment ?? this.textAlignment,
    imageBytes: imageBytes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'color': color,
    'opacity': opacity,
    'text': text,
    'fontSizePt': fontSizePt,
    'bold': bold,
    'textAlignment': textAlignment.name,
    if (imageBytes != null) 'imageBase64': base64Encode(imageBytes!),
  };

  factory DesignElement.fromJson(Map<String, dynamic> json) {
    try {
      final kind = ElementKind.values.byName(json['kind'] as String);
      final encoded = json['imageBase64'];
      if (encoded != null &&
          (encoded is! String ||
              encoded.length > ((maxImportedImageBytes + 2) ~/ 3) * 4)) {
        throw const FormatException('Image data exceeds the size limit.');
      }
      return DesignElement(
        id: json['id'] as String,
        kind: kind,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        rotation: (json['rotation'] as num).toDouble(),
        color: json['color'] as int,
        opacity: (json['opacity'] as num).toDouble(),
        text: json['text'] as String,
        fontSizePt: (json['fontSizePt'] as num).toDouble(),
        bold: json['bold'] as bool,
        textAlignment: TextAlignment.values.byName(
          json['textAlignment'] as String,
        ),
        imageBytes: encoded == null ? null : base64Decode(encoded as String),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid or unsupported design object.');
    }
  }
}

class DesignDocument {
  DesignDocument({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.updatedAt,
    this.backgroundColor = 0xffffffff,
    List<DesignElement> elements = const [],
  }) : elements = List.unmodifiable(elements) {
    if (!isSafeId(id) ||
        name.trim().isEmpty ||
        name.length > 100 ||
        !widthMm.isFinite ||
        !heightMm.isFinite ||
        widthMm < minPhysicalPageMm ||
        heightMm < minPhysicalPageMm ||
        widthMm > maxPhysicalPageMm ||
        heightMm > maxPhysicalPageMm ||
        backgroundColor < 0 ||
        backgroundColor > 0xffffffff ||
        elements.length > maxDesignElements ||
        elements.map((e) => e.id).toSet().length != elements.length) {
      throw const FormatException(
        'Invalid project dimensions, name, or layers.',
      );
    }
  }

  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final DateTime updatedAt;
  final int backgroundColor;
  final List<DesignElement> elements;

  factory DesignDocument.blank({
    required String name,
    required double widthMm,
    required double heightMm,
  }) => DesignDocument(
    id: newId(),
    name: name.trim(),
    widthMm: widthMm,
    heightMm: heightMm,
    updatedAt: DateTime.now().toUtc(),
  );

  DesignDocument copyWith({
    String? id,
    String? name,
    double? widthMm,
    double? heightMm,
    DateTime? updatedAt,
    int? backgroundColor,
    List<DesignElement>? elements,
  }) => DesignDocument(
    id: id ?? this.id,
    name: name ?? this.name,
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    updatedAt: updatedAt ?? this.updatedAt,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    elements: elements ?? this.elements,
  );

  Map<String, Object?> toJson() => {
    'format': 'desksuite.design',
    'version': currentDesignVersion,
    'id': id,
    'name': name,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'backgroundColor': backgroundColor,
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  static DesignDocument decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxProjectBytes) {
      throw const FormatException('The project is empty or exceeds 32 MB.');
    }
    try {
      _checkJsonNesting(bytes);
      final value = jsonDecode(utf8.decode(bytes));
      if (value is Map<String, dynamic> &&
          value['format'] == null &&
          value['schemaVersion'] == 1) {
        return _decodeLegacyProject(value);
      }
      if (value is! Map<String, dynamic> ||
          value['format'] != 'desksuite.design' ||
          value['version'] != currentDesignVersion) {
        throw const FormatException(
          'Unsupported DeskSuite project format or version.',
        );
      }
      final raw = value['elements'];
      if (raw is! List || raw.length > maxDesignElements) {
        throw const FormatException('Invalid project layers.');
      }
      return DesignDocument(
        id: value['id'] as String,
        name: value['name'] as String,
        widthMm: (value['widthMm'] as num).toDouble(),
        heightMm: (value['heightMm'] as num).toDouble(),
        updatedAt: DateTime.parse(value['updatedAt'] as String),
        backgroundColor: value['backgroundColor'] as int,
        elements: raw
            .map(
              (e) =>
                  DesignElement.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('The project file is malformed.');
    }
  }
}

/// Prevent adversarially deep JSON from exhausting the parser's stack. Strings
/// and escaped quotes are ignored; jsonDecode performs the complete validation.
void _checkJsonNesting(List<int> bytes) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (final byte in bytes) {
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (byte == 0x5c) {
        escaped = true;
      } else if (byte == 0x22) {
        inString = false;
      }
    } else if (byte == 0x22) {
      inString = true;
    } else if (byte == 0x7b || byte == 0x5b) {
      if (++depth > 32) {
        throw const FormatException('Project JSON is nested too deeply.');
      }
    } else if (byte == 0x7d || byte == 0x5d) {
      depth--;
    }
  }
}

/// Import the concurrently developed 0.1 .dsproject format without changing
/// its source file. That editor exported each logical unit as .75 PDF points,
/// corresponding to 96 units per inch; use this to preserve page size.
DesignDocument _decodeLegacyProject(Map<String, dynamic> json) {
  const mmPerUnit = 25.4 / 96;
  final items = json['items'];
  if (items is! List || items.length > maxDesignElements) {
    throw const FormatException('Invalid legacy project layers.');
  }
  final elements = items.map((value) {
    final item = Map<String, dynamic>.from(value as Map);
    final kind = switch (item['kind']) {
      'text' => ElementKind.text,
      'rect' => ElementKind.rectangle,
      'circle' => ElementKind.ellipse,
      'image' => ElementKind.image,
      _ => throw const FormatException('Unsupported legacy layer type.'),
    };
    final encoded = item['imageData'];
    if (encoded != null &&
        (encoded is! String ||
            encoded.length > ((maxImportedImageBytes + 2) ~/ 3) * 4)) {
      throw const FormatException('Legacy image exceeds the 8 MB limit.');
    }
    return DesignElement(
      id: item['id'] as String,
      kind: kind,
      x: (item['x'] as num).toDouble() * mmPerUnit,
      y: (item['y'] as num).toDouble() * mmPerUnit,
      width: (item['w'] as num).toDouble() * mmPerUnit,
      height: (item['h'] as num).toDouble() * mmPerUnit,
      color: item['color'] as int,
      text: item['text'] as String,
      fontSizePt: (item['size'] as num).toDouble() * .75,
      bold: kind == ElementKind.text,
      imageBytes: encoded == null ? null : base64Decode(encoded as String),
    );
  }).toList();
  return DesignDocument(
    id: json['id'] as String,
    name: json['name'] as String,
    widthMm: (json['width'] as num).toDouble() * mmPerUnit,
    heightMm: (json['height'] as num).toDouble() * mmPerUnit,
    updatedAt: DateTime.parse(json['updated'] as String),
    elements: elements,
  );
}
