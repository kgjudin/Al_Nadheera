import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_nadheera_construction/models/ipc_model.dart';
import 'package:al_nadheera_construction/models/product_model.dart';
import 'package:al_nadheera_construction/features/ipc/services/ipc_pdf_generator.dart';
import 'package:al_nadheera_construction/features/ipc/services/ipc_excel_generator.dart';
import 'package:al_nadheera_construction/features/ipc/create_edit_ipc_screen.dart';
import 'package:al_nadheera_construction/features/ipc/ipc_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IPC Model and Calculation Tests', () {
    test('Calculates item amount and grand total correctly', () {
      final heading = IpcItem(
        itemType: 'heading',
        description: 'CLASS I : PIPEWORK-PIPES',
        sortOrder: 0,
      );

      final item1 = IpcItem(
        itemType: 'item',
        itemNumber: 'I1',
        description: 'Pipes; clay, vitrified clay, standard strength; s & s joints; in trenches, beds or other supports, depth not exceeding 1.5m; 150mm nominal size',
        unit: 'm',
        quantity: 957.0,
        rate: 15.0,
        amount: 957.0 * 15.0,
        sortOrder: 1,
      );

      final item2 = IpcItem(
        itemType: 'item',
        itemNumber: 'I2',
        description: 'Extra for bends, nominal bore 150mm',
        unit: 'nr',
        quantity: 20.0,
        rate: 25.0,
        amount: 20.0 * 25.0,
        sortOrder: 2,
      );

      final doc = IpcDocument(
        id: 'test-123',
        documentNumber: 'IPC-001',
        projectName: 'IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD',
        clientName: 'Ministry of Works',
        date: DateTime(2026, 10, 17),
        status: 'Submitted',
        totalAmount: item1.amount + item2.amount,
        items: [heading, item1, item2],
      );

      expect(item1.amount, 14355.0);
      expect(item2.amount, 500.0);
      expect(doc.totalAmount, 14855.0);
      expect(doc.items.length, 3);

      // JSON serialization round-trip
      final jsonMap = doc.toJson();
      final fromJson = IpcDocument.fromJson(jsonMap);
      expect(fromJson.documentNumber, 'IPC-001');
      expect(fromJson.items.length, 3);
      expect(fromJson.items[1].quantity, 957.0);
      expect(fromJson.items[1].rate, 15.0);
      expect(fromJson.items[1].amount, 14355.0);
    });

    test('Generates PDF bytes without exceptions', () async {
      final doc = IpcDocument(
        id: 'test-doc',
        documentNumber: 'IPC-001',
        projectName: 'IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD',
        clientName: 'Client Alpha',
        date: DateTime(2026, 10, 17),
        status: 'Draft',
        totalAmount: 139000.0,
        items: [
          IpcItem(
            itemType: 'heading',
            description: 'CLASS 1 PIPE WORKS-PIPE',
            sortOrder: 0,
          ),
          IpcItem(
            itemType: 'subheading',
            description: 'Nominal bore 400mm',
            sortOrder: 1,
          ),
          IpcItem(
            itemType: 'item',
            itemNumber: 'I1',
            description: 'In trenches, depth not exceeding 1.50 m',
            unit: 'M',
            quantity: 15.0,
            rate: 9000.0,
            amount: 135000.0,
            sortOrder: 2,
          ),
          IpcItem(
            itemType: 'item',
            itemNumber: 'I2',
            description: 'In trenches, depth 1.5 m to 2.0 m',
            unit: 'M',
            quantity: 4.0,
            rate: 500.0,
            amount: 2000.0,
            sortOrder: 3,
          ),
          IpcItem(
            itemType: 'item',
            itemNumber: 'I3',
            description: 'In trenches, depth 2.0 m to 2.5 m',
            unit: 'M',
            quantity: 4.0,
            rate: 500.0,
            amount: 2000.0,
            sortOrder: 4,
          ),
          IpcItem(
            itemType: 'heading',
            description: 'CLASS J PIPEWORK - FITTINGS AND VALVES',
            sortOrder: 5,
          ),
          IpcItem(
            itemType: 'subheading',
            description: 'Valves',
            sortOrder: 6,
          ),
          IpcItem(
            itemType: 'item',
            itemNumber: 'I4',
            description: 'In trenches, depth 1.5 m to 2.0 m',
            unit: 'M',
            quantity: 0.0,
            rate: 0.0,
            amount: 0.0,
            sortOrder: 7,
          ),
        ],
      );

      final pdfBytes = await IpcPdfGenerator.generatePdf(doc);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
      File('test_ipc_output.pdf').writeAsBytesSync(pdfBytes);
    });

    test('Generates Excel (.xlsx) bytes without exceptions', () async {
      final doc = IpcDocument(
        id: 'test-doc',
        documentNumber: 'IPC-001',
        projectName: 'IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD',
        clientName: 'Client Alpha',
        date: DateTime(2026, 10, 17),
        status: 'Draft',
        totalAmount: 14355.0,
        items: [
          IpcItem(
            itemType: 'heading',
            description: 'CLASS I : PIPEWORK-PIPES',
            sortOrder: 0,
          ),
          IpcItem(
            itemType: 'item',
            itemNumber: 'I1',
            description: 'Pipes; clay, vitrified clay; depth not exceeding 1.5m; 150mm nominal size',
            unit: 'm',
            quantity: 957.0,
            rate: 15.0,
            amount: 14355.0,
            sortOrder: 1,
          ),
        ],
      );

      final excelBytes = await IpcExcelGenerator.generateExcelBytes(doc);
      expect(excelBytes, isNotEmpty);
      expect(excelBytes.length, greaterThan(100));
    });

    test('CreateEditIpcScreen and IpcListScreen can be instantiated', () {
      const editScreen = CreateEditIpcScreen();
      expect(editScreen, isNotNull);

      const listScreen = IpcListScreen();
      expect(listScreen, isNotNull);
    });

    test('Product specification correctly maps to IPC item row with unit and rate', () {
      final product = Product(
        id: 'p-1',
        name: 'In trenches, depth not exceeding 1.50 m',
        unit: 'METER',
        price: 15.0,
        className: 'CLASS 1 PIPE WORKS-PIPE',
        submoduleName: 'Nominal bore 600mm',
      );

      final row = IpcItem(
        itemType: 'item',
        itemNumber: 'I1',
        description: product.name,
        unit: product.unit,
        rate: product.price,
        quantity: 100.0,
        amount: 100.0 * product.price,
        className: product.className,
        submoduleName: product.submoduleName,
        productId: product.id,
      );

      expect(row.description, 'In trenches, depth not exceeding 1.50 m');
      expect(row.unit, 'METER');
      expect(row.rate, 15.0);
      expect(row.amount, 1500.0);
      expect(row.className, 'CLASS 1 PIPE WORKS-PIPE');
      expect(row.submoduleName, 'Nominal bore 600mm');
    });
  });
}
