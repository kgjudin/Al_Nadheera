import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/invoice_model.dart';
import '../customers/customers_screen.dart';
import 'create_edit_invoice_screen.dart';
import 'invoice_detail_screen.dart';
import 'invoice_pdf_generator.dart';
import '../document_templates/document_template_settings_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _supabase = Supabase.instance.client;
  final currencyFormat = NumberFormat.currency(symbol: 'BHD ', decimalDigits: 3);
  final dateFormat = DateFormat('yyyy-MM-dd');

  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Paid'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('invoices')
          .select('*, invoice_items(*)')
          .order('date', ascending: false);

      final list = (res as List).map((json) {
        return Invoice.fromJson(json as Map<String, dynamic>);
      }).toList();

      if (mounted) {
        setState(() {
          _invoices = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load invoices: $e')),
        );
      }
    }
  }

  Future<void> _toggleInvoiceStatus(Invoice invoice) async {
    final newStatus = invoice.isPaid ? 'Pending' : 'Paid';

    try {
      await _supabase
          .from('invoices')
          .update({'status': newStatus})
          .eq('id', invoice.id);

      setState(() {
        final idx = _invoices.indexWhere((i) => i.id == invoice.id);
        if (idx != -1) {
          _invoices[idx] = _invoices[idx].copyWith(status: newStatus);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${invoice.invoiceNumber} status changed to $newStatus'),
            backgroundColor: newStatus == 'Paid' ? const Color(0xFF137333) : const Color(0xFFD93025),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _printOrSharePdf(Invoice invoice) async {
    try {
      final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(invoice);
      final fileName = '${invoice.invoiceNumber}_${invoice.status}.pdf';
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _invoices.where((inv) {
      // Filter by status
      if (_selectedFilter == 'Pending' && !inv.isPending) return false;
      if (_selectedFilter == 'Paid' && !inv.isPaid) return false;

      // Filter by search
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.customerName.toLowerCase().contains(q) ||
          (inv.siteName != null && inv.siteName!.toLowerCase().contains(q)) ||
          (inv.description != null && inv.description!.toLowerCase().contains(q));
    }).toList();

    // KPI Metrics
    final totalInvoiced = _invoices.fold<double>(0.0, (acc, i) => acc + i.totalAmount);
    final pendingInvoices = _invoices.where((i) => i.isPending).toList();
    final totalPending = pendingInvoices.fold<double>(0.0, (acc, i) => acc + i.totalAmount);
    final paidInvoices = _invoices.where((i) => i.isPaid).toList();
    final totalPaid = paidInvoices.fold<double>(0.0, (acc, i) => acc + i.totalAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Invoices & Billing', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        actions: [
          // Customer Management Button
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomersScreen()),
              );
            },
            icon: const Icon(Icons.groups_rounded, size: 20),
            label: const Text('Customers', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A2540)),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DocumentTemplateSettingsScreen(),
                ),
              );
            },
            tooltip: 'Print Formats & Templates',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInvoices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvoices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Invoiced',
                    amount: currencyFormat.format(totalInvoiced),
                    countText: '${_invoices.length} Bills',
                    color: const Color(0xFF0A2540),
                    bgColor: const Color(0xFFF1F5F9),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Pending',
                    amount: currencyFormat.format(totalPending),
                    countText: '${pendingInvoices.length} Unpaid',
                    color: const Color(0xFFD93025),
                    bgColor: const Color(0xFFFCE8E6),
                    icon: Icons.hourglass_top_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Paid',
                    amount: currencyFormat.format(totalPaid),
                    countText: '${paidInvoices.length} Settled',
                    color: const Color(0xFF137333),
                    bgColor: const Color(0xFFE6F4EA),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search invoice number, customer, or site...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),

            const SizedBox(height: 14),

            // Filter Tabs (All, Pending, Paid)
            Row(
              children: [
                _buildFilterChip('All', _invoices.length),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', pendingInvoices.length, activeColor: const Color(0xFFD93025)),
                const SizedBox(width: 8),
                _buildFilterChip('Paid', paidInvoices.length, activeColor: const Color(0xFF137333)),
              ],
            ),

            const SizedBox(height: 14),

            // Invoices List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _selectedFilter != 'All'
                            ? 'No invoices match your filter'
                            : 'No invoices created yet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the button below to generate your first bill or invoice.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2540),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _navigateToCreateInvoice,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create New Invoice'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((inv) => _buildInvoiceCard(inv)),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        onPressed: _navigateToCreateInvoice,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _navigateToCreateInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEditInvoiceScreen()),
    ).then((res) {
      if (res == true) _loadInvoices();
    });
  }

  Widget _buildFilterChip(String label, int count, {Color? activeColor}) {
    final isSelected = _selectedFilter == label;
    final color = activeColor ?? const Color(0xFF0A2540);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String countText,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            countText,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final isPaid = invoice.isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvoiceDetailScreen(invoice: invoice),
            ),
          ).then((_) => _loadInvoices());
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Number, Date, Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2540).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(invoice.date),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  // Status badge (Tappable to toggle status!)
                  InkWell(
                    onTap: () => _toggleInvoiceStatus(invoice),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                            size: 13,
                            color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'PAID' : 'PENDING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? const Color(0xFF137333) : const Color(0xFFD93025),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.sync_rounded, size: 10, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Customer Name and Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (invoice.siteName != null && invoice.siteName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.business_rounded, size: 12, color: Color(0xFF0B5ED7)),
                              const SizedBox(width: 4),
                              Text(
                                invoice.siteName!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF0B5ED7), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(invoice.totalAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPaid ? const Color(0xFF137333) : const Color(0xFF0A2540),
                    ),
                  ),
                ],
              ),

              if (invoice.description != null && invoice.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  invoice.description!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 6),

              // Bottom card bar: Items count, Print / PDF shortcut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${invoice.items.length} Line Item${invoice.items.length == 1 ? '' : 's'}${invoice.discount > 0 ? ' • Discount Applied' : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF0A2540)),
                        tooltip: 'Print PDF',
                        onPressed: () => _printOrSharePdf(invoice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0A2540)),
                        tooltip: 'Edit Invoice',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateEditInvoiceScreen(invoiceToEdit: invoice),
                            ),
                          ).then((res) {
                            if (res == true) _loadInvoices();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
