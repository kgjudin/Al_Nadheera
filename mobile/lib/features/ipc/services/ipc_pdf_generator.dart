import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../models/ipc_model.dart';

class IpcPdfGenerator {
  static final NumberFormat _numFormat = NumberFormat('#,##0.000');

  static String _formatNumber(double val) {
    if (val == 0.0) return '-';
    return _numFormat.format(val);
  }

  static String _formatQty(double val) {
    if (val == 0.0) return '-';
    return _numFormat.format(val);
  }

  static Future<Uint8List> generatePdf(IpcDocument document) async {
    final pdf = pw.Document();

    // Fonts setup with safe fallback to standard PDF Helvetica
    pw.Font regularFont;
    pw.Font boldFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      regularFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    final projectName = document.projectName.toUpperCase().startsWith('PROJECT:')
        ? document.projectName.toUpperCase()
        : 'PROJECT: ${document.projectName.toUpperCase()}';

    // Calculate total if not set
    document.calculateTotal();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (pw.Context context) {
          return [
            // Top Project Box Table (Spanning Item + Description + unit + quantity)
            pw.Table(
              border: const pw.TableBorder(
                top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),    // Spans across Item, Description, unit, quantity
                1: pw.FixedColumnWidth(65),  // rate
                2: pw.FixedColumnWidth(85),  // Amount
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      child: pw.Text(
                        projectName,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 9.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    _buildEmptyCell(),
                    _buildEmptyCell(),
                  ],
                ),
              ],
            ),

            // Main Data Table
            pw.Table(
              border: const pw.TableBorder(
                top: pw.BorderSide.none,
                left: pw.BorderSide(color: PdfColors.black, width: 0.8),
                right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(40),  // Item
                1: pw.FlexColumnWidth(1),    // Description
                2: pw.FixedColumnWidth(35),  // unit
                3: pw.FixedColumnWidth(65),  // quantity
                4: pw.FixedColumnWidth(65),  // rate
                5: pw.FixedColumnWidth(85),  // Amount
              },
              children: [
                // Row 1: Table Column Headers (Item | Description | unit | quantity | rate | Amount)
                pw.TableRow(
                  repeat: true,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('Item', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('Description', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('unit', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('quantity', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('rate', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text('Amount', style: pw.TextStyle(font: regularFont, fontSize: 9.5)),
                    ),
                  ],
                ),

                // Data Rows
                for (final item in document.items)
                  if (item.isHeading)
                    // Class heading row (e.g. CLASS I : PIPEWORK-PIPES)
                    pw.TableRow(
                      children: [
                        _buildEmptyCell(),
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 9.5,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                        ),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                      ],
                    )
                  else if (item.isSubheading)
                    // Subheading row (e.g. Clause 3.3 ... or Nominal bore 150mm)
                    pw.TableRow(
                      children: [
                        _buildEmptyCell(),
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 9,
                              decoration: (item.description.toLowerCase().contains('clause') ||
                                      item.description.toLowerCase().contains('specification'))
                                  ? pw.TextDecoration.underline
                                  : pw.TextDecoration.none,
                            ),
                          ),
                        ),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                        _buildEmptyCell(),
                      ],
                    )
                  else
                    // Regular specification item line
                    pw.TableRow(
                      children: [
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            item.itemNumber ?? '',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            item.unit ?? '',
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            _formatQty(item.quantity),
                            style: pw.TextStyle(font: boldFont, fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            _formatNumber(item.rate),
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: pw.Text(
                            _formatNumber(item.amount),
                            style: pw.TextStyle(font: regularFont, fontSize: 9),
                          ),
                        ),
                      ],
                    ),

                // Total Summary Row
                pw.TableRow(
                  children: [
                    _buildEmptyCell(),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: pw.Text(
                        'TOTAL AMOUNT (BHD)',
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                    ),
                    _buildEmptyCell(),
                    _buildEmptyCell(),
                    _buildEmptyCell(),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: pw.Text(
                        _formatNumber(document.totalAmount),
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEmptyCell() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(''),
    );
  }
}
