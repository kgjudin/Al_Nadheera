import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_words_converter.dart';
import '../../models/document_template_model.dart';
import '../../models/invoice_model.dart';
import '../../services/document_template_service.dart';

class B2bQuotationPdfGenerator {
  static final NumberFormat _currFormat = NumberFormat('#,##0.000', 'en_US');
  static final NumberFormat _twoDecFormat = NumberFormat('#,##0.00', 'en_US');

  /// Formats currency with commas and appropriate decimal places
  static String formatAmount(double value, {bool forceThreeDecimals = false}) {
    if (forceThreeDecimals || (value * 1000) % 10 != 0) {
      return _currFormat.format(value);
    }
    return _twoDecFormat.format(value);
  }

  /// Generates the exact PDF matching the Al Nadheera Quotation / B2B Document format
  static Future<Uint8List> generatePdf(
    Invoice invoice, {
    DocumentTemplate? customTemplate,
    bool? showSealSignatureArea,
  }) async {
    final pdf = pw.Document();

    final effectiveShowSealSignature = showSealSignatureArea ?? invoice.showSealSignatureArea;

    DocumentTemplate template;
    if (customTemplate != null) {
      template = customTemplate;
    } else {
      try {
        template = DocumentTemplateService.instance.getTemplate('quotation');
      } catch (_) {
        template = DocumentTemplate.defaultTemplate('quotation');
      }
    }

    // Load fonts
    pw.Font? baseFont;
    pw.Font? boldFont;
    pw.Font? arabicFont;

    final fontType = invoice.sourceConfig?['fontType']?.toString().toLowerCase() ?? 'helvetica';
    try {
      if (fontType == 'times new roman') {
        baseFont = await PdfGoogleFonts.merriweatherRegular();
        boldFont = await PdfGoogleFonts.merriweatherBold();
      } else if (fontType == 'courier') {
        baseFont = await PdfGoogleFonts.courierPrimeRegular();
        boldFont = await PdfGoogleFonts.courierPrimeBold();
      } else {
        baseFont = await PdfGoogleFonts.robotoRegular();
        boldFont = await PdfGoogleFonts.robotoBold();
      }
    } catch (_) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    try {
      arabicFont = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      try {
        arabicFont = await PdfGoogleFonts.amiriBold();
      } catch (_) {}
    }

    // Load Image Assets from local asset bundle
    pw.MemoryImage? headerImage;
    pw.MemoryImage? emblemImage;
    pw.MemoryImage? watermarkImage;
    pw.MemoryImage? constellationImage;

    try {
      final headerBytes = await rootBundle.load('assets/images/al_nadheera_header.png');
      headerImage = pw.MemoryImage(headerBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final emblemBytes = await rootBundle.load('assets/images/al_nadheera_emblem.png');
      emblemImage = pw.MemoryImage(emblemBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final wmBytes = await rootBundle.load('assets/images/al_nadheera_watermark.png');
      watermarkImage = pw.MemoryImage(wmBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final constBytes = await rootBundle.load('assets/images/footer_constellation.png');
      constellationImage = pw.MemoryImage(constBytes.buffer.asUint8List());
    } catch (_) {}

    // Extract margin parameters from Source Config
    final sourceCfg = invoice.sourceConfig ?? {};
    final customMarginTop = (sourceCfg['marginTop'] as num?)?.toDouble() ?? 0.0;
    final customMarginLeft = (sourceCfg['marginLeft'] as num?)?.toDouble() ?? 0.0;
    final customMarginRight = (sourceCfg['marginRight'] as num?)?.toDouble() ?? 0.0;
    final customMarginBottom = (sourceCfg['marginBottom'] as num?)?.toDouble() ?? 0.0;

    // Use default comfortable page margins (if 0 is set in form, use standard margins)
    final topMargin = customMarginTop > 0 ? customMarginTop : 25.0;
    final leftMargin = customMarginLeft > 0 ? customMarginLeft : 30.0;
    final rightMargin = customMarginRight > 0 ? customMarginRight : 30.0;
    final bottomMargin = customMarginBottom > 0 ? customMarginBottom : 18.0;

    final pageMargin = pw.EdgeInsets.only(
      top: topMargin,
      left: leftMargin,
      right: rightMargin,
      bottom: bottomMargin,
    );

    // Page format: Letter (default), A4, Legal
    PdfPageFormat format = PdfPageFormat.letter;
    final fmtStr = sourceCfg['pageFormat']?.toString().toUpperCase() ?? 'LETTER';
    if (fmtStr == 'A4') format = PdfPageFormat.a4;
    if (fmtStr == 'LETTER') format = PdfPageFormat.letter;
    if (fmtStr == 'LEGAL') format = PdfPageFormat.legal;

    final isLandscape = (sourceCfg['pageMode']?.toString().toUpperCase() ?? 'PORTRAIT') == 'LANDSCAPE';
    if (isLandscape) {
      format = format.landscape;
    }

    // Recipient address lines
    final recipientLines = <String>[];
    if (invoice.customerName.isNotEmpty) recipientLines.add(invoice.customerName);
    if (invoice.customerAddress != null && invoice.customerAddress!.isNotEmpty) {
      final parts = invoice.customerAddress!.split(RegExp(r'[,|\n]'));
      for (final p in parts) {
        final clean = p.trim();
        if (clean.isNotEmpty) recipientLines.add(clean.endsWith(',') ? clean : '$clean,');
      }
    }

    final subject = invoice.subject?.isNotEmpty == true
        ? invoice.subject!
        : (invoice.description?.isNotEmpty == true ? invoice.description! : '');

    final salutation = invoice.salutation?.isNotEmpty == true ? invoice.salutation! : 'Respected Sir,';

    final docType = (invoice.documentType != null && invoice.documentType!.isNotEmpty)
        ? invoice.documentType!
        : (sourceCfg['documentType']?.toString() ?? 'Quotation');
    final isQuotation = docType.trim().toLowerCase() == 'quotation';

    final introText = invoice.introText != null
        ? invoice.introText!
        : (isQuotation
            ? 'We with kind esteem would like to inform you that we confirm our committed intention to engage in your Project to provide the Project Management and Construction Management Services for the above mention project. Our organization is pleased to submit our best Competitive offer in conformity to the Specification and Drawing for an amount of BOQ Details Below.'
            : '');

    final tableHeaderTitle = invoice.tableHeaderTitle?.isNotEmpty == true
        ? invoice.tableHeaderTitle!
        : (invoice.description?.isNotEmpty == true ? invoice.description! : '');

    final vatPercentage = invoice.vatRate > 0 ? invoice.vatRate : 10.0;
    final amountInWords = CurrencyWordsConverter.toBahrainiDinarsWords(invoice.totalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          margin: pageMargin,
          theme: pw.ThemeData.withFont(
            base: baseFont,
            bold: boldFont,
            fontFallback: [if (arabicFont != null) arabicFont],
          ),
          buildBackground: (pw.Context context) {
            if (watermarkImage == null) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: false,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.10,
                  child: pw.Image(watermarkImage, width: 260),
                ),
              ),
            );
          },
        ),
        footer: (pw.Context context) {
          return _buildExactFooter(constellationImage, template);
        },
        build: (pw.Context context) {
          return [
            // ==================== HEADER BRANDING ====================
            pw.Center(
              child: headerImage != null
                  ? pw.Image(headerImage, height: 72, fit: pw.BoxFit.contain)
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (emblemImage != null)
                          pw.Image(emblemImage, height: 46, fit: pw.BoxFit.contain),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'AL NADHEERA CONTRACTING CO. W.L.L',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#C51A1B'),
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'شركة النضيرة للمقاولات ذ.م.م',
                          textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                            font: arabicFont,
                            color: PdfColors.black,
                            fontSize: 12.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),

            pw.SizedBox(height: 10),

            // ==================== DATE & QUOTATION NO ROW ====================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Quotation No: ${invoice.invoiceNumber}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(invoice.date)}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // ==================== RECIPIENT BLOCK ("To:") ====================
            pw.Text('To:', style: const pw.TextStyle(fontSize: 9.5)),
            for (final line in recipientLines)
              pw.Text(line, style: const pw.TextStyle(fontSize: 9.5)),

            pw.SizedBox(height: 10),

            // ==================== SUBJECT ====================
            if (subject.isNotEmpty) ...[
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'SUBJECT: ',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.TextSpan(
                      text: subject,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],

            // ==================== SALUTATION & BODY ====================
            pw.Text(
              salutation,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            if (introText.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                introText,
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),
            ] else ...[
              pw.SizedBox(height: 6),
            ],

            // ==================== TABLE SUB-HEADER TITLE ====================
            if (tableHeaderTitle.isNotEmpty) ...[
              pw.Center(
                child: pw.Text(
                  tableHeaderTitle,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
            ],

            // ==================== BOQ ITEMS TABLE ====================
            _buildBoqTable(invoice, vatPercentage),

            pw.SizedBox(height: 10),

            // ==================== TOTAL IN WORDS ====================
            pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9),
                children: [
                  const pw.TextSpan(text: 'Our total price shall be '),
                  pw.TextSpan(
                    text: 'BHD ${formatAmount(invoice.totalAmount, forceThreeDecimals: true)} ',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.TextSpan(
                    text: '($amountInWords)',
                    style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ),

            // ==================== SEAL & SIGNATURE AREA ====================
            if (effectiveShowSealSignature) ...[
              pw.SizedBox(height: 12),
              _buildPhysicalSealAndSignatureArea(boldFont, baseFont),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Builds the physical seal and signature box matching the official document format
  /// Left Box: "Customer's Seal and Signature"
  /// Right Box: "FOR : AL NADHEERA CONTRACTING CO WLL" at top, "Authorised Signatory" at bottom-right
  static pw.Widget _buildPhysicalSealAndSignatureArea(
    pw.Font? boldFont,
    pw.Font? baseFont,
  ) {
    const double boxHeight = 85.0;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            // Left Box: Customer's Seal and Signature
            pw.Container(
              height: boxHeight,
              padding: const pw.EdgeInsets.all(6),
              child: pw.Align(
                alignment: pw.Alignment.topLeft,
                child: pw.Text(
                  "Customer's Seal and Signature",
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Right Box: Company Header + Authorised Signatory Footer
            pw.Container(
              height: boxHeight,
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FOR : AL NADHEERA CONTRACTING CO WLL',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Text(
                      'Authorised Signatory',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the BOQ Items Table with CLASS, Description, Total Amount and Totals
  static pw.Widget _buildBoqTable(Invoice invoice, double vatPercentage) {
    final items = invoice.items;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(48), // CLASS
        1: pw.FlexColumnWidth(5),   // Description
        2: pw.FixedColumnWidth(110), // Total Amount
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _cell('CLASS', isHeader: true, align: pw.TextAlign.left),
            _cell('Description', isHeader: true, align: pw.TextAlign.left),
            _cell('Total Amount', isHeader: true, align: pw.TextAlign.left),
          ],
        ),

        // Line Items entered by the user (NO fake dummy items injected!)
        for (int i = 0; i < items.length; i++) ...[
          pw.TableRow(
            children: [
              _cell(items[i].itemClass?.isNotEmpty == true ? items[i].itemClass! : '${i + 1}'),
              _cell(items[i].itemDescription),
              _cell(formatAmount(items[i].amount), align: pw.TextAlign.left),
            ],
          ),
        ],

        // Summary Row 1: Total (Subtotal)
        pw.TableRow(
          children: [
            _cell('Total', isBold: true),
            _cell(''),
            _cell(formatAmount(invoice.subtotal), isBold: true, align: pw.TextAlign.left),
          ],
        ),

        // Summary Row 2: VAT
        pw.TableRow(
          children: [
            _cell('VAT ${vatPercentage.toStringAsFixed(0)}%', isBold: true),
            _cell(''),
            _cell(
              formatAmount(invoice.vatAmount, forceThreeDecimals: true),
              isBold: true,
              align: pw.TextAlign.left,
            ),
          ],
        ),

        // Summary Row 3: Total Amount of Work
        pw.TableRow(
          children: [
            _cell('Total Amount of Work', isBold: true),
            _cell(''),
            _cell(
              formatAmount(invoice.totalAmount, forceThreeDecimals: true),
              isBold: true,
              align: pw.TextAlign.left,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8.5,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Builds the exact footer with contact icons, address, and red accent bar
  /// Sized at height 46 so it is fully visible above page margins without clipping or overlap
  static pw.Widget _buildExactFooter(pw.MemoryImage? constellation, DocumentTemplate template) {
    return pw.Container(
      height: 46,
      margin: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Constellation Graphic on Left
          if (constellation != null)
            pw.Container(
              width: 58,
              height: 42,
              child: pw.Image(constellation, fit: pw.BoxFit.contain),
            )
          else
            pw.SizedBox(width: 58),

          pw.SizedBox(width: 10),

          // Middle Contact Columns
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Phone & Email Block
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            margin: const pw.EdgeInsets.only(right: 4),
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                canvas.setColor(PdfColors.black);
                                canvas.setFillColor(PdfColors.black);
                                canvas.moveTo(1.2, 6.0);
                                canvas.lineTo(2.5, 7.3);
                                canvas.lineTo(4.0, 5.8);
                                canvas.lineTo(3.2, 5.0);
                                canvas.curveTo(3.5, 4.1, 4.1, 3.5, 5.0, 3.2);
                                canvas.lineTo(5.8, 4.0);
                                canvas.lineTo(7.3, 2.5);
                                canvas.lineTo(6.0, 1.2);
                                canvas.curveTo(3.6, 1.2, 1.2, 3.6, 1.2, 6.0);
                                canvas.fillPath();
                              },
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Office Number: +973 77900685', style: const pw.TextStyle(fontSize: 6.8)),
                                pw.Text('Mobile Number: +973 33880685', style: const pw.TextStyle(fontSize: 6.8)),
                                pw.Text('WhatsApp Number: +973 33667136', style: const pw.TextStyle(fontSize: 6.8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 6.5,
                            margin: const pw.EdgeInsets.only(right: 4),
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                canvas.setColor(PdfColors.black);
                                canvas.setLineWidth(0.6);
                                canvas.drawRect(0, 0, size.x, size.y);
                                canvas.moveTo(0, size.y);
                                canvas.lineTo(size.x / 2, size.y * 0.35);
                                canvas.lineTo(size.x, size.y);
                                canvas.strokePath();
                              },
                            ),
                          ),
                          pw.Text('anccwll@gmail.com', style: const pw.TextStyle(fontSize: 6.8)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 8),

                // Company Address & Web Block
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'AL Nadheera Contracting CO. W.L.L',
                        style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 7,
                            height: 9,
                            margin: const pw.EdgeInsets.only(top: 1, right: 4),
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                canvas.setColor(PdfColors.black);
                                canvas.setFillColor(PdfColors.black);
                                canvas.moveTo(size.x / 2, 0);
                                canvas.curveTo(1, 3, 0, 5, size.x / 2, size.y);
                                canvas.curveTo(size.x, 5, size.x - 1, 3, size.x / 2, 0);
                                canvas.fillPath();
                                canvas.setFillColor(PdfColors.white);
                                canvas.drawEllipse(size.x / 2, size.y * 0.65, 1.2, 1.2);
                                canvas.fillPath();
                              },
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              '22, Building: 23, Road 3901, Riffa / Al Hajiyat 0939\nSouthern Governorate, Kingdom of Bahrain',
                              style: const pw.TextStyle(fontSize: 6.8),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            margin: const pw.EdgeInsets.only(right: 4),
                            child: pw.CustomPaint(
                              painter: (PdfGraphics canvas, PdfPoint size) {
                                canvas.setColor(PdfColors.black);
                                canvas.setLineWidth(0.6);
                                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
                                canvas.moveTo(0, size.y / 2);
                                canvas.lineTo(size.x, size.y / 2);
                                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 4, size.y / 2);
                                canvas.strokePath();
                              },
                            ),
                          ),
                          pw.Text('www.alnadheera.com', style: const pw.TextStyle(fontSize: 6.8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 8),

          // Far-Right Dark Red Vertical Bar
          pw.Container(
            width: 8,
            height: 38,
            color: PdfColor.fromHex('#7B0D14'),
          ),
        ],
      ),
    );
  }
}
