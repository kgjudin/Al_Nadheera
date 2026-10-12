import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/document_template_model.dart';
import '../../models/invoice_model.dart';
import '../../models/template_layout_config.dart';
import '../../services/document_template_service.dart';
import '../invoices/invoice_pdf_generator.dart';

class LivePdfTemplateDesignerScreen extends StatefulWidget {
  final DocumentTemplate initialTemplate;
  final Invoice? invoice;
  final String templateKey;
  final ValueChanged<DocumentTemplate>? onTemplateSaved;

  const LivePdfTemplateDesignerScreen({
    super.key,
    required this.initialTemplate,
    this.invoice,
    required this.templateKey,
    this.onTemplateSaved,
  });

  @override
  State<LivePdfTemplateDesignerScreen> createState() =>
      _LivePdfTemplateDesignerScreenState();
}

class _LivePdfTemplateDesignerScreenState
    extends State<LivePdfTemplateDesignerScreen> {
  late DocumentTemplate _template;
  late Invoice _invoice;
  int _renderVersion = 0;
  bool _isSaving = false;
  int _activeDesignerTab = 0; // 0: Header, 1: Bill To, 2: Table, 3: Signatures, 4: Margins

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _invoice = widget.invoice ?? _generateSampleInvoice();
  }

  Invoice _generateSampleInvoice() {
    return Invoice(
      id: 'preview-inv-01',
      invoiceNumber: 'INV-2026-0042',
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 14)),
      status: 'Pending',
      customerName: 'Bahrain Real Estate Development Co.',
      customerPhone: '+973 1782 9900',
      customerAddress: 'Building 450, Road 2814, Seef District, Bahrain',
      customerVatNumber: 'VAT-BH-991827364',
      siteName: 'Seef Tower Commercial Center',
      description: 'Monthly Substructure Works & Concrete Pouring - Phase 2',
      subtotal: 1250.000,
      vatRate: 10,
      vatAmount: 125.000,
      totalAmount: 1375.000,
      discount: 0.0,
      notes: 'Payment received via Bank Transfer. Official receipt issued under CR 142857-1.',
      items: [
        InvoiceItem(
          itemDescription: 'Supply & Pouring of Ready Mix Grade C40 Concrete (45 m³)',
          quantity: 45,
          unitPrice: 15.000,
          amount: 675.000,
        ),
        InvoiceItem(
          itemDescription: 'Steel Reinforcement Fixing & Bending (High Tensile Grade)',
          quantity: 2.5,
          unitPrice: 180.000,
          amount: 450.000,
        ),
        InvoiceItem(
          itemDescription: 'Surface Vibrating, Curing & Quality Control Inspection',
          quantity: 1,
          unitPrice: 125.000,
          amount: 125.000,
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  void _updateConfig(TemplateLayoutConfig Function(TemplateLayoutConfig current) update) {
    setState(() {
      final newConfig = update(_template.layoutConfig);
      _template = _template.copyWith(layoutConfig: newConfig);
      _renderVersion++;
    });
  }

  Future<void> _saveTemplate() async {
    setState(() => _isSaving = true);
    try {
      final success = await DocumentTemplateService.instance.saveTemplate(_template);
      if (mounted) {
        if (success) {
          widget.onTemplateSaved?.call(_template);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${_template.templateName} layout saved successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF137333),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save template layout to cloud. Cached locally.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_template.templateName} - Studio',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text(
              'Live Alignment & Position Customizer',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Template'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 900;

          if (isWideScreen) {
            // Tablet / Desktop side-by-side view
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildLivePdfPreview(),
                ),
                Container(width: 1, color: const Color(0xFF1E293B)),
                SizedBox(
                  width: 380,
                  child: _buildControlsInspector(),
                ),
              ],
            );
          } else {
            // Mobile stacked view with collapsible bottom controls
            return Column(
              children: [
                Expanded(
                  child: _buildLivePdfPreview(),
                ),
                _buildMobileControlsDrawer(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildLivePdfPreview() {
    final isPending = _invoice.status.toLowerCase() != 'paid';

    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Quick Status Preview Toggle Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Color(0xFF94A3B8), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Preview Status:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _invoice = _invoice.copyWith(status: 'Pending');
                          _renderVersion++;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending ? const Color(0xFFD93025) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending) const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            if (isPending) const SizedBox(width: 4),
                            Text(
                              'Pending Payment',
                              style: TextStyle(
                                color: isPending ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _invoice = _invoice.copyWith(status: 'Paid');
                          _renderVersion++;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !isPending ? const Color(0xFF137333) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPending) const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            if (!isPending) const SizedBox(width: 4),
                            Text(
                              'Paid',
                              style: TextStyle(
                                color: !isPending ? Colors.white : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: !isPending ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey('preview-$_renderVersion'),
              build: (format) => InvoicePdfGenerator.generateInvoicePdf(
                _invoice,
                customTemplate: _template,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: '${_template.templateType}_template.pdf',
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: (context, build, pageFormat) {
                    setState(() => _renderVersion++);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileControlsDrawer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drawer Drag Handle & Section Tabs
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildTabChip(0, Icons.view_headline_rounded, 'Header & Logo'),
                  _buildTabChip(1, Icons.badge_outlined, 'Client & Meta'),
                  _buildTabChip(2, Icons.table_chart_outlined, 'Table & Totals'),
                  _buildTabChip(3, Icons.draw_outlined, 'Signatures & Seal'),
                  _buildTabChip(4, Icons.aspect_ratio_rounded, 'Margins & Footer'),
                ],
              ),
            ),
            const Divider(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                child: _buildActiveControlsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, IconData icon, String label) {
    final isSelected = _activeDesignerTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF0A2540)),
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedColor: const Color(0xFF0A2540),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0A2540)),
        onSelected: (_) => setState(() => _activeDesignerTab = index),
      ),
    );
  }

  Widget _buildControlsInspector() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF0A2540), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Template Alignment Studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2540)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildTabChip(0, Icons.view_headline_rounded, 'Header'),
                _buildTabChip(1, Icons.badge_outlined, 'Client Info'),
                _buildTabChip(2, Icons.table_chart_outlined, 'Table'),
                _buildTabChip(3, Icons.draw_outlined, 'Signatures'),
                _buildTabChip(4, Icons.aspect_ratio_rounded, 'Page'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildActiveControlsContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControlsContent() {
    switch (_activeDesignerTab) {
      case 0:
        return _buildHeaderControls();
      case 1:
        return _buildClientAndMetaControls();
      case 2:
        return _buildTableAndTotalsControls();
      case 3:
        return _buildSignaturesAndBankControls();
      case 4:
        return _buildMarginsAndFooterControls();
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. Header & Logo Controls
  Widget _buildHeaderControls() {
    final cfg = _template.layoutConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Header Layout & Style'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Layout Orientation',
          options: const [
            {'value': 'modern_split', 'label': 'Modern Split', 'desc': 'Logo/Info Left, Badge Right'},
            {'value': 'centered', 'label': 'Centered', 'desc': 'Symmetric centered logo & info'},
            {'value': 'reversed', 'label': 'Reversed', 'desc': 'Badge Left, Company Right'},
            {'value': 'minimal_bar', 'label': 'Accent Bar', 'desc': 'Full-width colored banner'},
          ],
          currentValue: cfg.headerLayout,
          onChanged: (val) => _updateConfig((c) => c.copyWith(headerLayout: val)),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Logo Alignment & Sizing'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Logo Position',
          options: const [
            {'value': 'left', 'label': 'Show Logo', 'desc': 'Standard logo display'},
            {'value': 'none', 'label': 'Hide Logo', 'desc': 'Show company text only'},
          ],
          currentValue: cfg.logoPosition,
          onChanged: (val) => _updateConfig((c) => c.copyWith(logoPosition: val)),
        ),
        const SizedBox(height: 10),
        _buildOptionSelector<String>(
          label: 'Logo Scale',
          options: const [
            {'value': 'small', 'label': 'Compact (36px)', 'desc': 'Saves vertical room'},
            {'value': 'medium', 'label': 'Standard (50px)', 'desc': 'Balanced proportion'},
            {'value': 'large', 'label': 'Prominent (66px)', 'desc': 'Bold branding'},
          ],
          currentValue: cfg.logoSize,
          onChanged: (val) => _updateConfig((c) => c.copyWith(logoSize: val)),
        ),
      ],
    );
  }

  // 2. Client & Meta Controls
  Widget _buildClientAndMetaControls() {
    final cfg = _template.layoutConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Client (Bill To) & Details Placement'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Arrangement Mode',
          options: const [
            {'value': 'split', 'label': 'Side-by-Side', 'desc': 'Bill To on Left, Details on Right'},
            {'value': 'reversed_split', 'label': 'Swapped', 'desc': 'Details on Left, Bill To on Right'},
            {'value': 'stacked', 'label': 'Stacked', 'desc': 'Bill To full width, details below'},
          ],
          currentValue: cfg.metaLayout,
          onChanged: (val) => _updateConfig((c) => c.copyWith(metaLayout: val)),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Bill To Card Decoration'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Card Style',
          options: const [
            {'value': 'card', 'label': 'Tinted Box', 'desc': 'Soft shaded background with border'},
            {'value': 'accent_border', 'label': 'Accent Bar', 'desc': 'Bold vertical line in primary color'},
            {'value': 'clean', 'label': 'Clean Minimal', 'desc': 'Plain background without borders'},
          ],
          currentValue: cfg.billToStyle,
          onChanged: (val) => _updateConfig((c) => c.copyWith(billToStyle: val)),
        ),
      ],
    );
  }

  // 3. Table & Totals Controls
  Widget _buildTableAndTotalsControls() {
    final cfg = _template.layoutConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Items Table Design'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Header Appearance',
          options: const [
            {'value': 'primary_filled', 'label': 'Solid Color', 'desc': 'Full primary color background'},
            {'value': 'tinted', 'label': 'Soft Tint', 'desc': 'Subtle light grey-blue tint'},
            {'value': 'minimal', 'label': 'Minimal Lines', 'desc': 'Top and bottom outline rules'},
          ],
          currentValue: cfg.tableHeaderStyle,
          onChanged: (val) => _updateConfig((c) => c.copyWith(tableHeaderStyle: val)),
        ),
        const SizedBox(height: 10),
        _buildOptionSelector<String>(
          label: 'Row Spacing & Density',
          options: const [
            {'value': 'compact', 'label': 'Compact', 'desc': 'Tight rows for multi-item invoices'},
            {'value': 'standard', 'label': 'Standard', 'desc': 'Balanced readability'},
            {'value': 'spacious', 'label': 'Spacious', 'desc': 'Executive open spacing'},
          ],
          currentValue: cfg.tableDensity,
          onChanged: (val) => _updateConfig((c) => c.copyWith(tableDensity: val)),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Alternate Row Shading (Zebra)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Light grey background on even rows', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: cfg.tableZebraStripes,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) => _updateConfig((c) => c.copyWith(tableZebraStripes: val)),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Totals & Calculations Alignment'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Totals Card Position',
          options: const [
            {'value': 'right', 'label': 'Right Aligned', 'desc': 'Traditional right-side summary'},
            {'value': 'left', 'label': 'Left Aligned', 'desc': 'Summary on left side'},
            {'value': 'full_width', 'label': 'Full Width', 'desc': 'Spans full page width'},
          ],
          currentValue: cfg.totalsPosition,
          onChanged: (val) => _updateConfig((c) => c.copyWith(totalsPosition: val)),
        ),
      ],
    );
  }

  // 4. Signatures & Bank Details Controls
  Widget _buildSignaturesAndBankControls() {
    final cfg = _template.layoutConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Seal & Signature Placement'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Alignment Mode',
          options: const [
            {'value': 'split', 'label': 'Split Ends', 'desc': 'Signature left, Seal right'},
            {'value': 'right', 'label': 'Right Grouped', 'desc': 'Both Seal and Signature on right'},
            {'value': 'center', 'label': 'Centered', 'desc': 'Both Seal and Signature centered'},
            {'value': 'left', 'label': 'Left Grouped', 'desc': 'Both on left side'},
          ],
          currentValue: cfg.signaturesLayout,
          onChanged: (val) => _updateConfig((c) => c.copyWith(signaturesLayout: val)),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Bank Transfer Details'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Bank Card Position',
          options: const [
            {'value': 'left_column', 'label': 'Side Column', 'desc': 'Alongside financial summary'},
            {'value': 'full_width', 'label': 'Full Width Below', 'desc': 'Dedicated bar under totals'},
          ],
          currentValue: cfg.bankDetailsLayout,
          onChanged: (val) => _updateConfig((c) => c.copyWith(bankDetailsLayout: val)),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Official Stamp / Seal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _template.showSeal,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) {
            setState(() {
              _template = _template.copyWith(showSeal: val);
              _renderVersion++;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Signature Line', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _template.showSignature,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) {
            setState(() {
              _template = _template.copyWith(showSignature: val);
              _renderVersion++;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Bank Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          value: _template.showBankDetails,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) {
            setState(() {
              _template = _template.copyWith(showBankDetails: val);
              _renderVersion++;
            });
          },
        ),
        const Divider(height: 20),
        _buildSectionHeader('Pending Status Visibility (Seal, Signature, Logo)'),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Official Seal if Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Render official company seal on pending documents', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: cfg.showSealWhenPending,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) => _updateConfig((c) => c.copyWith(showSealWhenPending: val)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Signature Line if Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Render authorized signatory on pending documents', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: cfg.showSignatureWhenPending,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) => _updateConfig((c) => c.copyWith(showSignatureWhenPending: val)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Company Logo if Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Render company logo on pending documents', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: cfg.showLogoWhenPending,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) => _updateConfig((c) => c.copyWith(showLogoWhenPending: val)),
        ),
      ],
    );
  }

  // 5. Margins & Footer Controls
  Widget _buildMarginsAndFooterControls() {
    final cfg = _template.layoutConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Page Geometry & Printable Margins'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Margin Spacing',
          options: const [
            {'value': 'compact', 'label': 'Compact (20pt)', 'desc': 'Maximum printable content area'},
            {'value': 'standard', 'label': 'Standard (32pt)', 'desc': 'Classic official document look'},
            {'value': 'spacious', 'label': 'Spacious (44pt)', 'desc': 'Generous elegant borders'},
          ],
          currentValue: cfg.pageMargin,
          onChanged: (val) => _updateConfig((c) => c.copyWith(pageMargin: val)),
        ),
        const SizedBox(height: 14),
        _buildSectionHeader('Footer Alignment'),
        const SizedBox(height: 8),
        _buildOptionSelector<String>(
          label: 'Alignment',
          options: const [
            {'value': 'split', 'label': 'Split', 'desc': 'Company info left, Page number right'},
            {'value': 'center', 'label': 'Centered', 'desc': 'All centered'},
            {'value': 'left', 'label': 'Left', 'desc': 'All left-aligned'},
          ],
          currentValue: cfg.footerAlignment,
          onChanged: (val) => _updateConfig((c) => c.copyWith(footerAlignment: val)),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Footer Divider Line', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Draw a thin line above the footer text', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: cfg.footerDivider,
          activeThumbColor: const Color(0xFF0A2540),
          onChanged: (val) => _updateConfig((c) => c.copyWith(footerDivider: val)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0A2540),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildOptionSelector<T>({
    required String label,
    required List<Map<String, dynamic>> options,
    required T currentValue,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = opt['value'] == currentValue;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(opt['value'] as T),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0A2540) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0A2540) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (opt['desc'] != null)
                      Text(
                        opt['desc'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
