import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  static String _formatDec(double? val) {
    if (val == null || val == 0.0) return '-';
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
                      decoration: item.isHighlighted
                          ? pw.BoxDecoration(
                              color: PdfColor.fromHex(item.highlightColorHex),
                            )
                          : null,
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

    // If document contains material deduction items, append dedicated landscape Material Deduction Sheet
    if (document.hasDeductions) {
      _addMaterialDeductionPage(pdf, document, regularFont, boldFont);
    }

    return pdf.save();
  }

  static void _addMaterialDeductionPage(
    pw.Document pdf,
    IpcDocument document,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    const table1Widths = {
      0: pw.FixedColumnWidth(36), // Item No.
      1: pw.FlexColumnWidth(1.0), // Item Description
      2: pw.FixedColumnWidth(34), // Unit
      3: pw.FixedColumnWidth(55), // CONTRACT
      4: pw.FixedColumnWidth(116), // PREVIOUS (52 + 64)
      5: pw.FixedColumnWidth(116), // THIS PERIOD (52 + 64)
      6: pw.FixedColumnWidth(116), // CUMULATIVE (52 + 64)
      7: pw.FixedColumnWidth(64), // as per site
    };

    const colWidths = {
      0: pw.FixedColumnWidth(36), // Item No.
      1: pw.FlexColumnWidth(1.0), // Item Description
      2: pw.FixedColumnWidth(34), // Unit
      3: pw.FixedColumnWidth(55), // CONTRACT Rate
      4: pw.FixedColumnWidth(52), // PREVIOUS Quantity
      5: pw.FixedColumnWidth(64), // PREVIOUS Amount BD
      6: pw.FixedColumnWidth(52), // THIS PERIOD Quantity
      7: pw.FixedColumnWidth(64), // THIS PERIOD Amount BD
      8: pw.FixedColumnWidth(52), // CUMULATIVE Quantity
      9: pw.FixedColumnWidth(64), // CUMULATIVE Amount BD
      10: pw.FixedColumnWidth(64), // as per site
    };

    pw.Widget buildTopHeader() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              document.projectName.toUpperCase(),
              style: pw.TextStyle(font: boldFont, fontSize: 10, letterSpacing: 0.3),
              textAlign: pw.TextAlign.center,
            ),
            if (document.mainContractor.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'MAIN CONTRACTOR : ${document.mainContractor.trim().toUpperCase()}',
                style: pw.TextStyle(font: boldFont, fontSize: 8.5),
                textAlign: pw.TextAlign.center,
              ),
            ],
            if (document.subContractor.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'SUB CONTRACTOR : ${document.subContractor.trim().toUpperCase()}',
                style: pw.TextStyle(font: boldFont, fontSize: 8.5),
                textAlign: pw.TextAlign.center,
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'IPA # ${document.documentNumber} Until ${DateFormat('dd/MM/yyyy').format(document.date)}',
                style: pw.TextStyle(font: boldFont, fontSize: 8.5),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildTableHeader() {
      const headerBg = PdfColor.fromInt(0xFFFDE8D7); // Peach/tan tint matching sample image
      return pw.Column(
        children: [
          // Table 1: Top Header Row (8 columns)
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: PdfColors.black, width: 0.8),
              left: pw.BorderSide(color: PdfColors.black, width: 0.8),
              right: pw.BorderSide(color: PdfColors.black, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
            columnWidths: table1Widths,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('Item No.', style: pw.TextStyle(font: boldFont, fontSize: 7.5)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('Item Description', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('Unit', style: pw.TextStyle(font: boldFont, fontSize: 8)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('CONTRACT', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('PREVIOUS', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('THIS PERIOD', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('CUMULATIVE', style: pw.TextStyle(font: boldFont, fontSize: 7)),
                  ),
                  pw.Container(
                    height: 18,
                    alignment: pw.Alignment.center,
                    child: pw.Text('as per site', style: pw.TextStyle(font: boldFont, fontSize: 7.5)),
                  ),
                ],
              ),
            ],
          ),

          // Table 2: Subheader Row (11 columns)
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide.none,
              left: pw.BorderSide(color: PdfColors.black, width: 0.8),
              right: pw.BorderSide(color: PdfColors.black, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
            columnWidths: colWidths,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(font: boldFont, fontSize: 7))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(font: boldFont, fontSize: 7))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(font: boldFont, fontSize: 7))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Rate', style: pw.TextStyle(font: boldFont, fontSize: 7))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Quantity', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Amount BD', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Quantity', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Amount BD', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Quantity', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('Amount BD', style: pw.TextStyle(font: boldFont, fontSize: 6.5))),
                  pw.Container(height: 14, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(font: boldFont, fontSize: 7))),
                ],
              ),
            ],
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        header: (context) => pw.Column(
          children: [
            buildTopHeader(),
            buildTableHeader(),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide.none,
              left: pw.BorderSide(color: PdfColors.black, width: 0.8),
              right: pw.BorderSide(color: PdfColors.black, width: 0.8),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
              horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
              verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
            columnWidths: colWidths,
            children: [
              for (final r in document.deductions)
                pw.TableRow(
                  decoration: r.isHighlighted
                      ? pw.BoxDecoration(color: PdfColor.fromHex(r.highlightColorHex))
                      : null,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(r.itemNumber ?? '', style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(r.description, style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
                      child: pw.Text(r.unit ?? '', style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.contractRate), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.previousQuantity), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.previousAmount), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.thisPeriodQuantity), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.thisPeriodAmount), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.cumulativeQuantity), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerRight,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(_formatDec(r.cumulativeAmount), style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
                      child: pw.Text(r.remarks ?? '', style: pw.TextStyle(font: regularFont, fontSize: 7.5)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmptyCell() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(''),
    );
  }

  /// Opens a full-screen, high-fidelity PDF preview modal with Print & Share actions
  static Future<void> showPreview(BuildContext context, IpcDocument document) async {
    final pdfBytes = await generatePdf(document);
    if (!context.mounted) return;

    final fileName = '${document.documentNumber.isNotEmpty ? document.documentNumber : "IPC"}_Measurement_Bill.pdf';

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              '${document.documentNumber.isNotEmpty ? document.documentNumber : "IPC Bill"} - Preview',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            backgroundColor: const Color(0xFF0A2540),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share PDF',
                onPressed: () => Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: fileName,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded),
                tooltip: 'Print',
                onPressed: () => Printing.layoutPdf(
                  onLayout: (_) async => pdfBytes,
                  name: fileName,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => pdfBytes,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: fileName,
          ),
        ),
      ),
    );
  }
}
