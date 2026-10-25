import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/currency_words_converter.dart';
import '../../models/invoice_model.dart';
import 'b2b_quotation_pdf_generator.dart';
import 'b2b_document_form_screen.dart';

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
  final NumberFormat _currFormat = NumberFormat('#,##0.000', 'en_US');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

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

  Future<void> _toggleSealSignatureArea(bool enabled) async {
    final updatedSourceConfig = Map<String, dynamic>.from(_invoice.sourceConfig ?? {});
    updatedSourceConfig['showSealSignatureArea'] = enabled;

    setState(() {
      _invoice = _invoice.copyWith(
        showSealSignatureArea: enabled,
        sourceConfig: updatedSourceConfig,
      );
    });

    try {
      await _supabase
          .from('invoices')
          .update({'source_config': updatedSourceConfig})
          .eq('id', _invoice.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Seal & Signature area enabled for PDF & Print'
                  : 'Seal & Signature area disabled',
            ),
            backgroundColor: enabled ? const Color(0xFF0A2540) : const Color(0xFF64748B),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating seal & signature area config: $e');
    }
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
      final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(_invoice);
      final fileName = '${_invoice.invoiceNumber}.pdf';

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
                icon: const Icon(Icons.print_rounded),
                onPressed: () => Printing.layoutPdf(
                  onLayout: (format) async => pdfBytes,
                  name: fileName,
                ),
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
        title: const Text('Delete Document?'),
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
          const SnackBar(content: Text('Document deleted successfully')),
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
    final isPaid = _invoice.isPaid;
    final totalWords = CurrencyWordsConverter.toBahrainiDinarsWords(_invoice.totalAmount);

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
            tooltip: 'Edit Document',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => B2bDocumentFormScreen(invoiceToEdit: _invoice),
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
              } else if (val == 'print') {
                _handlePdfAction(share: false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 18, color: Color(0xFF0A2540)),
                    SizedBox(width: 8),
                    Text('Print Document'),
                  ],
                ),
              ),
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
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Document', style: TextStyle(color: Colors.red)),
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
                        isPaid ? 'DOCUMENT IS SETTLED' : 'STATUS: PENDING',
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
                            : 'Active document awaiting payment/approval',
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

          // Official Al Nadheera Document Card (Matching Image 1)
          Card(
            elevation: 2,
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
                  // 1. Bilingual Al Nadheera Header
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/al_nadheera_emblem.png',
                          height: 52,
                          errorBuilder: (_, __, ___) => const Icon(Icons.business_rounded, size: 40, color: Color(0xFFC51A1B)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AL NADHEERA CONTRACTING CO. W.L.L',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFFC51A1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'شركة النضيرة للمقاولات ذ.م.م',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.black26),
                  const SizedBox(height: 6),

                  // 2. Quotation Number & Date Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quotation No: ${_invoice.invoiceNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                      ),
                      Text(
                        'Date: ${_dateFormat.format(_invoice.date)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3. Recipient "To:" Block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _invoice.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                      ),
                      if (_invoice.customerAddress != null && _invoice.customerAddress!.isNotEmpty)
                        Text(
                          _invoice.customerAddress!,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 4. Underlined Subject Line
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 1.2)),
                    ),
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'SUBJECT: ${(_invoice.subject != null && _invoice.subject!.isNotEmpty) ? _invoice.subject : (_invoice.description ?? "REVISED QUOTATION").toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Salutation & Intent Letter
                  Text(
                    _invoice.salutation ?? 'Respected Sir,',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _invoice.introText ??
                        'We with kind esteem would like to inform you that we confirm our committed intention to engage in your Project and fulfill all related works accordingly.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black87, height: 1.35),
                  ),

                  const SizedBox(height: 14),

                  // 6. Centered Project Sub-Header
                  Center(
                    child: Text(
                      (_invoice.tableHeaderTitle != null && _invoice.tableHeaderTitle!.isNotEmpty)
                          ? _invoice.tableHeaderTitle!.toUpperCase()
                          : (_invoice.description ?? 'STORM WATER HIGHWAY 96').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.black,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 7. Exact 3-Column BOQ Items Table (CLASS, Description, Total Amount)
                  Table(
                    border: TableBorder.all(color: Colors.black, width: 1),
                    columnWidths: const {
                      0: FixedColumnWidth(60), // CLASS
                      1: FlexColumnWidth(5),   // Description
                      2: FixedColumnWidth(110), // Total Amount
                    },
                    children: [
                      // Header Row
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Text('CLASS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Text('Total Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      // Item Rows
                      for (final item in _invoice.items)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Text(item.itemClass ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              child: Text(item.itemDescription, style: const TextStyle(fontSize: 11)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              child: Text(_currFormat.format(item.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      // Summary Rows
                      TableRow(
                        children: [
                          const SizedBox(),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Text(_currFormat.format(_invoice.subtotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          const SizedBox(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Text('VAT ${_invoice.vatRate > 0 ? "${_invoice.vatRate.toStringAsFixed(0)}%" : "10%"}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: Text(_currFormat.format(_invoice.vatAmount), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          const SizedBox(),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                            child: Text('Total Amount of Work', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                            child: Text(_currFormat.format(_invoice.totalAmount), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0A2540))),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 8. Amount in Words
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Our total price shall be BHD ${_currFormat.format(_invoice.totalAmount)} ($totalWords)',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),

                  // 8.5 Seal & Signature Area (Matching Official Format)
                  const SizedBox(height: 14),
                  if (_invoice.showSealSignatureArea) ...[
                    _buildPhysicalSealAndSignatureCard(),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD93025),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _isLoading ? null : () => _toggleSealSignatureArea(false),
                        icon: const Icon(Icons.remove_circle_outline, size: 15),
                        label: const Text('Disable Seal & Signature Box', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFFF8FAFC),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.draw_outlined, size: 20, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seal & Signature Area (Physical)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                ),
                                Text(
                                  'Currently disabled. Enable to show stamp & signature boxes on PDF.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2540),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _isLoading ? null : () => _toggleSealSignatureArea(true),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: Colors.black26),

                  // 9. Company Footer Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Office: +973 77900685 • Mobile: +973 33880685', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                            Text('WhatsApp: +973 33667136 • Email: anccwll@gmail.com', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                            Text('Riffa / Al Hajiyat, Kingdom of Bahrain • www.alnadheera.com', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                          ],
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 38,
                        color: const Color(0xFF7B0D14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Toggle Card for Seal & Signature Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _invoice.showSealSignatureArea ? const Color(0xFF0A2540) : const Color(0xFFE2E8F0),
                width: _invoice.showSealSignatureArea ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _invoice.showSealSignatureArea
                        ? const Color(0xFF0A2540).withValues(alpha: 0.08)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.draw_outlined,
                    color: _invoice.showSealSignatureArea
                        ? const Color(0xFF0A2540)
                        : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seal & Signature Area',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _invoice.showSealSignatureArea
                            ? 'Enabled • Area will be included on PDF for physical seal & sign'
                            : 'Disabled • Tap toggle to add physical seal & signature box',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _invoice.showSealSignatureArea
                              ? const Color(0xFF137333)
                              : const Color(0xFF64748B),
                          fontWeight: _invoice.showSealSignatureArea ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _invoice.showSealSignatureArea,
                  activeTrackColor: const Color(0xFF0A2540),
                  onChanged: _isLoading ? null : (val) => _toggleSealSignatureArea(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Primary Actions: Print Official PDF, Share, Edit
          SizedBox(
            width: double.infinity,
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
              label: const Text('Print Official Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A2540),
                    side: const BorderSide(color: Color(0xFF0A2540)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGeneratingPdf ? null : () => _handlePdfAction(share: true),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC51A1B),
                    side: const BorderSide(color: Color(0xFFC51A1B)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => B2bDocumentFormScreen(invoiceToEdit: _invoice)),
                    );
                    if (updated == true) _refreshInvoiceDetails();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFC51A1B)),
                  label: const Text('Edit Document'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Exact visual card matching the official Seal & Signature format
  /// Left Box: "Customer's Seal and Signature"
  /// Right Box: "FOR : AL NADHEERA CONTRACTING CO WLL" at top, "Authorised Signatory" at bottom-right
  Widget _buildPhysicalSealAndSignatureCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.black, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            children: [
              // Left: Customer's Seal and Signature
              Container(
                height: 90,
                padding: const EdgeInsets.all(8),
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    "Customer's Seal and Signature",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              // Right: FOR : AL NADHEERA CONTRACTING CO WLL + Authorised Signatory
              Container(
                height: 90,
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'FOR : AL NADHEERA CONTRACTING CO WLL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        'Authorised Signatory',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
