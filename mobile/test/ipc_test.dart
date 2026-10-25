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

    test('IpcPdfGenerator generates valid PDF for preview modal', () async {
      final doc = IpcDocument(
        id: 'preview-test-id',
        documentNumber: 'IPC-PREVIEW-001',
        projectName: 'HIGHWAY 96 WIDENING',
        clientName: 'Ministry of Transportation',
        date: DateTime.now(),
        status: 'Draft',
        totalAmount: 25000.0,
        items: [
          IpcItem(itemType: 'heading', description: 'CLASS A: EARTHWORKS', sortOrder: 0),
          IpcItem(
            itemType: 'item',
            itemNumber: 'A1',
            description: 'Site excavation in all materials',
            unit: 'm3',
            quantity: 500.0,
            rate: 50.0,
            amount: 25000.0,
            sortOrder: 1,
          ),
        ],
      );

      final bytes = await IpcPdfGenerator.generatePdf(doc);
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });

    test('IpcItem row highlighter serialization, PDF, and Excel support', () async {
      final highlightedItem = IpcItem(
        itemType: 'item',
        itemNumber: 'H1',
        description: 'Critical highlighted trench excavation work',
        unit: 'm',
        quantity: 120.0,
        rate: 45.0,
        amount: 5400.0,
        isHighlighted: true,
        highlightColor: '#FEF9C3',
      );

      expect(highlightedItem.isHighlighted, isTrue);
      expect(highlightedItem.highlightColorHex, '#FEF9C3');

      // Test serialization & round-trip
      final json = highlightedItem.toJson();
      expect(json['is_highlighted'], isTrue);
      expect(json['highlight_color'], '#FEF9C3');

      final restoredItem = IpcItem.fromJson(json);
      expect(restoredItem.isHighlighted, isTrue);
      expect(restoredItem.highlightColor, '#FEF9C3');

      final docWithHighlight = IpcDocument(
        id: 'doc-highlight-test',
        documentNumber: 'IPC-HL-01',
        projectName: 'PROJECT WITH HIGHLIGHTED SECTION',
        date: DateTime.now(),
        totalAmount: 5400.0,
        items: [highlightedItem],
      );

      // Verify PDF generation with highlighted row
      final pdfBytes = await IpcPdfGenerator.generatePdf(docWithHighlight);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);

      // Verify Excel generation with highlighted row
      final excelBytes = await IpcExcelGenerator.generateExcel(docWithHighlight);
      expect(excelBytes, isNotEmpty);
    });

    test('Material Deduction Sheet model, calculation, PDF and Excel generation', () async {
      final deduction1 = IpcDeductionItem(
        itemNumber: '21',
        description: '1000mm Dia GRP Pipes',
        unit: 'm',
        contractRate: 60.0,
        thisPeriodQuantity: 58.5,
        thisPeriodAmount: 3510.0,
        cumulativeQuantity: 58.5,
        cumulativeAmount: 3510.0,
      );

      final deduction2 = IpcDeductionItem(
        itemNumber: '27',
        description: 'Machinery deduction',
        thisPeriodAmount: 1418.750,
        cumulativeAmount: 1418.750,
        isHighlighted: true,
      );

      final deduction3 = IpcDeductionItem(
        itemNumber: '31',
        description: 'Gullies',
        unit: 'nrs',
        contractRate: 27.0,
        previousQuantity: 126.0,
        previousAmount: 3402.0,
        cumulativeQuantity: 126.0,
        cumulativeAmount: 3402.0,
      );

      final doc = IpcDocument(
        id: 'doc-deduction-test',
        documentNumber: 'IPA # 03',
        projectName: 'RASHID EQUESTRIAN HORSE RACING CLUB ACCESS -SECTION 2',
        mainContractor: 'KINGDOM ASPHALT CO WLL',
        subContractor: 'AL NADEERA CONTRACTING WLL',
        date: DateTime(2026, 9, 3),
        totalAmount: 12500.0,
        items: [
          IpcItem(
            itemType: 'item',
            description: 'Main Work Item',
            unit: 'm',
            quantity: 10,
            rate: 1250,
            amount: 12500,
          ),
        ],
        deductions: [deduction1, deduction2, deduction3],
      );

      expect(doc.hasDeductions, isTrue);
      expect(doc.totalDeductionPrevious, 3402.0);
      expect(doc.totalDeductionThisPeriod, 3510.0 + 1418.750);
      expect(doc.totalDeductionCumulative, 3510.0 + 1418.750 + 3402.0);

      // JSON Round-trip
      final json = doc.toJson();
      expect(json['deductions'], isList);
      expect((json['deductions'] as List).length, 3);
      expect(json['main_contractor'], 'KINGDOM ASPHALT CO WLL');

      final fromJson = IpcDocument.fromJson(json);
      expect(fromJson.hasDeductions, isTrue);
      expect(fromJson.deductions.length, 3);
      expect(fromJson.deductions[1].isHighlighted, isTrue);
      expect(fromJson.deductions[1].highlightColorHex, '#FFFF00');

      // Verify PDF generation with Landscape Material Deduction Annexure
      final pdfBytes = await IpcPdfGenerator.generatePdf(doc);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF

      // Verify Excel generation with Material Deduction worksheet
      final excelBytes = await IpcExcelGenerator.generateExcel(doc);
      expect(excelBytes, isNotEmpty);
    });
  });
}
