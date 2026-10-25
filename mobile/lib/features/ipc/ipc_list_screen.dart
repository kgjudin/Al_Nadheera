import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/ipc_model.dart';
import '../../services/api_service.dart';
import 'create_edit_ipc_screen.dart';
import 'services/ipc_excel_generator.dart';
import 'services/ipc_pdf_generator.dart';

class IpcListScreen extends StatefulWidget {
  const IpcListScreen({super.key});

  @override
  State<IpcListScreen> createState() => _IpcListScreenState();
}

class _IpcListScreenState extends State<IpcListScreen> {
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();

  late Future<List<IpcDocument>> _ipcFuture;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  final NumberFormat _fmt = NumberFormat('#,##0.000');

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    setState(() {
      _ipcFuture = _fetchIpcDocuments();
    });
  }

  Future<List<IpcDocument>> _fetchIpcDocuments() async {
    try {
      final res = await _supabase
          .from('ipc_documents')
          .select('*, ipc_items(*)')
          .order('created_at', ascending: false);

      return (res as List).map((json) => IpcDocument.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Supabase direct IPC query error: $e. Trying fallback API...');
      try {
        return await _apiService.getIpcDocuments();
      } catch (e2) {
        throw Exception('Failed to load IPC documents: $e');
      }
    }
  }

  Future<void> _deleteDocument(String id) async {
    try {
      await _supabase.from('ipc_documents').delete().eq('id', id);
    } catch (_) {
      await _apiService.deleteIpcDocument(id);
    }
    _loadDocuments();
  }

  void _confirmDelete(IpcDocument doc) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete IPC Document'),
        content: Text('Are you sure you want to delete "${doc.documentNumber} - ${doc.projectName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _deleteDocument(doc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('IPC document deleted successfully')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openCreateEdit([IpcDocument? existing]) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateEditIpcScreen(existingDocument: existing)),
    ).then((saved) {
      if (saved == true) {
        _loadDocuments();
      }
    });
  }

  Future<void> _previewPdf(IpcDocument doc) async {
    try {
      await IpcPdfGenerator.showPreview(context, doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printPdf(IpcDocument doc) async {
    final bytes = await IpcPdfGenerator.generatePdf(doc);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: '${doc.documentNumber}_Measurement_Bill.pdf',
    );
  }

  Future<void> _exportExcel(IpcDocument doc) async {
    try {
      final bytes = await IpcExcelGenerator.generateExcel(doc);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${doc.documentNumber}_Measurement_Bill.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Excel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('IPC Measurement Bills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadDocuments,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadDocuments();
          await _ipcFuture;
        },
        child: FutureBuilder<List<IpcDocument>>(
          future: _ipcFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      const Text('Failed to load IPC documents', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDocuments,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      const Text(
                        'No IPC Documents Created Yet',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create interim payment certificates and measurement bills for clients with live quantity, rate & amount valuations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2540),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openCreateEdit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First IPC Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allDocs = snapshot.data!;

            // Filter docs
            final filtered = allDocs.where((d) {
              final q = _searchQuery.toLowerCase().trim();
              final matchesQuery = q.isEmpty ||
                  d.projectName.toLowerCase().contains(q) ||
                  d.documentNumber.toLowerCase().contains(q) ||
                  (d.clientName != null && d.clientName!.toLowerCase().contains(q));

              final matchesStatus = _selectedStatusFilter == 'All' || d.status == _selectedStatusFilter;
              return matchesQuery && matchesStatus;
            }).toList();

            double totalValuation = 0.0;
            for (final d in filtered) {
              totalValuation += d.totalAmount;
            }

            return Column(
              children: [
                // Search and Filters Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by project name, IPC #, or client...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 8),

                      // Status filter chips
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: ['All', 'Draft', 'Submitted', 'Approved', 'Paid'].map((st) {
                            final isSel = _selectedStatusFilter == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(st, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: const Color(0xFF0A2540),
                                labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF334155)),
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                onSelected: (_) => setState(() => _selectedStatusFilter = st),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Summary Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${allDocs.length} bills',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Total: BHD ${_fmt.format(totalValuation)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0A2540), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Documents List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No IPC documents match your search/filter.', style: TextStyle(color: Color(0xFF94A3B8))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final doc = filtered[idx];
                            return _buildIpcCard(doc);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        onPressed: () => _openCreateEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New IPC Bill', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIpcCard(IpcDocument doc) {
    Color statusColor;
    switch (doc.status) {
      case 'Approved':
      case 'Paid':
        statusColor = const Color(0xFF16A34A);
        break;
      case 'Submitted':
        statusColor = const Color(0xFF0284C7);
        break;
      default:
        statusColor = const Color(0xFFEAB308);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _previewPdf(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top badges & date row
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
                          doc.documentNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0A2540)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.status.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(doc.date),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Project Title
              Text(
                doc.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
              ),

              if (doc.clientName != null && doc.clientName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      doc.clientName!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Bottom stats & action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${doc.items.length} bill rows',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        'BHD ${_fmt.format(doc.totalAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2540)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_rounded, color: Color(0xFF0A2540), size: 20),
                        tooltip: 'Preview IPC Document',
                        onPressed: () => _previewPdf(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A), size: 20),
                        tooltip: 'Export Excel (.xlsx)',
                        onPressed: () => _exportExcel(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Color(0xFF64748B), size: 20),
                        tooltip: 'Print PDF',
                        onPressed: () => _printPdf(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 20),
                        tooltip: 'Edit IPC',
                        onPressed: () => _openCreateEdit(doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        tooltip: 'Delete IPC',
                        onPressed: () => _confirmDelete(doc),
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
