import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../models/site_budget_transaction_model.dart';
import '../../models/site_model.dart';
import '../../services/site_budget_service.dart';
import '../../services/document_template_service.dart';

class SiteBudgetHistoryDialog extends StatefulWidget {
  final Site site;

  const SiteBudgetHistoryDialog({super.key, required this.site});

  @override
  State<SiteBudgetHistoryDialog> createState() => _SiteBudgetHistoryDialogState();
}

class _SiteBudgetHistoryDialogState extends State<SiteBudgetHistoryDialog> {
  final SiteBudgetService _budgetService = SiteBudgetService();
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 2);
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  late Future<List<SiteBudgetTransaction>> _transactionsFuture;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _transactionsFuture = _budgetService.getTransactions(siteId: widget.site.id);
    });
  }

  Future<void> _exportPdfReport(List<SiteBudgetTransaction> transactions) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final docTemplateService = DocumentTemplateService.instance;
      if (docTemplateService.templates.isEmpty) {
        await docTemplateService.loadTemplates();
      }
      final tmpl = docTemplateService.getTemplate('quotation');

      final pdf = pw.Document();

      pw.MemoryImage? logoImage;
      if (tmpl.logoUrl != null && tmpl.logoUrl!.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(tmpl.logoUrl!));
          if (res.statusCode == 200) {
            logoImage = pw.MemoryImage(res.bodyBytes);
          }
        } catch (_) {}
      }

      final primaryColor = PdfColor.fromHex(tmpl.primaryColor);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 40,
                            height: 40,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              tmpl.companyNameEn,
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                            ),
                            pw.Text(
                              tmpl.tagline ?? 'CONSTRUCTION & GENERAL CONTRACTING',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              '${tmpl.address} • CR: ${tmpl.crNumber ?? "N/A"}',
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: primaryColor),
                      ),
                      child: pw.Text(
                        'SITE BUDGET AUDIT REPORT',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 6),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Site Name: ${widget.site.name}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        if (widget.site.clientName != null)
                          pw.Text('Client: ${widget.site.clientName}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Current Assigned Budget:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(currencyFormat.format(widget.site.assignedBudget), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              pw.Text('Budget Transaction History (${transactions.length} records)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Prev Budget', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('New Budget', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Reason / Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                  ...transactions.map((tx) {
                    final isAdd = tx.transactionType == 'add';
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('yyyy-MM-dd').format(tx.date), style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            isAdd ? '+ ADD MONEY' : '- REDUCE MONEY',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: isAdd ? PdfColors.green800 : PdfColors.red800),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currencyFormat.format(tx.previousBudget), style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${isAdd ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: isAdd ? PdfColors.green800 : PdfColors.red800),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currencyFormat.format(tx.newBudget), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(tx.reason ?? '-', style: const pw.TextStyle(fontSize: 8))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Report Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Budget_Report_${widget.site.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<SiteBudgetTransaction>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            final transactions = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.site.name} Budget History',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Current Budget: ${currencyFormat.format(widget.site.assignedBudget)}',
                            style: TextStyle(fontSize: 13, color: Colors.green[800], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : transactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No budget adjustments recorded yet.',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use "+ Add Money" or "- Reduce Money" to adjust.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: transactions.length,
                              separatorBuilder: (c, i) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final tx = transactions[i];
                                final isAdd = tx.transactionType == 'add';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isAdd ? Colors.green.shade50 : Colors.red.shade50,
                                    child: Icon(
                                      isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                      color: isAdd ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isAdd ? 'Added Money' : 'Reduced Money',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isAdd ? Colors.green.shade900 : Colors.red.shade900,
                                        ),
                                      ),
                                      Text(
                                        '${isAdd ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isAdd ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 3),
                                      Text(
                                        'Previous: ${currencyFormat.format(tx.previousBudget)} -> New: ${currencyFormat.format(tx.newBudget)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      if (tx.reason != null && tx.reason!.isNotEmpty)
                                        Text(
                                          'Reason: ${tx.reason}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                        ),
                                      Text(
                                        'Date: ${DateFormat('yyyy-MM-dd').format(tx.date)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                const Divider(height: 24),

                // Bottom actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    ElevatedButton.icon(
                      onPressed: transactions.isEmpty || _isGeneratingPdf
                          ? null
                          : () => _exportPdfReport(transactions),
                      icon: _isGeneratingPdf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2540),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
