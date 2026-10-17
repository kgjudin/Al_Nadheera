import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ipc_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import 'services/ipc_excel_generator.dart';
import 'services/ipc_pdf_generator.dart';

class _IpcSectionItem {
  final TextEditingController itemNumberCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController rateCtrl;
  String? productId;
  bool isCustomDescription;

  _IpcSectionItem({
    String itemNumber = '',
    String description = '',
    String unit = '',
    String quantity = '',
    String rate = '',
    this.productId,
    this.isCustomDescription = false,
  })  : itemNumberCtrl = TextEditingController(text: itemNumber),
        descriptionCtrl = TextEditingController(text: description),
        unitCtrl = TextEditingController(text: unit),
        quantityCtrl = TextEditingController(text: quantity),
        rateCtrl = TextEditingController(text: rate);

  String get itemNumber => itemNumberCtrl.text.trim();
  String get description => descriptionCtrl.text.trim();
  String get unit => unitCtrl.text.trim();
  double get quantity => double.tryParse(quantityCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
  double get rate => double.tryParse(rateCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
  double get amount => quantity * rate;

  void dispose() {
    itemNumberCtrl.dispose();
    descriptionCtrl.dispose();
    unitCtrl.dispose();
    quantityCtrl.dispose();
    rateCtrl.dispose();
  }
}

class _IpcSectionGroup {
  String? selectedClass;
  final TextEditingController customClassCtrl;
  bool isCustomClass;

  String? selectedSubheading;
  final TextEditingController customSubheadingCtrl;
  bool isCustomSubheading;

  final List<_IpcSectionItem> items;

  _IpcSectionGroup({
    this.selectedClass,
    String customClass = '',
    this.selectedSubheading,
    String customSubheading = '',
    List<_IpcSectionItem>? items,
  })  : isCustomClass = false,
        isCustomSubheading = false,
        customClassCtrl = TextEditingController(text: customClass.isNotEmpty ? customClass : (selectedClass ?? '')),
        customSubheadingCtrl = TextEditingController(text: customSubheading.isNotEmpty ? customSubheading : (selectedSubheading ?? '')),
        items = items ?? [];

  String get effectiveClass => isCustomClass ? customClassCtrl.text.trim() : (selectedClass ?? customClassCtrl.text.trim());
  String get effectiveSubheading => isCustomSubheading ? customSubheadingCtrl.text.trim() : (selectedSubheading ?? customSubheadingCtrl.text.trim());

  double get totalAmount {
    double sum = 0.0;
    for (final it in items) {
      sum += it.amount;
    }
    return sum;
  }

  void dispose() {
    customClassCtrl.dispose();
    customSubheadingCtrl.dispose();
    for (final it in items) {
      it.dispose();
    }
  }
}

class CreateEditIpcScreen extends StatefulWidget {
  final IpcDocument? existingDocument;

  const CreateEditIpcScreen({super.key, this.existingDocument});

  @override
  State<CreateEditIpcScreen> createState() => _CreateEditIpcScreenState();
}

class _CreateEditIpcScreenState extends State<CreateEditIpcScreen> {
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _projectCtrl = TextEditingController();
  final TextEditingController _docNumberCtrl = TextEditingController();
  final TextEditingController _clientCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'Draft';

  final List<_IpcSectionGroup> _sections = [];
  bool _isSaving = false;

  List<Product> _allCatalogProducts = [];
  List<ProductClass> _allClasses = [];
  List<ProductSubmodule> _allSubmodules = [];

  final NumberFormat _fmt = NumberFormat('#,##0.000');

  @override
  void initState() {
    super.initState();
    final doc = widget.existingDocument;
    if (doc != null) {
      _projectCtrl.text = doc.projectName;
      _docNumberCtrl.text = doc.documentNumber;
      _clientCtrl.text = doc.clientName ?? '';
      _selectedDate = doc.date;
      _selectedStatus = doc.status;

      String? curClass;
      String? curSub;
      _IpcSectionGroup? curGroup;

      for (final item in doc.items) {
        if (item.itemType == 'heading') {
          curClass = item.description;
          curSub = null;
          curGroup = _IpcSectionGroup(
            selectedClass: curClass,
            customClass: curClass,
          );
          _sections.add(curGroup);
        } else if (item.itemType == 'subheading') {
          curSub = item.description;
          if (curGroup == null || curGroup.items.isNotEmpty) {
            curGroup = _IpcSectionGroup(
              selectedClass: curClass,
              customClass: curClass ?? '',
              selectedSubheading: curSub,
              customSubheading: curSub,
            );
            _sections.add(curGroup);
          } else {
            curGroup.selectedSubheading = curSub;
            curGroup.customSubheadingCtrl.text = curSub;
          }
        } else {
          // item
          if (curGroup == null) {
            curGroup = _IpcSectionGroup(
              selectedClass: item.className ?? curClass,
              selectedSubheading: item.submoduleName ?? curSub,
            );
            _sections.add(curGroup);
          }
          curGroup.items.add(_IpcSectionItem(
            itemNumber: item.itemNumber ?? '',
            description: item.description,
            unit: item.unit ?? 'm',
            quantity: item.quantity > 0 ? item.quantity.toStringAsFixed(3) : '',
            rate: item.rate > 0 ? item.rate.toStringAsFixed(3) : '',
            productId: item.productId,
          ));
        }
      }
    } else {
      _projectCtrl.text = '';
      _docNumberCtrl.text = '';
      _clientCtrl.text = '';
    }

    _loadCatalogData();
  }

  @override
  void dispose() {
    _projectCtrl.dispose();
    _docNumberCtrl.dispose();
    _clientCtrl.dispose();
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalogData() async {
    try {
      final res = await _supabase.from('products').select().order('name');
      _allCatalogProducts = (res as List).map((j) => Product.fromJson(j)).toList();
    } catch (_) {
      try {
        _allCatalogProducts = await _apiService.getProducts();
      } catch (_) {}
    }

    try {
      final res = await _supabase.from('product_classes').select().order('name');
      _allClasses = (res as List).map((j) => ProductClass.fromJson(j)).toList();
    } catch (_) {
      try {
        _allClasses = await _apiService.getProductClasses();
      } catch (_) {}
    }

    try {
      final res = await _supabase.from('product_submodules').select().order('name');
      _allSubmodules = (res as List).map((j) => ProductSubmodule.fromJson(j)).toList();
    } catch (_) {
      try {
        _allSubmodules = await _apiService.getProductSubmodules();
      } catch (_) {}
    }

    // If starting fresh and no sections exist yet, initialize section 1 (clean without prefilled data)
    if (_sections.isEmpty && widget.existingDocument == null) {
      final section1 = _IpcSectionGroup(
        selectedClass: null,
        selectedSubheading: null,
      );
      _addDescriptionItemToSection(section1);
      _sections.add(section1);
    }

    if (mounted) setState(() {});
  }

  List<String> _getAvailableClassNames() {
    final set = <String>{};
    for (final c in _allClasses) {
      if (c.name.trim().isNotEmpty) set.add(c.name.trim());
    }
    for (final p in _allCatalogProducts) {
      if (p.className != null && p.className!.trim().isNotEmpty) {
        set.add(p.className!.trim());
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _getSubheadingsForClass(String? className) {
    final target = className?.trim().toLowerCase();
    if (target == null || target.isEmpty) return [];

    final set = <String>{};

    for (final s in _allSubmodules) {
      if (s.className.trim().toLowerCase() == target) {
        if (s.name.trim().isNotEmpty) set.add(s.name.trim());
      }
    }
    for (final p in _allCatalogProducts) {
      final pc = p.className?.trim().toLowerCase();
      if (pc == target) {
        if (p.submoduleName != null && p.submoduleName!.trim().isNotEmpty) {
          set.add(p.submoduleName!.trim());
        }
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<Product> _getProductsFor(String? className, String? submoduleName) {
    if (_allCatalogProducts.isEmpty) return [];

    final cTarget = className?.trim().toLowerCase() ?? '';
    final sTarget = submoduleName?.trim().toLowerCase() ?? '';

    // If nothing selected yet, return empty list
    if (cTarget.isEmpty && sTarget.isEmpty) return [];

    // 1. Both class and submodule match
    if (cTarget.isNotEmpty && sTarget.isNotEmpty) {
      final bothMatch = _allCatalogProducts.where((p) {
        final pc = p.className?.trim().toLowerCase() ?? '';
        final ps = p.submoduleName?.trim().toLowerCase() ?? '';

        final cMatch = pc == cTarget || pc.contains(cTarget) || cTarget.contains(pc);
        final sMatch = ps == sTarget || ps.contains(sTarget) || sTarget.contains(ps);

        return cMatch && sMatch;
      }).toList();

      if (bothMatch.isNotEmpty) return bothMatch;
    }

    // 2. Submodule-only match
    if (sTarget.isNotEmpty) {
      final subMatch = _allCatalogProducts.where((p) {
        final ps = p.submoduleName?.trim().toLowerCase() ?? '';
        return ps == sTarget || ps.contains(sTarget) || sTarget.contains(ps);
      }).toList();
      if (subMatch.isNotEmpty) return subMatch;
    }

    // 3. Class-only match
    if (cTarget.isNotEmpty) {
      final classMatch = _allCatalogProducts.where((p) {
        final pc = p.className?.trim().toLowerCase() ?? '';
        return pc == cTarget || pc.contains(cTarget) || cTarget.contains(pc);
      }).toList();
      if (classMatch.isNotEmpty) return classMatch;
    }

    return [];
  }

  int get _totalItemCount {
    int count = 0;
    for (final s in _sections) {
      count += s.items.length;
    }
    return count;
  }

  double get _totalAmount {
    double sum = 0.0;
    for (final s in _sections) {
      sum += s.totalAmount;
    }
    return sum;
  }

  void _addDescriptionItemToSection(_IpcSectionGroup section) {
    section.items.add(_IpcSectionItem(
      itemNumber: '',
      description: '',
      unit: '',
      quantity: '',
      rate: '',
      productId: null,
      isCustomDescription: false,
    ));
    if (mounted) setState(() {});
  }

  void _addNewSection() {
    final newSection = _IpcSectionGroup(
      selectedClass: null,
      selectedSubheading: null,
    );
    _addDescriptionItemToSection(newSection);

    setState(() {
      _sections.add(newSection);
    });
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) return;
    setState(() {
      final removed = _sections.removeAt(index);
      removed.dispose();
    });
  }

  IpcDocument _buildCurrentDocument() {
    final flatItems = <IpcItem>[];
    int sortOrder = 0;
    String? lastClass;

    for (final section in _sections) {
      final cName = section.effectiveClass;
      final sName = section.effectiveSubheading;

      // Add Class Heading if different from last class
      if (cName.isNotEmpty && cName != lastClass) {
        flatItems.add(IpcItem(
          itemType: 'heading',
          description: cName,
          className: cName,
          sortOrder: sortOrder++,
        ));
        lastClass = cName;
      }

      // Add Subheading
      if (sName.isNotEmpty) {
        flatItems.add(IpcItem(
          itemType: 'subheading',
          description: sName,
          className: cName.isNotEmpty ? cName : null,
          submoduleName: sName,
          sortOrder: sortOrder++,
        ));
      }

      // Add items
      for (final it in section.items) {
        if (it.description.isEmpty && it.amount == 0 && it.quantity == 0) {
          continue;
        }
        flatItems.add(IpcItem(
          itemType: 'item',
          itemNumber: it.itemNumber.isNotEmpty ? it.itemNumber : null,
          description: it.description,
          unit: it.unit.isNotEmpty ? it.unit : null,
          quantity: it.quantity,
          rate: it.rate,
          amount: it.amount,
          className: cName.isNotEmpty ? cName : null,
          submoduleName: sName.isNotEmpty ? sName : null,
          productId: it.productId,
          sortOrder: sortOrder++,
        ));
      }
    }

    return IpcDocument(
      id: widget.existingDocument?.id ?? '',
      documentNumber: _docNumberCtrl.text.trim(),
      projectName: _projectCtrl.text.trim(),
      clientName: _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim(),
      date: _selectedDate,
      status: _selectedStatus,
      totalAmount: _totalAmount,
      items: flatItems,
    );
  }

  Future<void> _saveIpc() async {
    if (!_formKey.currentState!.validate()) return;
    final filledCount = _sections.expand((s) => s.items).where((it) => it.description.isNotEmpty).length;
    if (filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter at least one item description.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final doc = _buildCurrentDocument();

    try {
      final payload = doc.toJson();
      if (widget.existingDocument != null) {
        await _supabase.from('ipc_documents').update(payload).eq('id', widget.existingDocument!.id);
      } else {
        await _supabase.from('ipc_documents').insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IPC Document saved successfully!'),
            backgroundColor: Color(0xFF137333),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Supabase direct IPC save failed: $e. Trying backend API...');
      try {
        final payload = doc.toJson();
        if (widget.existingDocument != null) {
          await _apiService.updateIpcDocument(widget.existingDocument!.id, payload);
        } else {
          await _apiService.createIpcDocument(payload);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('IPC Document saved successfully!'),
              backgroundColor: Color(0xFF137333),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving IPC: $e2'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _previewAndPrintPdf() async {
    final doc = _buildCurrentDocument();
    final pdfBytes = await IpcPdfGenerator.generatePdf(doc);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '${doc.documentNumber}_${doc.projectName}.pdf',
    );
  }

  Future<void> _exportExcel() async {
    final doc = _buildCurrentDocument();
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
    final isEditing = widget.existingDocument != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit IPC Document' : 'Create IPC Measurement Bill',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A)),
            tooltip: 'Export Excel (.xlsx)',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF0A2540)),
            tooltip: 'Print / Preview PDF',
            onPressed: _previewAndPrintPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Valuation', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(
                      'BHD ${_fmt.format(_totalAmount)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2540),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _saveIpc,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Saving...' : (isEditing ? 'Update IPC' : 'Save IPC Bill'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Project & Header Info Box
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Header & Project Information',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),

                    // PROJECT: [Title]
                    TextFormField(
                      controller: _projectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PROJECT: Heading (Appears top of PDF & Bill) *',
                        hintText: 'e.g. PROJECT: HIGHWAY EXPANSION or VILLA PROJECT',
                        prefixIcon: Icon(Icons.business_center_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Project heading is required' : null,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _docNumberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Document / IPC # *',
                              hintText: 'e.g. IPC-2026-001',
                              prefixIcon: Icon(Icons.tag_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'IPC # required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _clientCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Client Name',
                              hintText: 'e.g. Ministry of Works',
                              prefixIcon: Icon(Icons.business_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) setState(() => _selectedDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.flag_rounded, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                              DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                            ],
                            onChanged: (v) => setState(() => _selectedStatus = v ?? 'Draft'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Section loop
            ..._sections.asMap().entries.map((entry) {
              final sectionIndex = entry.key;
              final section = entry.value;
              return _buildSectionCard(section, sectionIndex);
            }),

            const SizedBox(height: 8),

            // "+ Add Next Class / Sub-Heading Section" Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _addNewSection,
              icon: const Icon(Icons.playlist_add_rounded, size: 22),
              label: const Text(
                '+ Add Next Section (Class / Sub-Heading)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),

            // Grand Total Summary Box
            Card(
              elevation: 0,
              color: const Color(0xFF0A2540),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL AMOUNT',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        Text(
                          '$_totalItemCount bill items included across ${_sections.length} sections',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      'BHD ${_fmt.format(_totalAmount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(_IpcSectionGroup section, int sectionIndex) {
    final availableClasses = _getAvailableClassNames();
    final availableSubheadings = _getSubheadingsForClass(section.effectiveClass);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2540),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'SECTION ${sectionIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (_sections.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Section',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeSection(sectionIndex),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 1. CLASS SELECTION (Main Heading)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_special_rounded, color: Color(0xFF0369A1), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '1. SELECT CLASS (Main Heading)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        onPressed: () => setState(() => section.isCustomClass = !section.isCustomClass),
                        icon: Icon(section.isCustomClass ? Icons.list_rounded : Icons.edit_note_rounded, size: 16, color: const Color(0xFF0369A1)),
                        label: Text(
                          section.isCustomClass ? 'Pick from Dropdown' : 'Type Custom Class',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!section.isCustomClass && availableClasses.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: availableClasses.contains(section.selectedClass) ? section.selectedClass : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF93C5FD))),
                        isDense: true,
                      ),
                      hint: const Text('Choose a Class Heading...', style: TextStyle(fontSize: 13)),
                      items: availableClasses.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          section.selectedClass = val;
                          section.customClassCtrl.text = val ?? '';
                          section.selectedSubheading = null;
                          section.customSubheadingCtrl.text = '';
                        });
                      },
                    )
                  else
                    TextFormField(
                      controller: section.customClassCtrl,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: 'e.g. CLASS I : PIPEWORK-PIPES',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. SUB-HEADING SELECTION
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF0F766E), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '2. SUB-HEADING of ${section.effectiveClass.isNotEmpty ? section.effectiveClass : "Class"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F766E)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        onPressed: () => setState(() => section.isCustomSubheading = !section.isCustomSubheading),
                        icon: Icon(section.isCustomSubheading ? Icons.list_rounded : Icons.edit_note_rounded, size: 16, color: const Color(0xFF0F766E)),
                        label: Text(
                          section.isCustomSubheading ? 'Pick from Dropdown' : 'Type Custom Sub-Heading',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!section.isCustomSubheading)
                    DropdownButtonFormField<String>(
                      value: availableSubheadings.contains(section.selectedSubheading) ? section.selectedSubheading : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF5EEAD4))),
                        isDense: true,
                      ),
                      hint: Text(
                        section.effectiveClass.isEmpty
                            ? 'Please choose a Class above first...'
                            : (availableSubheadings.isEmpty
                                ? 'No sub-headings found for this class'
                                : 'Choose a Sub-Heading / Sub-module...'),
                        style: TextStyle(
                          fontSize: 13,
                          color: availableSubheadings.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      items: availableSubheadings.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: availableSubheadings.isEmpty ? null : (val) {
                        setState(() {
                          section.selectedSubheading = val;
                          section.customSubheadingCtrl.text = val ?? '';
                        });
                      },
                    )
                  else
                    TextFormField(
                      controller: section.customSubheadingCtrl,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        hintText: 'e.g. Nominal bore 600mm or Clause 3.3 ...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. DESCRIPTIONS / PRODUCTS LIST UNDER THIS SUB-HEADING
            Row(
              children: [
                const Icon(Icons.description_rounded, size: 16, color: Color(0xFF475569)),
                const SizedBox(width: 6),
                const Text(
                  '3. DESCRIPTIONS & PRODUCTS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${section.items.length} items',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ...section.items.asMap().entries.map((entry) {
              final itIdx = entry.key;
              final it = entry.value;
              return _buildSectionItemCard(section, it, itIdx);
            }),

            const SizedBox(height: 10),

            // "+ Add More Description" button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0A2540),
                side: const BorderSide(color: Color(0xFF0A2540)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => _addDescriptionItemToSection(section),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                section.effectiveSubheading.isNotEmpty
                    ? '+ Add More Description under "${section.effectiveSubheading}"'
                    : '+ Add More Description',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionItemCard(_IpcSectionGroup section, _IpcSectionItem it, int itIdx) {
    final matchingProducts = _getProductsFor(section.effectiveClass, section.effectiveSubheading);

    // Selected product id resolution
    String? selectedProdId;
    if (matchingProducts.any((p) => p.id == it.productId)) {
      selectedProdId = it.productId;
    } else if (matchingProducts.any((p) => p.name.trim().toLowerCase() == it.description.trim().toLowerCase())) {
      selectedProdId = matchingProducts.firstWhere((p) => p.name.trim().toLowerCase() == it.description.trim().toLowerCase()).id;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Item # & Actions
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: it.itemNumberCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2540)),
                  decoration: InputDecoration(
                    labelText: 'Item #',
                    hintText: 'I1',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Specification #${itIdx + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              IconButton(
                icon: Icon(
                  it.isCustomDescription ? Icons.list_rounded : Icons.edit_note_rounded,
                  size: 18,
                  color: const Color(0xFF0A2540),
                ),
                tooltip: it.isCustomDescription ? 'Choose from products dropdown' : 'Edit / type custom description',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    it.isCustomDescription = !it.isCustomDescription;
                  });
                },
              ),
              if (section.items.length > 1)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Remove Item',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      section.items.removeAt(itIdx);
                      it.dispose();
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Description Box: Dropdown of Products from Product Page!
          if (!it.isCustomDescription)
            DropdownButtonFormField<String>(
              value: selectedProdId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Description (Product / Specification) *',
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF0A2540), width: 1.5)),
              ),
              hint: Text(
                section.effectiveClass.isEmpty && section.effectiveSubheading.isEmpty
                    ? 'Select Class & Sub-Heading above first...'
                    : (matchingProducts.isEmpty
                        ? 'No products saved for this section'
                        : (it.description.isNotEmpty ? it.description : 'Select Product Name / Specification...')),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: it.description.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  color: it.description.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              items: matchingProducts.map((p) => DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${p.unit ?? 'METER'} @ BHD ${p.price > 0 ? p.price.toStringAsFixed(3) : '0.000'}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              onChanged: matchingProducts.isEmpty ? null : (prodId) {
                if (prodId != null) {
                  final p = matchingProducts.firstWhere((prod) => prod.id == prodId);
                  setState(() {
                    it.productId = p.id;
                    it.descriptionCtrl.text = p.name;
                    it.unitCtrl.text = p.unit ?? 'METER';
                    it.rateCtrl.text = p.price > 0 ? p.price.toStringAsFixed(3) : '0.000';
                  });
                }
              },
            )
          else
            TextFormField(
              controller: it.descriptionCtrl,
              maxLines: null,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Description (Product / Specification) *',
                hintText: 'e.g. In trenches, depth not exceeding 1.50 m',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 8),

          // Unit | Quantity | Rate | Amount
          Row(
            children: [
              // Unit
              SizedBox(
                width: 75,
                child: TextFormField(
                  controller: it.unitCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    hintText: 'm',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Quantity
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: it.quantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Quantity *',
                    hintText: '0.000',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Rate
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: it.rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Rate',
                    hintText: '0.000',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Live Amount
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Amount (BHD)',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      Text(
                        _fmt.format(it.amount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
