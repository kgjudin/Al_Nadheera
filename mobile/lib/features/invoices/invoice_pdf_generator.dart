import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/document_template_model.dart';
import '../../models/invoice_model.dart';
import '../../services/document_template_service.dart';

class InvoicePdfGenerator {
  static Future<Uint8List> generateInvoicePdf(
    Invoice invoice, {
    DocumentTemplate? customTemplate,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('yyyy-MM-dd');
    final cf = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

    final template = customTemplate ??
        DocumentTemplateService.instance.getTemplate('invoice');

    final isPaid = invoice.isPaid;
    final primaryColor = PdfColor.fromHex(template.primaryColor);
    final accentColor = PdfColor.fromHex(template.accentColor);
    final paidColor = PdfColor.fromHex('#137333');
    final pendingColor = PdfColor.fromHex('#D93025');

    // Download custom images if present
    pw.MemoryImage? logoImage;
    if (template.logoUrl != null && template.logoUrl!.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(template.logoUrl!));
        if (res.statusCode == 200) {
          logoImage = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    pw.MemoryImage? sealImage;
    if (template.sealUrl != null && template.sealUrl!.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(template.sealUrl!));
        if (res.statusCode == 200) {
          sealImage = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    pw.MemoryImage? signatureImage;
    if (template.signatureUrl != null && template.signatureUrl!.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(template.signatureUrl!));
        if (res.statusCode == 200) {
          signatureImage = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Bar with Company Header & Status Badge
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Branding
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (logoImage != null)
                              pw.Container(
                                width: 50,
                                height: 50,
                                margin: const pw.EdgeInsets.only(right: 12),
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              )
                            else
                              pw.Container(
                                width: 42,
                                height: 42,
                                margin: const pw.EdgeInsets.only(right: 12),
                                decoration: pw.BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    template.companyNameEn.isNotEmpty
                                        ? template.companyNameEn.substring(0, 2).toUpperCase()
                                        : 'AN',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    template.companyNameEn,
                                    style: pw.TextStyle(
                                      color: primaryColor,
                                      fontSize: 15,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (template.companyNameAr != null && template.companyNameAr!.isNotEmpty) ...[
                                    pw.SizedBox(height: 1),
                                    pw.Text(
                                      template.companyNameAr!,
                                      style: pw.TextStyle(
                                        color: primaryColor,
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  if (template.tagline != null && template.tagline!.isNotEmpty) ...[
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      template.tagline!,
                                      style: const pw.TextStyle(
                                        color: PdfColors.grey700,
                                        fontSize: 8.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          '${template.address} • CR: ${template.crNumber ?? "N/A"} • VAT: ${template.vatNumber ?? "N/A"}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Phone: ${template.phone} • Email: ${template.email}${template.website != null ? " • Web: ${template.website}" : ""}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Invoice Label and Status Badge/Stamp
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: pw.TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),

                      // Prominent Stamp Badge: PAID or PENDING
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: isPaid
                              ? PdfColor.fromHex('#E6F4EA')
                              : PdfColor.fromHex('#FCE8E6'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(
                            color: isPaid ? paidColor : pendingColor,
                            width: 1.5,
                          ),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              isPaid ? 'PAID' : 'PENDING PAYMENT',
                              style: pw.TextStyle(
                                color: isPaid ? paidColor : pendingColor,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Two Column Info: Bill To & Invoice Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO:',
                            style: pw.TextStyle(
                              color: primaryColor,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.customerName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                          if (invoice.customerAddress != null && invoice.customerAddress!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Address: ${invoice.customerAddress}', style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                          if (invoice.customerVatNumber != null && invoice.customerVatNumber!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('VAT / CR: ${invoice.customerVatNumber}', style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                          if (invoice.siteName != null && invoice.siteName!.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue50,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                'Project / Site: ${invoice.siteName}',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 14),

                  // Invoice Metadata
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey200),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INVOICE DETAILS:',
                            style: pw.TextStyle(
                              color: primaryColor,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildPdfKeyValue('Invoice Date:', df.format(invoice.date)),
                          if (invoice.dueDate != null)
                            _buildPdfKeyValue('Due Date:', df.format(invoice.dueDate!)),
                          _buildPdfKeyValue('Payment Status:', invoice.status.toUpperCase(), isStatus: true, isPaid: isPaid),
                          _buildPdfKeyValue('Currency:', 'BHD (Bahraini Dinar)'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (invoice.description != null && invoice.description!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F1F5F9'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Subject / Description: ${invoice.description}',
                    style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                  ),
                ),
              ],

              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    template.footerText ?? 'Al Nadheera Contracting W.L.L. • Kingdom of Bahrain',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          final items = invoice.items;

          return [
            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),
                1: pw.FlexColumnWidth(5),
                2: pw.FixedColumnWidth(48),
                3: pw.FixedColumnWidth(80),
                4: pw.FixedColumnWidth(85),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Item / Service Description', isHeader: true),
                    _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
                    _buildTableCell('Total (BHD)', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Data Rows
                for (int i = 0; i < items.length; i++) ...[
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),
                    ),
                    children: [
                      _buildTableCell('${i + 1}', align: pw.TextAlign.center),
                      _buildTableCell(items[i].itemDescription),
                      _buildTableCell(
                        items[i].quantity % 1 == 0
                            ? items[i].quantity.toInt().toString()
                            : items[i].quantity.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                      ),
                      _buildTableCell(cf.format(items[i].unitPrice), align: pw.TextAlign.right),
                      _buildTableCell(cf.format(items[i].amount), align: pw.TextAlign.right, isBold: true),
                    ],
                  ),
                ],
                if (items.isEmpty)
                  pw.TableRow(
                    children: [
                      _buildTableCell('-', align: pw.TextAlign.center),
                      _buildTableCell(invoice.description ?? 'General Contracting Services'),
                      _buildTableCell('1', align: pw.TextAlign.center),
                      _buildTableCell(cf.format(invoice.subtotal), align: pw.TextAlign.right),
                      _buildTableCell(cf.format(invoice.subtotal), align: pw.TextAlign.right, isBold: true),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 14),

            // Summary Calculation & Seal/Signature Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Payment Terms, Notes, Official Seal & Signature
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Notes / Terms
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        pw.Text(
                          'Notes & Instructions:',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          invoice.notes!,
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.SizedBox(height: 8),
                      ],

                      // Bank Transfer Details
                      if (template.showBankDetails && template.bankName != null && template.bankName!.isNotEmpty) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8FAFC'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Payment Information / Bank Details:',
                                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text('Bank: ${template.bankName}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                              if (template.accountName != null)
                                pw.Text('Account Name: ${template.accountName}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                              if (template.iban != null)
                                pw.Text('IBAN: ${template.iban}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                              if (template.swiftCode != null && template.swiftCode!.isNotEmpty)
                                pw.Text('SWIFT: ${template.swiftCode}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 12),
                      ],

                      // Seal and Signature Block
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Seal Stamp Block
                          if (template.showSeal) ...[
                            if (sealImage != null)
                              pw.Container(
                                width: 75,
                                height: 75,
                                child: pw.Image(sealImage, fit: pw.BoxFit.contain),
                              )
                            else
                              pw.Container(
                                width: 75,
                                height: 75,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  border: pw.Border.all(color: primaryColor, width: 1.5),
                                ),
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Container(
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(color: primaryColor, width: 0.8),
                                  ),
                                  child: pw.Center(
                                    child: pw.Column(
                                      mainAxisAlignment: pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text(
                                          '★ OFFICIAL ★',
                                          style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                        ),
                                        pw.Text(
                                          'SEAL',
                                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                        ),
                                        pw.Text(
                                          'KINGDOM OF BAHRAIN',
                                          style: pw.TextStyle(fontSize: 4, color: primaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            pw.SizedBox(width: 16),
                          ],

                          // Signature Block
                          if (template.showSignature) ...[
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (signatureImage != null)
                                    pw.Container(
                                      height: 38,
                                      child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                                    )
                                  else
                                    pw.SizedBox(height: 22),
                                  pw.Container(height: 1, color: PdfColors.grey500),
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    'Authorized Signatory & Date',
                                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                  ),
                                  pw.Text(
                                    template.companyNameEn,
                                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 16),

                // Right: Financial Summary Breakdown
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal:', cf.format(invoice.subtotal)),
                        if (invoice.discount > 0)
                          _buildSummaryRow(
                            invoice.discountType == 'percentage'
                                ? 'Discount (${invoice.discount.toStringAsFixed(0)}%):'
                                : 'Discount:',
                            '- ${cf.format(invoice.discount)}',
                            isNegative: true,
                          ),
                        if (invoice.vatAmount > 0 || invoice.vatRate > 0)
                          _buildSummaryRow(
                            invoice.vatRate > 0
                                ? 'VAT (${invoice.vatRate.toStringAsFixed(0)}%):'
                                : 'VAT:',
                            '+ ${cf.format(invoice.vatAmount)}',
                            isPositive: true,
                          ),
                        pw.Divider(thickness: 1, color: primaryColor),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              isPaid ? 'TOTAL PAID:' : 'TOTAL DUE:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.Text(
                              cf.format(invoice.totalAmount),
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: isPaid ? paidColor : primaryColor,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),

                        // Payment Status Highlight in Summary Box
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: isPaid ? PdfColor.fromHex('#E6F4EA') : PdfColor.fromHex('#FFF0F0'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              isPaid ? 'PAID IN FULL' : 'PAYMENT PENDING',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: isPaid ? paidColor : pendingColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfKeyValue(String key, String value, {bool isStatus = false, bool isPaid = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: isStatus
                  ? (isPaid ? PdfColor.fromHex('#137333') : PdfColor.fromHex('#D93025'))
                  : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isNegative = false,
    bool isPositive = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: isNegative
                  ? PdfColor.fromHex('#D93025')
                  : isPositive
                      ? PdfColor.fromHex('#137333')
                      : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
