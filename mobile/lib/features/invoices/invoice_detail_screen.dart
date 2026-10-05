import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/invoice_model.dart';
import 'create_edit_invoice_screen.dart';
import 'invoice_pdf_generator.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Invoice _invoice;
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _refreshInvoiceDetails();
  }

  Future<void> _refreshInvoiceDetails() async {
    try {
      final invRes = await _supabase
          .from('invoices')
          .select('*, invoice_items(*)')
          .eq('id', _invoice.id)
          .single();

      if (mounted) {
        setState(() {
          _invoice = Invoice.fromJson(invRes);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleStatus() async {
    final newStatus = _invoice.isPaid ? 'Pending' : 'Paid';
    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('invoices')
          .update({'status': newStatus})
          .eq('id', _invoice.id);

      if (mounted) {
        setState(() {
          _invoice = _invoice.copyWith(status: newStatus);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: newStatus == 'Paid' ? const Color(0xFF137333) : const Color(0xFFD93025),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _handlePdfAction({bool share = false}) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(_invoice);
      final fileName = '${_invoice.invoiceNumber}_${_invoice.status}.pdf';

      try {
        if (share) {
          await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        } else {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: fileName,
          );
        }
      } catch (printingErr) {
        // Fallback in-app preview dialog if native printing plugin fails
        if (mounted) {
          _showInAppPdfDialog(pdfBytes, fileName);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _showInAppPdfDialog(Uint8List pdfBytes, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(fileName, style: const TextStyle(fontSize: 16)),
            backgroundColor: const Color(0xFF0A2540),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () => Printing.sharePdf(bytes: pdfBytes, filename: fileName),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
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

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('Are you sure you want to delete ${_invoice.invoiceNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('invoices').delete().eq('id', _invoice.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final isPaid = _invoice.isPaid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Invoice',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateEditInvoiceScreen(invoiceToEdit: _invoice),
                ),
              );
              if (updated == true) {
                _refreshInvoiceDetails();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'delete') {
                _deleteInvoice();
              } else if (val == 'share') {
                _handlePdfAction(share: true);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Share PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Invoice', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Action Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPaid ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid ? 'INVOICE IS PAID' : 'PAYMENT PENDING',
                        style: TextStyle(
                          color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        isPaid
                            ? 'Marked as received & settled'
                            : 'Awaiting customer disbursement',
                        style: TextStyle(
                          color: isPaid ? const Color(0xFF137333).withValues(alpha: 0.8) : const Color(0xFFD93025).withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid ? Colors.white : const Color(0xFF137333),
                    foregroundColor: isPaid ? const Color(0xFFD93025) : Colors.white,
                    side: isPaid ? const BorderSide(color: Color(0xFFD93025)) : null,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _toggleStatus,
                  icon: Icon(isPaid ? Icons.undo_rounded : Icons.check_rounded, size: 16),
                  label: Text(
                    isPaid ? 'Mark Pending' : 'Mark as Paid',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bill Format Preview Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Branding Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A2540),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('AN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'AL NADHEERA',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2540), letterSpacing: 0.8),
                              ),
                              Text(
                                'CONTRACTING W.L.L',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TAX INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2540))),
                          Text(_invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B5ED7))),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Bill To Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BILL TO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Text(_invoice.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                            if (_invoice.customerPhone != null)
                              Text('Tel: ${_invoice.customerPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            if (_invoice.customerAddress != null)
                              Text(_invoice.customerAddress!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            if (_invoice.customerVatNumber != null)
                              Text('VAT: ${_invoice.customerVatNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            if (_invoice.siteName != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Site: ${_invoice.siteName}', style: const TextStyle(fontSize: 11, color: Color(0xFF0B5ED7), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMetaRow('Date:', df.format(_invoice.date)),
                          if (_invoice.dueDate != null) _buildMetaRow('Due Date:', df.format(_invoice.dueDate!)),
                          _buildMetaRow('Currency:', 'BHD'),
                        ],
                      ),
                    ],
                  ),

                  if (_invoice.description != null && _invoice.description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Description: ${_invoice.description}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Line Items Table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0A2540),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(flex: 5, child: Text('Item / Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              SizedBox(width: 40, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              SizedBox(width: 80, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              SizedBox(width: 85, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                        ),
                        // Items
                        for (int i = 0; i < _invoice.items.length; i++) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                            child: Row(
                              children: [
                                SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                Expanded(flex: 5, child: Text(_invoice.items[i].itemDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    _invoice.items[i].quantity % 1 == 0
                                        ? _invoice.items[i].quantity.toInt().toString()
                                        : _invoice.items[i].quantity.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                SizedBox(width: 80, child: Text(currencyFormat.format(_invoice.items[i].unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                SizedBox(width: 85, child: Text(currencyFormat.format(_invoice.items[i].amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          if (i < _invoice.items.length - 1)
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Financial Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 240,
                        child: Column(
                          children: [
                            _buildSummaryLine('Subtotal', currencyFormat.format(_invoice.subtotal)),
                            if (_invoice.discount > 0)
                              _buildSummaryLine('Discount', '- ${currencyFormat.format(_invoice.discount)}', color: Colors.red),
                            if (_invoice.vatAmount > 0)
                              _buildSummaryLine('VAT', '+ ${currencyFormat.format(_invoice.vatAmount)}', color: Colors.green[800]),
                            const Divider(color: Color(0xFF0A2540), thickness: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  currencyFormat.format(_invoice.totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2540)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Official Seal & Signatory Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Seal preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF0A2540), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: const [
                            Text('AL NADHEERA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                            Text('OFFICIAL SEAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                            Text('KINGDOM OF BAHRAIN', style: TextStyle(fontSize: 7, color: Color(0xFF0A2540))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text('_____________________________', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('Authorized Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
                          Text('Al Nadheera Contracting W.L.L', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Print & Share PDF Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2540),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGeneratingPdf ? null : () => _handlePdfAction(share: false),
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.print_rounded),
                  label: const Text('Print / PDF Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0A2540),
                  side: const BorderSide(color: Color(0xFF0A2540)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isGeneratingPdf ? null : () => _handlePdfAction(share: true),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF0A2540))),
        ],
      ),
    );
  }
}
