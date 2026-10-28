import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/currency_words_converter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../services/invoice_number_service.dart';
import 'b2b_quotation_pdf_generator.dart';

class B2bDocumentFormScreen extends StatefulWidget {
  final Invoice? invoiceToEdit;

  const B2bDocumentFormScreen({super.key, this.invoiceToEdit});

  @override
  State<B2bDocumentFormScreen> createState() => _B2bDocumentFormScreenState();
}

class _B2bDocumentFormScreenState extends State<B2bDocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final NumberFormat _currFormat = NumberFormat('#,##0.000', 'en_US');

  // ==================== SOURCE CARD CONTROLLERS & STATE ====================
  static const String _defaultQuotationIntroText =
      'We with kind esteem would like to inform you that we confirm our committed intention to engage in your Project to provide the Project Management and Construction Management Services for the above mention project. Our organization is pleased to submit our best Competitive offer in conformity to the Specification and Drawing for an amount of BOQ Details Below.';

  String _documentType = 'Quotation';
  final List<String> _documentTypeOptions = [
    'Quotation',
    'Letter',
    'B2B',
    'Tax Invoice',
    'Estimate',
    'Performa Invoice'
  ];

  DateTime _startDate = DateTime(2026, 5, 10);
  DateTime? _endDate;

  String _pageFormat = 'Letter';
  final List<String> _pageFormatOptions = ['Letter', 'A4', 'Legal'];

  String _pageMode = 'PORTRAIT';
  final List<String> _pageModeOptions = ['PORTRAIT', 'LANDSCAPE'];

  String _fontType = 'Helvetica';
  final List<String> _fontTypeOptions = ['Helvetica', 'Times New Roman', 'Courier', 'Roboto'];

  String _status = 'Pending';
  final List<String> _statusOptions = ['Pending', 'Paid', 'Active', 'Draft', 'Approved', 'Cancelled', 'Overdue'];

  late TextEditingController _marginTopCtrl;
  late TextEditingController _marginLeftCtrl;
  late TextEditingController _marginRightCtrl;
  late TextEditingController _marginHeaderCtrl;
  late TextEditingController _marginBottomCtrl;
  late TextEditingController _autoPageBreakCtrl;

  // ==================== DOCUMENT DETAILS CONTROLLERS ====================
  late TextEditingController _quotationNumCtrl;
  late TextEditingController _recipientNameCtrl;
  late TextEditingController _recipientCityCtrl;
  late TextEditingController _recipientCountryCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _salutationCtrl;
  late TextEditingController _introTextCtrl;
  late TextEditingController _tableTitleCtrl;
  late TextEditingController _vatRateCtrl;

  List<Customer> _savedCustomers = [];
  Customer? _selectedCustomer;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSealSignatureArea = false;

  // ==================== DYNAMIC BOQ ITEMS ====================
  final List<_B2bItemInputRow> _itemRows = [];

  @override
  void initState() {
    super.initState();
    final edit = widget.invoiceToEdit;

    // Source configuration defaults
    final srcCfg = edit?.sourceConfig ?? {};
    _documentType = edit?.documentType ?? srcCfg['documentType']?.toString() ?? 'Quotation';
    final rawFormat = srcCfg['pageFormat']?.toString();
    _pageFormat = (rawFormat != null && rawFormat.isNotEmpty) ? rawFormat : 'Letter';
    _pageMode = srcCfg['pageMode']?.toString() ?? 'PORTRAIT';
    _fontType = srcCfg['fontType']?.toString() ?? 'Helvetica';
    _status = edit?.status ?? srcCfg['status']?.toString() ?? 'Pending';
    _showSealSignatureArea = edit?.showSealSignatureArea ??
        (srcCfg['showSealSignatureArea'] == true || srcCfg['showSealSignatureArea']?.toString().toLowerCase() == 'true');

    _startDate = edit?.date ?? DateTime.now();
    if (edit?.dueDate != null) {
      _endDate = edit!.dueDate;
    } else if (srcCfg['endDate'] != null) {
      _endDate = DateTime.tryParse(srcCfg['endDate'].toString());
    }

    _marginTopCtrl = TextEditingController(text: (srcCfg['marginTop'] ?? 0).toString());
    _marginLeftCtrl = TextEditingController(text: (srcCfg['marginLeft'] ?? 0).toString());
    _marginRightCtrl = TextEditingController(text: (srcCfg['marginRight'] ?? 0).toString());
    _marginHeaderCtrl = TextEditingController(text: (srcCfg['marginHeader'] ?? 0).toString());
    _marginBottomCtrl = TextEditingController(text: (srcCfg['marginBottom'] ?? 0).toString());
    _autoPageBreakCtrl = TextEditingController(text: (srcCfg['autoPageBreak'] ?? 0).toString());

    // Document contents: use edited invoice values or clean blanks for new document
    final initialNum = edit?.invoiceNumber ?? InvoiceNumberService.generateInitialB2bNumber(_documentType, _startDate);
    _quotationNumCtrl = TextEditingController(
      text: initialNum,
    );
    if (edit == null) {
      InvoiceNumberService.fetchNextB2bDocumentNumber(_documentType, _startDate).then((newNumber) {
        if (mounted && (_quotationNumCtrl.text == initialNum || _quotationNumCtrl.text.isEmpty)) {
          setState(() {
            _quotationNumCtrl.text = newNumber;
          });
        }
      });
    }
    _recipientNameCtrl = TextEditingController(
      text: edit?.customerName.isNotEmpty == true ? edit!.customerName : '',
    );

    // Parse city & country
    String city = '';
    String country = '';
    if (edit?.customerAddress != null && edit!.customerAddress!.isNotEmpty) {
      final parts = edit.customerAddress!.split(RegExp(r'[,|\n]'));
      if (parts.isNotEmpty) city = parts.first.trim();
      if (parts.length > 1) country = parts.sublist(1).join(', ').trim();
    }
    _recipientCityCtrl = TextEditingController(text: city);
    _recipientCountryCtrl = TextEditingController(text: country);

    _subjectCtrl = TextEditingController(
      text: edit?.subject ??
          (edit?.description?.isNotEmpty == true
              ? edit!.description!
              : ''),
    );
    _salutationCtrl = TextEditingController(
      text: edit?.salutation?.isNotEmpty == true ? edit!.salutation! : 'Respected Sir,',
    );
    final isQuotation = _documentType.trim().toLowerCase() == 'quotation';
    String initialIntro = '';
    if (edit != null) {
      if (edit.introText != null && edit.introText!.isNotEmpty) {
        if (!isQuotation && edit.introText!.trim() == _defaultQuotationIntroText.trim()) {
          initialIntro = '';
        } else {
          initialIntro = edit.introText!;
        }
      } else if (isQuotation) {
        initialIntro = _defaultQuotationIntroText;
      }
    } else {
      initialIntro = isQuotation ? _defaultQuotationIntroText : '';
    }
    _introTextCtrl = TextEditingController(
      text: initialIntro,
    );
    _tableTitleCtrl = TextEditingController(
      text: edit?.tableHeaderTitle?.isNotEmpty == true ? edit!.tableHeaderTitle! : '',
    );
    _vatRateCtrl = TextEditingController(
      text: edit != null && edit.vatRate > 0 ? edit.vatRate.toStringAsFixed(0) : '10',
    );

    // Items initialization: clean empty row for new documents, or actual saved items if editing
    if (edit != null && edit.items.isNotEmpty) {
      for (final item in edit.items) {
        _itemRows.add(_B2bItemInputRow(
          classCtrl: TextEditingController(text: item.itemClass ?? ''),
          descriptionCtrl: TextEditingController(text: item.itemDescription),
          amountCtrl: TextEditingController(text: item.amount > 0 ? item.amount.toStringAsFixed(2) : ''),
        ));
      }
    } else {
      // Start with 1 clean empty item row for immediate user input
      _itemRows.add(_B2bItemInputRow(
        classCtrl: TextEditingController(),
        descriptionCtrl: TextEditingController(),
        amountCtrl: TextEditingController(),
      ));
    }

    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final res = await _supabase.from('customers').select('*').order('name');
      final list = (res as List).map((c) => Customer.fromJson(c as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _savedCustomers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _marginTopCtrl.dispose();
    _marginLeftCtrl.dispose();
    _marginRightCtrl.dispose();
    _marginHeaderCtrl.dispose();
    _marginBottomCtrl.dispose();
    _autoPageBreakCtrl.dispose();

    _quotationNumCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientCityCtrl.dispose();
    _recipientCountryCtrl.dispose();
    _subjectCtrl.dispose();
    _salutationCtrl.dispose();
    _introTextCtrl.dispose();
    _tableTitleCtrl.dispose();
    _vatRateCtrl.dispose();

    for (final row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ==================== FINANCIAL CALCULATIONS ====================
  double get _subtotal {
    double total = 0.0;
    for (final r in _itemRows) {
      final amt = double.tryParse(r.amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
      total += amt;
    }
    return total;
  }

  double get _vatRate => double.tryParse(_vatRateCtrl.text.trim()) ?? 10.0;

  double get _vatAmount => (_subtotal * _vatRate) / 100.0;

  double get _totalAmountOfWork => _subtotal + _vatAmount;

  String get _amountInWords => CurrencyWordsConverter.toBahrainiDinarsWords(_totalAmountOfWork);

  Invoice _buildCurrentInvoice() {
    final addressParts = [
      _recipientCityCtrl.text.trim(),
      _recipientCountryCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).toList();
    final fullAddress = addressParts.join('\n');

    final items = <InvoiceItem>[];
    for (int i = 0; i < _itemRows.length; i++) {
      final row = _itemRows[i];
      final itemClass = row.classCtrl.text.trim();
      final itemDesc = row.descriptionCtrl.text.trim();
      final amt = double.tryParse(row.amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
      if (_itemRows.length > 1 && itemClass.isEmpty && itemDesc.isEmpty && amt == 0.0) {
        continue;
      }
      items.add(InvoiceItem(
        itemClass: itemClass,
        itemDescription: itemDesc,
        quantity: 1,
        unitPrice: amt,
        amount: amt,
        sortOrder: i,
      ));
    }

    final sourceConfig = {
      'documentType': _documentType,
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'pageFormat': _pageFormat,
      'pageMode': _pageMode,
      'fontType': _fontType,
      'status': _status,
      'marginTop': double.tryParse(_marginTopCtrl.text.trim()) ?? 0,
      'marginLeft': double.tryParse(_marginLeftCtrl.text.trim()) ?? 0,
      'marginRight': double.tryParse(_marginRightCtrl.text.trim()) ?? 0,
      'marginHeader': double.tryParse(_marginHeaderCtrl.text.trim()) ?? 0,
      'marginBottom': double.tryParse(_marginBottomCtrl.text.trim()) ?? 0,
      'autoPageBreak': double.tryParse(_autoPageBreakCtrl.text.trim()) ?? 0,
      'showSealSignatureArea': _showSealSignatureArea,
    };

    return Invoice(
      id: widget.invoiceToEdit?.id ?? '',
      invoiceNumber: _quotationNumCtrl.text.trim(),
      date: _startDate,
      dueDate: _endDate,
      status: _status,
      customerId: _selectedCustomer?.id,
      customerName: _recipientNameCtrl.text.trim(),
      customerAddress: fullAddress,
      description: _subjectCtrl.text.trim(),
      subtotal: _subtotal,
      discount: 0,
      vatRate: _vatRate,
      vatAmount: _vatAmount,
      totalAmount: _totalAmountOfWork,
      items: items,
      createdAt: widget.invoiceToEdit?.createdAt ?? DateTime.now(),
      documentType: _documentType,
      subject: _subjectCtrl.text.trim(),
      salutation: _salutationCtrl.text.trim(),
      introText: _introTextCtrl.text.trim(),
      tableHeaderTitle: _tableTitleCtrl.text.trim(),
      sourceConfig: sourceConfig,
      showSealSignatureArea: _showSealSignatureArea,
    );
  }

  // ==================== ACTIONS ====================
  Future<void> _previewPdf() async {
    final invoice = _buildCurrentInvoice();
    try {
      final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(invoice);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text('${invoice.invoiceNumber} - Preview', style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF0A2540),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Print',
                  onPressed: () => Printing.layoutPdf(
                    name: '${invoice.invoiceNumber}.pdf',
                    onLayout: (_) => pdfBytes,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Share / Export PDF',
                  onPressed: () => Printing.sharePdf(
                    bytes: pdfBytes,
                    filename: '${invoice.invoiceNumber}.pdf',
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
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating preview: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _directPrint() async {
    final invoice = _buildCurrentInvoice();
    try {
      final pdfBytes = await B2bQuotationPdfGenerator.generatePdf(invoice);
      await Printing.layoutPdf(
        name: '${invoice.invoiceNumber}.pdf',
        onLayout: (_) => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening print dialog: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final invoice = _buildCurrentInvoice();

      Future<void> saveWithConfig({required bool useDedicatedColumns}) async {
        final invoicePayload = invoice.toJson(useDedicatedColumns: useDedicatedColumns);

        String invoiceId;
        if (widget.invoiceToEdit == null || widget.invoiceToEdit!.id.isEmpty) {
          final res = await _supabase.from('invoices').insert(invoicePayload).select('id').single();
          invoiceId = res['id'].toString();
        } else {
          invoiceId = widget.invoiceToEdit!.id;
          await _supabase.from('invoices').update(invoicePayload).eq('id', invoiceId);
          await _supabase.from('invoice_items').delete().eq('invoice_id', invoiceId);
        }

        final itemsToInsert = invoice.items.map((it) => it.toJson(
          parentInvoiceId: invoiceId,
          useDedicatedColumns: useDedicatedColumns,
        )).toList();

        if (itemsToInsert.isNotEmpty) {
          await _supabase.from('invoice_items').insert(itemsToInsert);
        }
      }

      try {
        await saveWithConfig(useDedicatedColumns: true);
      } catch (saveError) {
        final errStr = saveError.toString();
        if (errStr.contains('PGRST204') ||
            errStr.contains('document_type') ||
            errStr.contains('item_class') ||
            errStr.contains('schema cache') ||
            errStr.contains('column')) {
          // Automatic resilient fallback to standard schema
          await saveWithConfig(useDedicatedColumns: false);
        } else {
          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${invoice.invoiceNumber} saved successfully!'),
            backgroundColor: const Color(0xFF137333),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving document: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM/dd/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('B2B Quotation / Invoice Designer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined),
            tooltip: 'Live Document Preview',
            onPressed: _previewPdf,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Export',
            onPressed: _directPrint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveInvoice,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ==================== CARD 1: SOURCE (MATCHING IMAGE 2) ====================
                  _buildSourceCard(df),

                  const SizedBox(height: 18),

                  // ==================== CARD 2: DOCUMENT & RECIPIENT ====================
                  _buildRecipientCard(),

                  const SizedBox(height: 18),

                  // ==================== CARD 3: SUBJECT & LETTER BODY ====================
                  _buildSubjectAndBodyCard(),

                  const SizedBox(height: 18),

                  // ==================== CARD 4: BOQ ITEMS & ADD ITEM ====================
                  _buildBoqItemsCard(),

                  const SizedBox(height: 18),

                  // ==================== CARD 5: FINANCIAL SUMMARY & WORDS ====================
                  _buildFinancialSummaryCard(),

                  const SizedBox(height: 18),

                  // ==================== CARD 6: SEAL & SIGNATURE AREA ====================
                  _buildSealAndSignatureCard(),

                  const SizedBox(height: 32),

                  // Large Preview & Export Action Button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF0A2540), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _previewPdf,
                          icon: const Icon(Icons.visibility_rounded, color: Color(0xFF0A2540)),
                          label: const Text(
                            'Full Screen PDF Preview',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A2540),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _directPrint,
                          icon: const Icon(Icons.print_rounded),
                          label: const Text(
                            'Print / Export PDF',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ==================== CARD 1: DOCUMENT INFO & DATE (TOP SECTION) ====================
  Widget _buildSourceCard(DateFormat df) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cyan/soft-blue accent
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
                top: BorderSide(color: Color(0xFF38BDF8), width: 3),
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              'Document Information',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 380;
                final docNameField = _buildFormFieldWrapper(
                  label: 'DOCUMENT NAME',
                  child: _buildDropdownContainer(
                    value: _documentType,
                    items: _documentTypeOptions,
                    onChanged: (v) {
                      if (v != null) {
                        final oldPrefix = InvoiceNumberService.getPrefixForType(_documentType);
                        final newPrefix = InvoiceNumberService.getPrefixForType(v);
                        setState(() {
                          _documentType = v;
                          if (widget.invoiceToEdit == null) {
                            if (_quotationNumCtrl.text.isEmpty || _quotationNumCtrl.text.startsWith(oldPrefix)) {
                              _quotationNumCtrl.text = _quotationNumCtrl.text.replaceFirst(oldPrefix, newPrefix);
                              if (!_quotationNumCtrl.text.startsWith(newPrefix)) {
                                _quotationNumCtrl.text = InvoiceNumberService.generateInitialB2bNumber(v, _startDate);
                              }
                            }
                          }

                          // Prefill introductory letter ONLY for Quotation; make blank for other document names
                          final isNowQuotation = v.trim().toLowerCase() == 'quotation';
                          if (isNowQuotation) {
                            if (_introTextCtrl.text.trim().isEmpty) {
                              _introTextCtrl.text = _defaultQuotationIntroText;
                            }
                          } else {
                            if (_introTextCtrl.text.trim() == _defaultQuotationIntroText.trim()) {
                              _introTextCtrl.text = '';
                            }
                          }
                        });
                        if (widget.invoiceToEdit == null) {
                          InvoiceNumberService.fetchNextB2bDocumentNumber(v, _startDate).then((newNumber) {
                            if (mounted && widget.invoiceToEdit == null) {
                              setState(() {
                                _quotationNumCtrl.text = newNumber;
                              });
                            }
                          });
                        }
                      }
                    },
                  ),
                );

                final startDateField = _buildFormFieldWrapper(
                  label: 'START DATE',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(df.format(_startDate), style: const TextStyle(fontSize: 13.5)),
                          const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      docNameField,
                      const SizedBox(height: 14),
                      startDateField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: docNameField),
                    const SizedBox(width: 14),
                    Expanded(child: startDateField),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CARD 2: RECIPIENT & METADATA ====================
  Widget _buildRecipientCard() {
    return _buildSectionBox(
      title: 'Quotation Number & Recipient Details ("To:")',
      icon: Icons.business_center_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _quotationNumCtrl,
                  decoration: InputDecoration(
                    labelText: _documentType == 'Quotation'
                        ? 'Quotation No *'
                        : (_documentType == 'Tax Invoice' || _documentType == 'B2B' ? 'Invoice No *' : '$_documentType No *'),
                    hintText: 'e.g. ${InvoiceNumberService.generateInitialB2bNumber(_documentType, _startDate)}',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Auto-generate number',
                      onPressed: () async {
                        final num = await InvoiceNumberService.fetchNextB2bDocumentNumber(_documentType, _startDate);
                        if (mounted) {
                          setState(() {
                            _quotationNumCtrl.text = num;
                          });
                        }
                      },
                    ),
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              if (_savedCustomers.isNotEmpty)
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<Customer>(
                    initialValue: _selectedCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Quick Pick Customer',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _savedCustomers.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (c) {
                      if (c == null) return;
                      setState(() {
                        _selectedCustomer = c;
                        _recipientNameCtrl.text = c.name;
                        if (c.address != null && c.address!.isNotEmpty) {
                          final parts = c.address!.split(RegExp(r'[,|\n]'));
                          if (parts.isNotEmpty) _recipientCityCtrl.text = parts.first.trim();
                          if (parts.length > 1) _recipientCountryCtrl.text = parts.sublist(1).join(', ').trim();
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _recipientNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Recipient / Customer Name *',
              hintText: 'e.g. Kingdom Asphalt W.L.L,',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _recipientCityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City / Area',
                    hintText: 'e.g. Manama,',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _recipientCountryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    hintText: 'e.g. Kingdom of Bahrain.',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CARD 3: SUBJECT & LETTER BODY ====================
  Widget _buildSubjectAndBodyCard() {
    return _buildSectionBox(
      title: 'Subject Line & Introductory Letter',
      icon: Icons.mail_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject Line * (Underlined on Quotation)',
              hintText: 'e.g. REVISED QUOTATION FOR STORM WATER IMPROVEMENT OF HIGHWAY 96...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _salutationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Salutation',
                    hintText: 'e.g. Respected Sir,',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _tableTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Table Heading / Project Title',
                    hintText: 'e.g. STORM WATER HIGHWAY 96',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _introTextCtrl,
            decoration: InputDecoration(
              labelText: _documentType == 'Quotation'
                  ? 'Introductory Intent Letter Paragraph'
                  : 'Introductory Letter (Blank unless specified)',
              hintText: _documentType == 'Quotation'
                  ? null
                  : 'Leave blank or enter custom introductory notes...',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ==================== CARD 4: BOQ LINE ITEMS & ADD ITEMS ====================
  Widget _buildBoqItemsCard() {
    return _buildSectionBox(
      title: 'BOQ Line Items & Rates Table',
      icon: Icons.table_chart_outlined,
      headerAction: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A2540),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () {
          setState(() {
            _itemRows.add(_B2bItemInputRow(
              classCtrl: TextEditingController(),
              descriptionCtrl: TextEditingController(),
              amountCtrl: TextEditingController(),
            ));
          });
        },
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2540),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                SizedBox(width: 60, child: Text('CLASS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 12),
                Expanded(child: Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 12),
                SizedBox(width: 120, child: Text('Total Amount (BHD)', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Items rows
          for (int i = 0; i < _itemRows.length; i++) ...[
            _buildItemRowCard(i),
            if (i < _itemRows.length - 1) const SizedBox(height: 8),
          ],

          if (_itemRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _itemRows.add(_B2bItemInputRow(
                        classCtrl: TextEditingController(),
                        descriptionCtrl: TextEditingController(),
                        amountCtrl: TextEditingController(),
                      ));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Line Item'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRowCard(int index) {
    final row = _itemRows[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // CLASS Field
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: row.classCtrl,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'e.g. I',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Description Field
          Expanded(
            child: TextFormField(
              controller: row.descriptionCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. PIPEWORK - PIPES',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 12),

          // Total Amount Field
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: row.amountCtrl,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 6),

          // Remove Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            onPressed: () {
              setState(() {
                row.dispose();
                _itemRows.removeAt(index);
              });
            },
            tooltip: 'Remove Row',
          ),
        ],
      ),
    );
  }

  // ==================== CARD 5: FINANCIAL SUMMARY & WORDS ====================
  Widget _buildFinancialSummaryCard() {
    return _buildSectionBox(
      title: 'Financial Breakdown & Words Representation',
      icon: Icons.calculate_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _vatRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'VAT Rate (%)',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildCalcRow('Total (Subtotal):', _currFormat.format(_subtotal)),
                      const SizedBox(height: 6),
                      _buildCalcRow('VAT ${_vatRate.toStringAsFixed(0)}%:', _currFormat.format(_vatAmount)),
                      const Divider(height: 14),
                      _buildCalcRow('Total Amount of Work:', _currFormat.format(_totalAmountOfWork), isBold: true),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Amount in Words Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DOCUMENT TEXT PREVIEW:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our total price shall be BHD ${_currFormat.format(_totalAmountOfWork)} ($_amountInWords)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CARD 6: SEAL & SIGNATURE AREA ====================
  Widget _buildSealAndSignatureCard() {
    return _buildSectionBox(
      title: 'Physical Seal & Signature Area',
      icon: Icons.draw_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Include Seal & Signature Area on PDF',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Adds boxes for Customer\'s Seal & Signature and Al Nadheera Authorised Signatory for physical stamping & signing',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            value: _showSealSignatureArea,
            activeTrackColor: const Color(0xFF0A2540),
            onChanged: (val) => setState(() => _showSealSignatureArea = val),
          ),
          if (_showSealSignatureArea) ...[
            const SizedBox(height: 12),
            const Text(
              'AREA PREVIEW ON PDF:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                color: Colors.white,
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
                        height: 85,
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
                        height: 85,
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
            ),
          ],
        ],
      ),
    );
  }

  // ==================== REUSABLE UI HELPERS ====================
  Widget _buildSectionBox({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? headerAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0A2540)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                ),
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildFormFieldWrapper({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDropdownContainer({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Collect unique items ensuring case-insensitive uniqueness
    final uniqueItems = <String>[];
    for (final i in items) {
      if (!uniqueItems.any((u) => u.toLowerCase() == i.toLowerCase())) {
        uniqueItems.add(i);
      }
    }

    // Match selected value safely
    String selectedValue = value;
    final matchIdx = uniqueItems.indexWhere((u) => u.toLowerCase() == value.toLowerCase());
    if (matchIdx != -1) {
      selectedValue = uniqueItems[matchIdx];
    } else if (value.isNotEmpty) {
      uniqueItems.add(value);
      selectedValue = value;
    } else if (uniqueItems.isNotEmpty) {
      selectedValue = uniqueItems.first;
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          items: uniqueItems.map((i) {
            return DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF0A2540) : Colors.black87,
          ),
        ),
        Text(
          'BHD $value',
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFF0A2540) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _B2bItemInputRow {
  final TextEditingController classCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController amountCtrl;

  _B2bItemInputRow({
    required this.classCtrl,
    required this.descriptionCtrl,
    required this.amountCtrl,
  });

  void dispose() {
    classCtrl.dispose();
    descriptionCtrl.dispose();
    amountCtrl.dispose();
  }
}
