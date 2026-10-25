import 'dart:io' as import_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:al_nadheera_construction/core/utils/currency_words_converter.dart';
import 'package:al_nadheera_construction/features/invoices/b2b_quotation_pdf_generator.dart';
import 'package:al_nadheera_construction/models/invoice_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CurrencyWordsConverter converts 349994.700 correctly', () {
    final words = CurrencyWordsConverter.toBahrainiDinarsWords(349994.700);
    expect(
      words,
      'Bahraini Dinars three Hundred forty nine Thousand nine hundred ninety four and seven hundred fills only',
    );
  });

  test('B2bQuotationPdfGenerator generates valid PDF bytes matching format', () async {
    final invoice = Invoice(
      id: 'test-inv-01',
      invoiceNumber: 'ANCC-032/026',
      date: DateTime(2026, 5, 10),
      status: 'Active',
      customerName: 'Kingdom Asphalt W.L.L,',
      customerAddress: 'Manama,\nKingdom of Bahrain.',
      subject: 'REVISED QUOTATION FOR STORM WATER IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD',
      salutation: 'Respected Sir,',
      introText: 'We with kind esteem would like to inform you that we confirm our committed intention to engage in your Project...',
      tableHeaderTitle: 'STORM WATER HIGHWAY 96',
      subtotal: 318177.00,
      vatRate: 10,
      vatAmount: 31817.700,
      totalAmount: 349994.700,
      items: [
        InvoiceItem(
          itemClass: 'I',
          itemDescription: 'PIPEWORK - PIPES',
          quantity: 1,
          unitPrice: 136753.00,
          amount: 136753.00,
        ),
        InvoiceItem(
          itemClass: 'J',
          itemDescription: 'PIPEWORK - FITTINGS AND VALVES',
          quantity: 1,
          unitPrice: 7326.00,
          amount: 7326.00,
        ),
        InvoiceItem(
          itemClass: 'K',
          itemDescription: 'PIPEWORK - MANHOLES AND PIPEWORK ANCILLARIES',
          quantity: 1,
          unitPrice: 98810.00,
          amount: 98810.00,
        ),
        InvoiceItem(
          itemClass: 'L',
          itemDescription: 'PIPEWORK - SUPPORTS & PROTECTION',
          quantity: 1,
          unitPrice: 75288.00,
          amount: 75288.00,
        ),
      ],
      createdAt: DateTime.now(),
      sourceConfig: {
        'pageFormat': 'A4',
        'pageMode': 'PORTRAIT',
        'fontType': 'Helvetica',
        'marginTop': 0,
        'marginLeft': 0,
      },
    );

    final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(invoice);
    expect(pdfBytes, isNotEmpty);
    // PDF files start with header "%PDF" (0x25, 0x50, 0x44, 0x46)
    expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    import_io.File('output_sample_b2b_quotation.pdf').writeAsBytesSync(pdfBytes);
  });

  test('Invoice and InvoiceItem dual-mode serialization preserves all metadata', () {
    final original = Invoice(
      id: 'inv-test-dual',
      invoiceNumber: 'ANCC-099/2026',
      date: DateTime(2026, 6, 1),
      customerName: 'Test Client Ltd',
      documentType: 'B2B',
      subject: 'PROJECT STORM WATER',
      salutation: 'Dear Sir,',
      introText: 'Official quotation text',
      tableHeaderTitle: 'HIGHWAY 96',
      sourceConfig: {'fontType': 'Helvetica', 'marginTop': 15},
      items: [
        InvoiceItem(
          itemClass: 'J',
          itemDescription: 'VALVES & PIPES',
          quantity: 2,
          unitPrice: 500,
        ),
      ],
      createdAt: DateTime.now(),
    );

    // 1. Dedicated columns mode
    final dedicatedJson = original.toJson(useDedicatedColumns: true);
    expect(dedicatedJson['document_type'], 'B2B');
    expect(dedicatedJson['subject'], 'PROJECT STORM WATER');
    final restoredFromDedicated = Invoice.fromJson(dedicatedJson);
    expect(restoredFromDedicated.documentType, 'B2B');
    expect(restoredFromDedicated.subject, 'PROJECT STORM WATER');

    // 2. Fallback mode (no new columns in DB schema)
    final fallbackJson = original.toJson(useDedicatedColumns: false);
    expect(fallbackJson.containsKey('document_type'), isFalse);
    expect(fallbackJson.containsKey('subject'), isFalse);
    expect(fallbackJson['notes'], contains('<!--B2B_META:'));

    final fallbackItemJson = original.items.first.toJson(useDedicatedColumns: false);
    expect(fallbackItemJson.containsKey('item_class'), isFalse);
    expect(fallbackItemJson['item_description'], '[CLASS: J] VALVES & PIPES');

    final restoredFromFallback = Invoice.fromJson(fallbackJson);
    expect(restoredFromFallback.documentType, 'B2B');
    expect(restoredFromFallback.subject, 'PROJECT STORM WATER');
    expect(restoredFromFallback.tableHeaderTitle, 'HIGHWAY 96');

    final restoredItem = InvoiceItem.fromJson(fallbackItemJson);
    expect(restoredItem.itemClass, 'J');
    expect(restoredItem.itemDescription, 'VALVES & PIPES');
  });

  test('B2bQuotationPdfGenerator handles large item lists across multiple pages seamlessly', () async {
    final manyItems = List.generate(
      35,
      (i) => InvoiceItem(
        itemClass: String.fromCharCode(65 + (i % 26)),
        itemDescription: 'CONSTRUCTION SERVICE & MATERIAL SPECIFICATION ITEM #${i + 1} - DETAILED SCOPE',
        quantity: 1,
        unitPrice: (i + 1) * 1000.0,
        amount: (i + 1) * 1000.0,
      ),
    );

    final subtotal = manyItems.fold<double>(0.0, (sum, it) => sum + it.amount);
    final vat = subtotal * 0.10;
    final total = subtotal + vat;

    final multiPageInvoice = Invoice(
      id: 'inv-multipage-test',
      invoiceNumber: 'ANCC-MULTI/2026',
      date: DateTime.now(),
      status: 'Active',
      customerName: 'Multi-Page Construction Client W.L.L',
      customerAddress: 'Building 100, Road 200\nManama, Kingdom of Bahrain',
      subject: 'COMPREHENSIVE MULTI-PAGE INFRASTRUCTURE EXPANSION WORKS',
      salutation: 'Respected Sir,',
      introText: 'We submit our extensive schedule of BOQ items below spanning across multiple sheets.',
      tableHeaderTitle: 'MAJOR CIVIL & STRUCTURAL WORKS',
      subtotal: subtotal,
      vatRate: 10,
      vatAmount: vat,
      totalAmount: total,
      items: manyItems,
      createdAt: DateTime.now(),
    );

    final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(multiPageInvoice);
    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    import_io.File('output_sample_multipage_quotation.pdf').writeAsBytesSync(pdfBytes);
  });

  test('Invoice showSealSignatureArea toggle and PDF generation', () async {
    final invWithSeal = Invoice(
      id: 'inv-seal-01',
      invoiceNumber: 'ANCC-SEAL/2026',
      date: DateTime.now(),
      customerName: 'Al Nadheera Partner Co.',
      customerAddress: 'Riffa, Bahrain',
      totalAmount: 1250.000,
      showSealSignatureArea: true,
      createdAt: DateTime.now(),
    );

    expect(invWithSeal.showSealSignatureArea, isTrue);

    // Serialization
    final json = invWithSeal.toJson();
    expect(json['source_config']['showSealSignatureArea'], isTrue);

    final restored = Invoice.fromJson(json);
    expect(restored.showSealSignatureArea, isTrue);

    // Test toggle to false
    final disabled = restored.copyWith(showSealSignatureArea: false);
    expect(disabled.showSealSignatureArea, isFalse);
    expect(disabled.toJson()['source_config']['showSealSignatureArea'], isFalse);

    // Test PDF generation with seal & signature enabled
    final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(invWithSeal);
    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    import_io.File('output_sample_seal_signature.pdf').writeAsBytesSync(pdfBytes);
  });
}

