import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/ids.dart';
import 'design_document.dart';
import 'geometry.dart';

/// Snapshot-based history; a drag is one undoable command, not hundreds.
class DesignController extends ChangeNotifier {
  DesignController(this.document, {this.onChanged});

  DesignDocument document;
  final void Function(DesignDocument document)? onChanged;
  String? selectedId;
  final List<DesignDocument> _undo = [];
  final List<DesignDocument> _redo = [];
  DesignDocument? _gestureStart;
  String? _gestureId;
  bool _resizing = false;
  Offset _gestureDelta = Offset.zero;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  DesignElement? get selected {
    for (final e in document.elements) {
      if (e.id == selectedId) return e;
    }
    return null;
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void _commit(DesignDocument next, {DesignDocument? before}) {
    _undo.add(before ?? document);
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
    document = next.copyWith(updatedAt: DateTime.now().toUtc());
    notifyListeners();
    onChanged?.call(document);
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(document);
    document = _undo.removeLast().copyWith(updatedAt: DateTime.now().toUtc());
    if (selected == null) selectedId = null;
    notifyListeners();
    onChanged?.call(document);
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(document);
    document = _redo.removeLast().copyWith(updatedAt: DateTime.now().toUtc());
    if (selected == null) selectedId = null;
    notifyListeners();
    onChanged?.call(document);
  }

  void add(DesignElement element) {
    if (document.elements.length >= maxDesignElements) {
      throw StateError('Maximum of $maxDesignElements layers reached.');
    }
    final next = document.copyWith(elements: [...document.elements, element]);
    if (next.encode().length > maxProjectBytes) {
      throw StateError('The project would exceed the 32 MB limit.');
    }
    selectedId = element.id;
    _commit(next);
  }

  List<DesignElement> _legacyPhotoLabels(DesignElement slot) => document
      .elements
      .where(
        (element) =>
            element.kind == ElementKind.text &&
            element.text.contains('35 × 45 mm') &&
            element.x >= slot.x &&
            element.x < slot.x + slot.width &&
            element.y >= slot.y &&
            element.y < slot.y + slot.height,
      )
      .toList();

  /// Explicitly marked ID slots or the original labelled 35 × 45 mm slots.
  /// Ordinary rectangles must never be replaced by this action.
  bool get canFillSelectedPhotoPlaceholder {
    final slot = selected;
    if (slot == null || slot.kind != ElementKind.rectangle) return false;
    return slot.text == photoPlaceholderMarker ||
        (slot.width == 35 &&
            slot.height == 45 &&
            _legacyPhotoLabels(slot).isNotEmpty);
  }

  /// Replace the selected supported slot with an image as one undoable edit.
  /// New marked slots never remove text/artwork that overlaps them; the older
  /// printed 35 × 45 mm slot retains its original label-removal behavior.
  void replaceSelectedPhotoPlaceholder(DesignElement imageElement) {
    final slot = selected;
    if (slot == null || slot.kind != ElementKind.rectangle) {
      throw StateError('Select a photo placeholder rectangle first.');
    }
    if (imageElement.kind != ElementKind.image ||
        imageElement.imageBytes == null) {
      throw const FormatException('Choose a valid image for the photo slot.');
    }
    if (!canFillSelectedPhotoPlaceholder) {
      throw StateError('The selected rectangle is not a supported photo slot.');
    }
    final labels = slot.text == photoPlaceholderMarker
        ? const <DesignElement>[]
        : _legacyPhotoLabels(slot);
    if (imageElement.x != slot.x ||
        imageElement.y != slot.y ||
        imageElement.width != slot.width ||
        imageElement.height != slot.height) {
      throw const FormatException(
        'The photo must match the placeholder dimensions.',
      );
    }
    final elements = <DesignElement>[];
    for (final element in document.elements) {
      if (element.id == slot.id) {
        elements.add(imageElement);
      } else if (!labels.any((label) => label.id == element.id)) {
        elements.add(element);
      }
    }
    final next = document.copyWith(elements: elements);
    if (next.encode().length > maxProjectBytes) {
      throw StateError('The project would exceed the 32 MB limit.');
    }
    selectedId = imageElement.id;
    _commit(next);
  }

  void updateSelected(DesignElement Function(DesignElement) update) {
    final item = selected;
    if (item == null) return;
    final updated = update(item);
    final next = document.copyWith(
      elements: [
        for (final e in document.elements) e.id == item.id ? updated : e,
      ],
    );
    if (updated.text != item.text && next.encode().length > maxProjectBytes) {
      throw StateError('The project would exceed the 32 MB limit.');
    }
    _commit(next);
  }

  void duplicateSelected() {
    final item = selected;
    if (item == null) return;
    add(item.copyWith(id: newId(), x: item.x + 5, y: item.y + 5));
  }

  void deleteSelected() {
    final id = selectedId;
    if (id == null) return;
    selectedId = null;
    _commit(
      document.copyWith(
        elements: document.elements.where((e) => e.id != id).toList(),
      ),
    );
  }

  void reorder(int direction) {
    final index = document.elements.indexWhere((e) => e.id == selectedId);
    if (index < 0) return;
    final next = index + direction;
    if (next < 0 || next >= document.elements.length) return;
    final items = [...document.elements];
    final element = items.removeAt(index);
    items.insert(next, element);
    _commit(document.copyWith(elements: items));
  }

  void alignHorizontal(TextAlignment alignment) {
    updateSelected(
      (e) => e.copyWith(
        x: switch (alignment) {
          TextAlignment.left => 0,
          TextAlignment.center => (document.widthMm - e.width) / 2,
          TextAlignment.right => document.widthMm - e.width,
        },
      ),
    );
  }

  void beginGesture(Offset point, {required double handleRadiusMm}) {
    final current = selected;
    _resizing =
        current != null &&
        (point - handlePosition(current)).distance <= handleRadiusMm;
    if (!_resizing) {
      String? hit;
      for (final e in document.elements.reversed) {
        if (containsPoint(e, point)) {
          hit = e.id;
          break;
        }
      }
      selectedId = hit;
    }
    _gestureStart = document;
    _gestureId = selectedId;
    _gestureDelta = Offset.zero;
    notifyListeners();
  }

  void updateGesture(Offset delta) {
    final start = _gestureStart;
    final id = _gestureId;
    if (start == null || id == null) return;
    _gestureDelta += delta;
    final original = start.elements.firstWhere((e) => e.id == id);
    DesignElement changed;
    if (_resizing) {
      final theta = -original.rotation * math.pi / 180;
      final localX =
          _gestureDelta.dx * math.cos(theta) -
          _gestureDelta.dy * math.sin(theta);
      final localY =
          _gestureDelta.dx * math.sin(theta) +
          _gestureDelta.dy * math.cos(theta);
      var width = (original.width + localX).clamp(5.0, 4000.0);
      var height = (original.height + localY).clamp(5.0, 4000.0);
      if (original.kind == ElementKind.image) {
        final dxScale = localX / original.width;
        final dyScale = localY / original.height;
        final deltaScale = dxScale.abs() >= dyScale.abs() ? dxScale : dyScale;
        final minScale = math.max(5 / original.width, 5 / original.height);
        final maxScale = math.min(
          4000 / original.width,
          4000 / original.height,
        );
        final factor = (1 + deltaScale).clamp(minScale, maxScale);
        width = original.width * factor;
        height = original.height * factor;
      }
      // Keep the opposite, rotated corner fixed while the handle is dragged.
      final angle = original.rotation * math.pi / 180;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final oldCentre = Offset(
        original.x + original.width / 2,
        original.y + original.height / 2,
      );
      final anchor =
          oldCentre +
          Offset(
            -original.width / 2 * cos + original.height / 2 * sin,
            -original.width / 2 * sin - original.height / 2 * cos,
          );
      final centre =
          anchor +
          Offset(
            width / 2 * cos - height / 2 * sin,
            width / 2 * sin + height / 2 * cos,
          );
      changed = original.copyWith(
        x: centre.dx - width / 2,
        y: centre.dy - height / 2,
        width: width,
        height: height,
      );
    } else {
      changed = original.copyWith(
        x: (original.x + _gestureDelta.dx).clamp(-10000.0, 10000.0),
        y: (original.y + _gestureDelta.dy).clamp(-10000.0, 10000.0),
      );
    }
    document = start.copyWith(
      elements: [for (final e in start.elements) e.id == id ? changed : e],
    );
    notifyListeners();
  }

  void endGesture() {
    final start = _gestureStart;
    _gestureStart = null;
    _gestureId = null;
    if (start != null && _gestureDelta.distance > 0.01) {
      _commit(document, before: start);
    }
    _gestureDelta = Offset.zero;
  }
}
