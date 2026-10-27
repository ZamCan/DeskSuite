import 'package:desksuite/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design project serializes and restores editable elements', () {
    final project = Project(name: 'Test poster')
      ..items.add({
        'id': 'one',
        'kind': 'text',
        'text': 'Hello',
        'x': 10.0,
        'y': 20.0,
        'w': 100.0,
        'h': 50.0,
        'color': 0xFF292B29,
        'size': 24.0,
      });
    final restored = Project.fromJson(project.toJson());
    expect(restored.name, 'Test poster');
    expect(restored.items, hasLength(1));
    expect(restored.items.single['text'], 'Hello');
    expect(restored.items.single['x'], 10.0);
  });
}
