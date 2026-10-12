import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    final config = template.layoutConfig;

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

    // Load Unicode fonts (Roboto) and Arabic font (Cairo) for complete Unicode & Arabic support
    pw.Font? baseFont;
    pw.Font? boldFont;
    pw.Font? arabicFont;

    try {
      baseFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {}

    if (template.companyNameAr != null && template.companyNameAr!.trim().isNotEmpty) {
      try {
        arabicFont = await PdfGoogleFonts.cairoBold();
      } catch (_) {
        try {
          arabicFont = await PdfGoogleFonts.amiriBold();
        } catch (_) {}
      }
    }

    // Determine page margins from layout config
    pw.EdgeInsets pageMargin;
    switch (config.pageMargin) {
      case 'compact':
        pageMargin = const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18);
        break;
      case 'spacious':
        pageMargin = const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 38);
        break;
      case 'standard':
      default:
        pageMargin = const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28);
        break;
    }

    // Determine logo dimensions
    double logoSize = 50;
    switch (config.logoSize) {
      case 'small':
        logoSize = 36;
        break;
      case 'large':
        logoSize = 66;
        break;
      case 'medium':
      default:
        logoSize = 50;
        break;
    }

    final isPending = !isPaid;
    final showLogo = (config.logoPosition != 'none') && (!isPending || config.showLogoWhenPending);
    final shouldShowSeal = template.showSeal && (!isPending || config.showSealWhenPending);
    final shouldShowSignature = template.showSignature && (!isPending || config.showSignatureWhenPending);

    // Helper widget for Logo
    pw.Widget buildLogoWidget({double size = 50, bool isInBanner = false}) {
      if (!showLogo) return pw.SizedBox.shrink();
      if (logoImage != null) {
        return pw.Container(
          width: size,
          height: size,
          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
        );
      }
      return pw.Container(
        width: size * 0.84,
        height: size * 0.84,
        decoration: pw.BoxDecoration(
          color: isInBanner ? PdfColors.white : primaryColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Center(
          child: pw.Text(
            template.companyNameEn.isNotEmpty
                ? template.companyNameEn.substring(0, 2).toUpperCase()
                : 'AN',
            style: pw.TextStyle(
              color: isInBanner ? primaryColor : PdfColors.white,
              fontSize: size * 0.36,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Helper widget for Company Branding Block
    pw.Widget buildCompanyBranding({
      pw.CrossAxisAlignment align = pw.CrossAxisAlignment.start,
      bool isWhiteText = false,
      bool isCentered = false,
    }) {
      final titleColor = isWhiteText ? PdfColors.white : primaryColor;
      final subColor = isWhiteText ? PdfColor.fromHex('#E2E8F0') : PdfColors.grey700;

      return pw.Column(
        crossAxisAlignment: align,
        children: [
          pw.Text(
            template.companyNameEn,
            textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
              color: titleColor,
              fontSize: isCentered ? 17 : 15,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          if (template.companyNameAr != null &&
              template.companyNameAr!.trim().isNotEmpty &&
              arabicFont != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              template.companyNameAr!,
              textDirection: pw.TextDirection.rtl,
              textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                font: arabicFont,
                color: titleColor,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
          if (template.tagline != null && template.tagline!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              template.tagline!,
              textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                color: subColor,
                fontSize: 8.5,
              ),
            ),
          ],
        ],
      );
    }

    // Helper widget for Invoice Title & Status Stamp Badge
    pw.Widget buildInvoiceTitleAndStamp({
      pw.CrossAxisAlignment align = pw.CrossAxisAlignment.end,
      bool isWhiteText = false,
      bool isCentered = false,
    }) {
      final titleColor = isWhiteText ? PdfColors.white : primaryColor;
      final numberColor = isWhiteText ? PdfColor.fromHex('#93C5FD') : accentColor;

      return pw.Column(
        crossAxisAlignment: align,
        children: [
          pw.Text(
            'TAX INVOICE',
            textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            invoice.invoiceNumber,
            textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
            style: pw.TextStyle(
              color: numberColor,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: pw.BoxDecoration(
              color: isPaid ? PdfColor.fromHex('#E6F4EA') : PdfColor.fromHex('#FCE8E6'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(
                color: isPaid ? paidColor : pendingColor,
                width: 1.5,
              ),
            ),
            child: pw.Text(
              isPaid ? 'PAID' : 'PENDING PAYMENT',
              style: pw.TextStyle(
                color: isPaid ? paidColor : pendingColor,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      );
    }

    // Helper widget for Contact Details row/strip
    pw.Widget buildContactDetailsStrip({bool isCentered = false}) {
      return pw.Column(
        crossAxisAlignment: isCentered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _cleanText('${template.address} | CR: ${template.crNumber ?? "N/A"} | VAT: ${template.vatNumber ?? "N/A"}'),
            textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _cleanText('Phone: ${template.phone} | Email: ${template.email}${template.website != null ? " | Web: ${template.website}" : ""}'),
            textAlign: isCentered ? pw.TextAlign.center : pw.TextAlign.left,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      );
    }

    // Helper for Bill To Container
    pw.Widget buildBillToBox() {
      pw.BoxDecoration boxDecor;
      switch (config.billToStyle) {
        case 'accent_border':
          boxDecor = pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border(
              left: pw.BorderSide(color: primaryColor, width: 4),
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              right: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          );
          break;
        case 'clean':
          boxDecor = const pw.BoxDecoration(color: PdfColors.white);
          break;
        case 'card':
        default:
          boxDecor = pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.grey200),
          );
          break;
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: boxDecor,
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
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
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
      );
    }

    // Helper for Invoice Details Metadata Box
    pw.Widget buildInvoiceDetailsBox() {
      return pw.Container(
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
      );
    }

    // Helper for Bank Transfer Information
    pw.Widget buildBankDetailsBlock() {
      if (!template.showBankDetails || template.bankName == null || template.bankName!.isEmpty) {
        return pw.SizedBox.shrink();
      }
      return pw.Container(
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
      );
    }

    // Helper for Summary Calculation Breakdown
    pw.Widget buildTotalsSummaryBlock() {
      return pw.Container(
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
          ],
        ),
      );
    }

    // Helper for Seal Stamp Block
    pw.Widget buildSealWidget() {
      if (!shouldShowSeal) return pw.SizedBox.shrink();
      if (sealImage != null) {
        return pw.Container(
          width: 72,
          height: 72,
          child: pw.Image(sealImage, fit: pw.BoxFit.contain),
        );
      }
      return pw.Container(
        width: 72,
        height: 72,
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
      );
    }

    // Helper for Signature Block
    pw.Widget buildSignatureWidget() {
      if (!shouldShowSignature) return pw.SizedBox.shrink();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (signatureImage != null)
            pw.Container(
              height: 38,
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            )
          else
            pw.SizedBox(height: 22),
          pw.Container(height: 1, width: 140, color: PdfColors.grey500),
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
      );
    }

    // Density padding for table cells
    double tablePadH = 6;
    double tablePadV = 5;
    if (config.tableDensity == 'compact') {
      tablePadH = 4;
      tablePadV = 3;
    } else if (config.tableDensity == 'spacious') {
      tablePadH = 8;
      tablePadV = 8;
    }

    // Table header appearance
    pw.BoxDecoration tableHeaderDecor;
    PdfColor tableHeaderTextColor;
    switch (config.tableHeaderStyle) {
      case 'tinted':
        tableHeaderDecor = pw.BoxDecoration(
          color: PdfColor.fromHex('#EEF2F6'),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        );
        tableHeaderTextColor = primaryColor;
        break;
      case 'minimal':
        tableHeaderDecor = pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border(
            top: pw.BorderSide(color: primaryColor, width: 1.5),
            bottom: pw.BorderSide(color: primaryColor, width: 1.5),
          ),
        );
        tableHeaderTextColor = primaryColor;
        break;
      case 'primary_filled':
      default:
        tableHeaderDecor = pw.BoxDecoration(color: primaryColor);
        tableHeaderTextColor = PdfColors.white;
        break;
    }

    // Add Document Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pageMargin,
        theme: (baseFont != null && boldFont != null)
            ? pw.ThemeData.withFont(
                base: baseFont,
                bold: boldFont,
                fontFallback: [if (arabicFont != null) arabicFont],
              )
            : null,
        header: (pw.Context context) {
          // ==================== HEADER SECTION ====================
          pw.Widget headerContent;

          if (config.headerLayout == 'centered') {
            // Centered Header
            headerContent = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (showLogo) ...[
                  buildLogoWidget(size: logoSize, isInBanner: false),
                  pw.SizedBox(height: 6),
                ],
                buildCompanyBranding(align: pw.CrossAxisAlignment.center, isCentered: true),
                pw.SizedBox(height: 6),
                buildContactDetailsStrip(isCentered: true),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1, color: primaryColor),
                pw.SizedBox(height: 6),
                buildInvoiceTitleAndStamp(align: pw.CrossAxisAlignment.center, isCentered: true),
              ],
            );
          } else if (config.headerLayout == 'reversed') {
            // Reversed Header (Invoice details on Left, Company branding on Right)
            headerContent = pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildInvoiceTitleAndStamp(align: pw.CrossAxisAlignment.start),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Expanded(
                            child: buildCompanyBranding(align: pw.CrossAxisAlignment.end),
                          ),
                          if (showLogo) ...[
                            pw.SizedBox(width: 12),
                            buildLogoWidget(size: logoSize),
                          ],
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      buildContactDetailsStrip(isCentered: false),
                    ],
                  ),
                ),
              ],
            );
          } else if (config.headerLayout == 'minimal_bar') {
            // Minimalist Accent Bar Header
            headerContent = pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          if (showLogo) ...[
                            buildLogoWidget(size: logoSize * 0.85, isInBanner: true),
                            pw.SizedBox(width: 10),
                          ],
                          buildCompanyBranding(isWhiteText: true),
                        ],
                      ),
                      buildInvoiceTitleAndStamp(align: pw.CrossAxisAlignment.end, isWhiteText: true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                buildContactDetailsStrip(isCentered: false),
              ],
            );
          } else {
            // Modern Split (Default)
            headerContent = pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (showLogo) ...[
                            buildLogoWidget(size: logoSize),
                            pw.SizedBox(width: 12),
                          ],
                          pw.Expanded(
                            child: buildCompanyBranding(),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      buildContactDetailsStrip(isCentered: false),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                buildInvoiceTitleAndStamp(align: pw.CrossAxisAlignment.end),
              ],
            );
          }

          // ==================== METADATA & BILL TO SECTION ====================
          pw.Widget metaContent;

          if (config.metaLayout == 'reversed_split') {
            // Swapped: Details Left, Bill To Right
            metaContent = pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 5, child: buildInvoiceDetailsBox()),
                pw.SizedBox(width: 14),
                pw.Expanded(flex: 6, child: buildBillToBox()),
              ],
            );
          } else if (config.metaLayout == 'stacked') {
            // Stacked: Bill To full width, details below
            metaContent = pw.Column(
              children: [
                buildBillToBox(),
                pw.SizedBox(height: 8),
                buildInvoiceDetailsBox(),
              ],
            );
          } else {
            // Split (Default): Bill To Left, Details Right
            metaContent = pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 6, child: buildBillToBox()),
                pw.SizedBox(width: 14),
                pw.Expanded(flex: 5, child: buildInvoiceDetailsBox()),
              ],
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              headerContent,
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              metaContent,
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
          // ==================== FOOTER SECTION ====================
          pw.Widget footerInner;
          final footerText = _cleanText(template.footerText ?? 'Al Nadheera Contracting W.L.L. | Kingdom of Bahrain');
          final pageText = 'Page ${context.pageNumber} of ${context.pagesCount}';

          if (config.footerAlignment == 'center') {
            footerInner = pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(footerText, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(pageText, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
                ],
              ),
            );
          } else if (config.footerAlignment == 'left') {
            footerInner = pw.Row(
              children: [
                pw.Text('$footerText   |   $pageText', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            );
          } else {
            // Split (Default)
            footerInner = pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(footerText, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text(pageText, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            );
          }

          return pw.Column(
            children: [
              if (config.footerDivider) ...[
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
              ],
              footerInner,
            ],
          );
        },
        build: (pw.Context context) {
          final items = invoice.items;

          // ==================== SIGNATURES & STAMP BLOCK ====================
          pw.Widget buildSignatureAndSealRow() {
            if (!shouldShowSeal && !shouldShowSignature) {
              return pw.SizedBox.shrink();
            }

            if (config.signaturesLayout == 'right') {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (shouldShowSeal) buildSealWidget(),
                  if (shouldShowSeal && shouldShowSignature) pw.SizedBox(width: 14),
                  if (shouldShowSignature) buildSignatureWidget(),
                ],
              );
            } else if (config.signaturesLayout == 'center') {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (shouldShowSeal) buildSealWidget(),
                  if (shouldShowSeal && shouldShowSignature) pw.SizedBox(width: 20),
                  if (shouldShowSignature) buildSignatureWidget(),
                ],
              );
            } else if (config.signaturesLayout == 'left') {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (shouldShowSeal) buildSealWidget(),
                  if (shouldShowSeal && shouldShowSignature) pw.SizedBox(width: 14),
                  if (shouldShowSignature) buildSignatureWidget(),
                ],
              );
            } else {
              // Split (Default): Signature on Left, Seal on Right
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (shouldShowSignature) buildSignatureWidget(),
                  if (shouldShowSeal) buildSealWidget(),
                ],
              );
            }
          }

          return [
            // ==================== ITEMS TABLE ====================
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
                  decoration: tableHeaderDecor,
                  children: [
                    _buildCustomTableCell('#', isHeader: true, align: pw.TextAlign.center, textColor: tableHeaderTextColor, padH: tablePadH, padV: tablePadV),
                    _buildCustomTableCell('Item / Service Description', isHeader: true, textColor: tableHeaderTextColor, padH: tablePadH, padV: tablePadV),
                    _buildCustomTableCell('Qty', isHeader: true, align: pw.TextAlign.center, textColor: tableHeaderTextColor, padH: tablePadH, padV: tablePadV),
                    _buildCustomTableCell('Unit Price', isHeader: true, align: pw.TextAlign.right, textColor: tableHeaderTextColor, padH: tablePadH, padV: tablePadV),
                    _buildCustomTableCell('Total (BHD)', isHeader: true, align: pw.TextAlign.right, textColor: tableHeaderTextColor, padH: tablePadH, padV: tablePadV),
                  ],
                ),
                // Data Rows
                for (int i = 0; i < items.length; i++) ...[
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: config.tableZebraStripes
                          ? (i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC'))
                          : PdfColors.white,
                    ),
                    children: [
                      _buildCustomTableCell('${i + 1}', align: pw.TextAlign.center, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(items[i].itemDescription, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(
                        items[i].quantity % 1 == 0
                            ? items[i].quantity.toInt().toString()
                            : items[i].quantity.toStringAsFixed(2),
                        align: pw.TextAlign.center,
                        padH: tablePadH,
                        padV: tablePadV,
                      ),
                      _buildCustomTableCell(cf.format(items[i].unitPrice), align: pw.TextAlign.right, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(cf.format(items[i].amount), align: pw.TextAlign.right, isBold: true, padH: tablePadH, padV: tablePadV),
                    ],
                  ),
                ],
                if (items.isEmpty)
                  pw.TableRow(
                    children: [
                      _buildCustomTableCell('-', align: pw.TextAlign.center, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(invoice.description ?? 'General Contracting Services', padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell('1', align: pw.TextAlign.center, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(cf.format(invoice.subtotal), align: pw.TextAlign.right, padH: tablePadH, padV: tablePadV),
                      _buildCustomTableCell(cf.format(invoice.subtotal), align: pw.TextAlign.right, isBold: true, padH: tablePadH, padV: tablePadV),
                    ],
                  ),
              ],
            ),

            pw.SizedBox(height: 14),

            // ==================== TOTALS & SUMMARY LAYOUT ====================
            if (config.totalsPosition == 'full_width') ...[
              // Full-width totals bar
              buildTotalsSummaryBlock(),
              pw.SizedBox(height: 12),
              if (config.bankDetailsLayout == 'full_width') ...[
                buildBankDetailsBlock(),
                pw.SizedBox(height: 12),
              ],
              buildSignatureAndSealRow(),
            ] else if (config.totalsPosition == 'left') ...[
              // Totals on Left, Notes & Bank on Right
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 5, child: buildTotalsSummaryBlock()),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                          pw.Text('Notes & Instructions:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.SizedBox(height: 2),
                          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 8),
                        ],
                        buildBankDetailsBlock(),
                        pw.SizedBox(height: 10),
                        buildSignatureAndSealRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Totals on Right (Default)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                          pw.Text('Notes & Instructions:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.SizedBox(height: 2),
                          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.SizedBox(height: 8),
                        ],
                        if (config.bankDetailsLayout != 'full_width') ...[
                          buildBankDetailsBlock(),
                          pw.SizedBox(height: 12),
                        ],
                        buildSignatureAndSealRow(),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 5, child: buildTotalsSummaryBlock()),
                ],
              ),
              if (config.bankDetailsLayout == 'full_width') ...[
                pw.SizedBox(height: 12),
                buildBankDetailsBlock(),
              ],
            ],
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

  static pw.Widget _buildCustomTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? textColor,
    double padH = 6,
    double padV = 5,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: textColor ?? (isHeader ? PdfColors.white : PdfColors.black),
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

  static String _cleanText(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('•', ' | ')
        .replaceAll('·', ' | ')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }
}
