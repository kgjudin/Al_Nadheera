import 'package:flutter_test/flutter_test.dart';
import 'package:al_nadheera_construction/models/product_model.dart';

void main() {
  group('Product Hierarchy (Class -> Submodule -> Product)', () {
    test('ProductClass serialization and deserialization', () {
      final pc = ProductClass(
        id: 'cls-01',
        name: 'CLASS I PIPE WORK',
        createdAt: DateTime(2026, 10, 17),
      );

      final json = pc.toJson();
      expect(json['id'], 'cls-01');
      expect(json['name'], 'CLASS I PIPE WORK');

      final restored = ProductClass.fromJson(json);
      expect(restored.id, 'cls-01');
      expect(restored.name, 'CLASS I PIPE WORK');
    });

    test('ProductSubmodule serialization and deserialization', () {
      final sub = ProductSubmodule(
        id: 'sub-01',
        classId: 'cls-01',
        className: 'CLASS I PIPE WORK',
        name: 'Pipe',
        createdAt: DateTime(2026, 10, 17),
      );

      final json = sub.toJson();
      expect(json['id'], 'sub-01');
      expect(json['class_id'], 'cls-01');
      expect(json['class_name'], 'CLASS I PIPE WORK');
      expect(json['name'], 'Pipe');

      final restored = ProductSubmodule.fromJson(json);
      expect(restored.id, 'sub-01');
      expect(restored.classId, 'cls-01');
      expect(restored.className, 'CLASS I PIPE WORK');
      expect(restored.name, 'Pipe');
    });

    test('Product handles full Class, Sub-module, Unit, and Price fields', () {
      final p = Product(
        id: 'prod-01',
        className: 'CLASS I PIPE WORK',
        classId: 'cls-01',
        submoduleName: 'Pipe',
        submoduleId: 'sub-01',
        name: '300 MM PIPE 1 MTR TO 1.5',
        unit: 'METER',
        price: 32.0,
      );

      final json = p.toJson();
      expect(json['class_name'], 'CLASS I PIPE WORK');
      expect(json['class_id'], 'cls-01');
      expect(json['submodule_name'], 'Pipe');
      expect(json['submodule_id'], 'sub-01');
      expect(json['name'], '300 MM PIPE 1 MTR TO 1.5');
      expect(json['unit'], 'METER');
      expect(json['price'], 32.0);

      final restored = Product.fromJson(json);
      expect(restored.className, 'CLASS I PIPE WORK');
      expect(restored.classId, 'cls-01');
      expect(restored.submoduleName, 'Pipe');
      expect(restored.submoduleId, 'sub-01');
      expect(restored.name, '300 MM PIPE 1 MTR TO 1.5');
      expect(restored.unit, 'METER');
      expect(restored.price, 32.0);
    });
  });
}
