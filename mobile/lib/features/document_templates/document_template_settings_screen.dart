import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../../models/document_template_model.dart';
import '../../models/invoice_model.dart';
import '../../services/document_template_service.dart';
import '../invoices/invoice_pdf_generator.dart';

class DocumentTemplateSettingsScreen extends StatefulWidget {
  const DocumentTemplateSettingsScreen({super.key});

  @override
  State<DocumentTemplateSettingsScreen> createState() =>
      _DocumentTemplateSettingsScreenState();
}

class _DocumentTemplateSettingsScreenState
    extends State<DocumentTemplateSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = DocumentTemplateService.instance;
  final _picker = ImagePicker();

  late TabController _tabController;
  final List<String> _templateKeys = ['invoice', 'vat_statement', 'receipt', 'quotation'];
  final List<String> _templateLabels = ['Invoices', 'VAT Report', 'Receipts', 'Quotations'];

  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for active template
  late TextEditingController _nameEnCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _crCtrl;
  late TextEditingController _vatCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNameCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _swiftCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _footerCtrl;

  String? _logoUrl;
  String? _sealUrl;
  String? _signatureUrl;
  String _primaryColor = '#0A2540';
  String _accentColor = '#0B5ED7';
  bool _showSeal = true;
  bool _showSignature = true;
  bool _showBankDetails = true;

  final List<Color> _colorOptions = const [
    Color(0xFF0A2540), // Classic Dark Navy
    Color(0xFF0B5ED7), // Royal Blue
    Color(0xFF137333), // Construction Forest Green
    Color(0xFFB31412), // Deep Maroon / Crimson
    Color(0xFF475569), // Industrial Slate
    Color(0xFF5B21B6), // Corporate Purple
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _templateKeys.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });

    _initControllers();
    _loadTemplates();
  }

  void _initControllers() {
    _nameEnCtrl = TextEditingController();
    _nameArCtrl = TextEditingController();
    _taglineCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _crCtrl = TextEditingController();
    _vatCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _accountNameCtrl = TextEditingController();
    _ibanCtrl = TextEditingController();
    _swiftCtrl = TextEditingController();
    _termsCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    await _service.loadTemplates();
    _populateFieldsForType(_templateKeys[_selectedTabIndex]);
    setState(() => _isLoading = false);
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
      _populateFieldsForType(_templateKeys[index]);
    });
  }

  void _populateFieldsForType(String type) {
    final t = _service.getTemplate(type);

    _nameEnCtrl.text = t.companyNameEn;
    _nameArCtrl.text = t.companyNameAr ?? '';
    _taglineCtrl.text = t.tagline ?? '';
    _addressCtrl.text = t.address;
    _phoneCtrl.text = t.phone;
    _emailCtrl.text = t.email;
    _websiteCtrl.text = t.website ?? '';
    _crCtrl.text = t.crNumber ?? '';
    _vatCtrl.text = t.vatNumber ?? '';
    _bankNameCtrl.text = t.bankName ?? '';
    _accountNameCtrl.text = t.accountName ?? '';
    _ibanCtrl.text = t.iban ?? '';
    _swiftCtrl.text = t.swiftCode ?? '';
    _termsCtrl.text = t.termsAndConditions ?? '';
    _footerCtrl.text = t.footerText ?? '';

    _logoUrl = t.logoUrl;
    _sealUrl = t.sealUrl;
    _signatureUrl = t.signatureUrl;
    _primaryColor = t.primaryColor;
    _accentColor = t.accentColor;
    _showSeal = t.showSeal;
    _showSignature = t.showSignature;
    _showBankDetails = t.showBankDetails;
  }

  DocumentTemplate _buildCurrentTemplate() {
    final currentKey = _templateKeys[_selectedTabIndex];
    final existing = _service.getTemplate(currentKey);

    return existing.copyWith(
      companyNameEn: _nameEnCtrl.text.trim(),
      companyNameAr: _nameArCtrl.text.trim().isEmpty ? null : _nameArCtrl.text.trim(),
      tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
      logoUrl: _logoUrl,
      sealUrl: _sealUrl,
      signatureUrl: _signatureUrl,
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      crNumber: _crCtrl.text.trim().isEmpty ? null : _crCtrl.text.trim(),
      vatNumber: _vatCtrl.text.trim().isEmpty ? null : _vatCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      accountName: _accountNameCtrl.text.trim().isEmpty ? null : _accountNameCtrl.text.trim(),
      iban: _ibanCtrl.text.trim().isEmpty ? null : _ibanCtrl.text.trim(),
      swiftCode: _swiftCtrl.text.trim().isEmpty ? null : _swiftCtrl.text.trim(),
      termsAndConditions: _termsCtrl.text.trim().isEmpty ? null : _termsCtrl.text.trim(),
      footerText: _footerCtrl.text.trim().isEmpty ? null : _footerCtrl.text.trim(),
      primaryColor: _primaryColor,
      accentColor: _accentColor,
      showSeal: _showSeal,
      showSignature: _showSignature,
      showBankDetails: _showBankDetails,
      isDefault: true,
    );
  }

  Future<void> _pickAndUploadAsset(String assetType) async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      setState(() => _isSaving = true);
      final bytes = await file.readAsBytes();
      final url = await _service.uploadAssetImage(
        bytes: bytes,
        fileName: file.name,
        assetType: assetType,
      );

      if (url != null) {
        setState(() {
          if (assetType == 'logo') _logoUrl = url;
          if (assetType == 'seal') _sealUrl = url;
          if (assetType == 'signature') _signatureUrl = url;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${assetType.toUpperCase()} uploaded successfully!'),
              backgroundColor: const Color(0xFF137333),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload $assetType')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCurrentTemplate() async {
    setState(() => _isSaving = true);
    final tmpl = _buildCurrentTemplate();
    final ok = await _service.saveTemplate(tmpl);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '${_templateLabels[_selectedTabIndex]} template saved as default!'
              : 'Failed to save template'),
          backgroundColor: ok ? const Color(0xFF137333) : const Color(0xFFD93025),
        ),
      );
    }
  }

  Future<void> _applyToAllTemplates() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apply To All Templates?'),
        content: const Text(
          'This will copy the current company name, logo, seal, signature, address, and registration numbers across all document formats (Invoices, VAT Reports, Receipts, Quotations).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2540)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply To All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    final current = _buildCurrentTemplate();

    for (final key in _templateKeys) {
      final existing = _service.getTemplate(key);
      final updated = existing.copyWith(
        companyNameEn: current.companyNameEn,
        companyNameAr: current.companyNameAr,
        logoUrl: current.logoUrl,
        sealUrl: current.sealUrl,
        signatureUrl: current.signatureUrl,
        address: current.address,
        phone: current.phone,
        email: current.email,
        website: current.website,
        crNumber: current.crNumber,
        vatNumber: current.vatNumber,
        bankName: current.bankName,
        accountName: current.accountName,
        iban: current.iban,
        swiftCode: current.swiftCode,
        footerText: current.footerText,
        showSeal: current.showSeal,
        showSignature: current.showSignature,
        showBankDetails: current.showBankDetails,
        isDefault: true,
      );
      await _service.saveTemplate(updated);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default formatting applied across all document templates!'),
          backgroundColor: Color(0xFF137333),
        ),
      );
    }
  }

  Future<void> _previewSamplePdf() async {
    final template = _buildCurrentTemplate();

    // Create a mock invoice to render live preview
    final sampleInvoice = Invoice(
      id: 'sample',
      invoiceNumber: 'INV-${DateTime.now().year}-PREVIEW',
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 14)),
      status: 'Paid',
      customerName: 'Sample Client W.L.L',
      customerPhone: '+973 3311 2233',
      customerAddress: 'Building 102, Road 402, Seef District, Bahrain',
      customerVatNumber: '200098765400003',
      siteName: 'Al Hidd Residential Project',
      description: 'Sample Bill Preview using custom template settings',
      subtotal: 1500.000,
      discount: 100.000,
      discountType: 'amount',
      vatRate: 10.0,
      vatAmount: 140.000,
      totalAmount: 1540.000,
      notes: template.termsAndConditions,
      paymentTerms: 'Bank Wire / Cheque',
      items: [
        InvoiceItem(
          itemDescription: 'Excavation & Ground Preparation Works',
          quantity: 1,
          unitPrice: 850.000,
          amount: 850.000,
        ),
        InvoiceItem(
          itemDescription: 'Reinforced Concrete Foundation Works',
          quantity: 1,
          unitPrice: 650.000,
          amount: 650.000,
        ),
      ],
      createdAt: DateTime.now(),
    );

    try {
      final pdfBytes = await InvoicePdfGenerator.generateInvoicePdf(
        sampleInvoice,
        customTemplate: template,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text('${_templateLabels[_selectedTabIndex]} - Print Preview'),
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                actions: [
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
                pdfFileName: 'template_preview.pdf',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate preview: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    _taglineCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _crCtrl.dispose();
    _vatCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNameCtrl.dispose();
    _ibanCtrl.dispose();
    _swiftCtrl.dispose();
    _termsCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Document & Print Formats', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0A2540),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0A2540),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            for (final label in _templateLabels)
              Tab(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined),
            tooltip: 'Live Preview',
            onPressed: _previewSamplePdf,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save Format',
            onPressed: _isSaving ? null : _saveCurrentTemplate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Action Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2540).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0A2540).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF0A2540), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Editing default print format for: ${_templateLabels[_selectedTabIndex]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0B5ED7),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _applyToAllTemplates,
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Apply to All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 1. Assets Upload Section (Logo, Seal, Signature)
                _buildCardSection(
                  title: 'Official Branding Assets (Logo, Seal, Signature)',
                  icon: Icons.verified_rounded,
                  child: Column(
                    children: [
                      // Logo Uploader Card
                      _buildAssetUploadTile(
                        title: 'Company Logo',
                        subtitle: 'Upload transparent PNG or JPG logo header',
                        imageUrl: _logoUrl,
                        icon: Icons.image_rounded,
                        onUpload: () => _pickAndUploadAsset('logo'),
                        onClear: () => setState(() => _logoUrl = null),
                      ),
                      const Divider(height: 20),

                      // Official Seal Uploader Card
                      _buildAssetUploadTile(
                        title: 'Official Company Seal / Stamp',
                        subtitle: 'Circular or official stamp image for bills',
                        imageUrl: _sealUrl,
                        icon: Icons.shield_rounded,
                        onUpload: () => _pickAndUploadAsset('seal'),
                        onClear: () => setState(() => _sealUrl = null),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include Official Seal on Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Renders official seal on the PDF statement', style: TextStyle(fontSize: 11)),
                        value: _showSeal,
                        activeThumbColor: const Color(0xFF0A2540),
                        onChanged: (v) => setState(() => _showSeal = v),
                      ),
                      const Divider(height: 20),

                      // Authorized Signature Uploader Card
                      _buildAssetUploadTile(
                        title: 'Authorized Signature',
                        subtitle: 'Digital management signature image',
                        imageUrl: _signatureUrl,
                        icon: Icons.draw_rounded,
                        onUpload: () => _pickAndUploadAsset('signature'),
                        onClear: () => setState(() => _signatureUrl = null),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include Signature Block on Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Places signature line on the bill footer', style: TextStyle(fontSize: 11)),
                        value: _showSignature,
                        activeThumbColor: const Color(0xFF0A2540),
                        onChanged: (v) => setState(() => _showSignature = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Company Information
                _buildCardSection(
                  title: 'Company Information',
                  icon: Icons.business_rounded,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameEnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name (English) *',
                          prefixIcon: Icon(Icons.apartment_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameArCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name (Arabic / Optional)',
                          prefixIcon: Icon(Icons.language_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _taglineCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tagline / Sub-heading',
                          hintText: 'Civil Engineering & General Contracting',
                          prefixIcon: Icon(Icons.short_text_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Primary Color Palette
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Document Header Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          for (final c in _colorOptions) ...[
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _primaryColor = '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _primaryColor == '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}'
                                        ? Colors.black
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Official Address & Contact
                _buildCardSection(
                  title: 'Address & Contact Details',
                  icon: Icons.contact_mail_rounded,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Office Address *',
                          prefixIcon: Icon(Icons.location_on_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone / Tel *',
                                prefixIcon: Icon(Icons.phone_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                prefixIcon: Icon(Icons.email_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _crCtrl,
                              decoration: const InputDecoration(
                                labelText: 'CR Number',
                                prefixIcon: Icon(Icons.badge_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _vatCtrl,
                              decoration: const InputDecoration(
                                labelText: 'VAT Account No',
                                prefixIcon: Icon(Icons.tag_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _websiteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Website (Optional)',
                          prefixIcon: Icon(Icons.public_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Bank Information
                _buildCardSection(
                  title: 'Banking & Payment Transfer Details',
                  icon: Icons.account_balance_rounded,
                  headerAction: Switch(
                    value: _showBankDetails,
                    activeThumbColor: const Color(0xFF0A2540),
                    onChanged: (v) => setState(() => _showBankDetails = v),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _bankNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _accountNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Account Beneficiary Name',
                          prefixIcon: Icon(Icons.person_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _ibanCtrl,
                              decoration: const InputDecoration(
                                labelText: 'IBAN Number',
                                prefixIcon: Icon(Icons.credit_card_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _swiftCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SWIFT Code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Terms & Footer Notes
                _buildCardSection(
                  title: 'Default Terms & Footer Note',
                  icon: Icons.notes_rounded,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _termsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Default Terms & Conditions',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _footerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Document Footer Note',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bottom Buttons: Preview & Save as Default
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0A2540),
                          side: const BorderSide(color: Color(0xFF0A2540)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _previewSamplePdf,
                        icon: const Icon(Icons.remove_red_eye_rounded),
                        label: const Text('Live PDF Preview', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        onPressed: _isSaving ? null : _saveCurrentTemplate,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save as Default',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildAssetUploadTile({
    required String title,
    required String subtitle,
    required String? imageUrl,
    required IconData icon,
    required VoidCallback onUpload,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        // Preview thumbnail
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(icon, color: const Color(0xFF94A3B8)),
                  ),
                )
              : Icon(icon, color: const Color(0xFF94A3B8), size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        if (imageUrl != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            tooltip: 'Remove',
            onPressed: onClear,
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A2540),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onUpload,
          child: Text(imageUrl == null ? 'Upload' : 'Change', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    Widget? headerAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF0A2540)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                ],
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
