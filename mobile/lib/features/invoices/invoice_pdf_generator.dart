import 'dart:typed_data';
import '../../models/document_template_model.dart';
import '../../models/invoice_model.dart';
import 'b2b_quotation_pdf_generator.dart';

/// Official Al Nadheera PDF Generator (delegates to the B2B Quotation / BOQ format matching Image 1)
class InvoicePdfGenerator {
  /// Generates the official Al Nadheera document format matching Image 1
  static Future<Uint8List> generateInvoicePdf(
    Invoice invoice, {
    DocumentTemplate? customTemplate,
  }) async {
    return B2bQuotationPdfGenerator.generatePdf(
      invoice,
      customTemplate: customTemplate,
    );
  }
}
