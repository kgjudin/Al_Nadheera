import 'dart:convert';

/// Configuration for layout, alignments, and design positions of document templates.
class TemplateLayoutConfig {
  /// Header layout style:
  /// - 'modern_split': Company left, Invoice badge right (default)
  /// - 'centered': Centered logo, company name, Arabic name & badges
  /// - 'reversed': Invoice badge left, Company right
  /// - 'minimal_bar': Solid accent banner across top
  final String headerLayout;

  /// Logo position within header: 'left', 'center', 'right', 'none'
  final String logoPosition;

  /// Logo sizing: 'small' (38px), 'medium' (50px), 'large' (68px)
  final String logoSize;

  /// Company text alignment: 'left', 'center', 'right'
  final String companyInfoAlign;

  /// Bill To & Invoice Info arrangement:
  /// - 'split': Bill To left, Invoice info right
  /// - 'reversed_split': Invoice info left, Bill To right
  /// - 'stacked': Bill To full-width, Invoice info below
  final String metaLayout;

  /// Bill To box decoration: 'card' (boxed), 'accent_border' (vertical accent bar), 'clean' (minimal)
  final String billToStyle;

  /// Table header appearance: 'primary_filled' (solid primary), 'tinted' (soft tint), 'minimal' (clean outline)
  final String tableHeaderStyle;

  /// Whether to alternate row background colors for contrast
  final bool tableZebraStripes;

  /// Table row padding & spacing: 'compact', 'standard', 'spacious'
  final String tableDensity;

  /// Financial summary / totals position: 'right', 'left', 'full_width'
  final String totalsPosition;

  /// Bank transfer details placement: 'left_column' (alongside totals), 'full_width' (below totals)
  final String bankDetailsLayout;

  /// Stamp & signature placement:
  /// - 'split': Signature left, Official seal right
  /// - 'right': Both grouped on the right
  /// - 'left': Both grouped on the left
  /// - 'center': Both centered
  final String signaturesLayout;

  /// Footer text alignment: 'split' (text left, page right), 'center', 'left'
  final String footerAlignment;

  /// Whether to draw a divider line above the footer
  final bool footerDivider;

  /// Page margin spacing: 'compact' (18pt), 'standard' (30pt), 'spacious' (42pt)
  final String pageMargin;

  /// Whether to show the official company seal on Pending status documents
  final bool showSealWhenPending;

  /// Whether to show the authorized signature on Pending status documents
  final bool showSignatureWhenPending;

  /// Whether to show the company logo on Pending status documents
  final bool showLogoWhenPending;

  /// Whether to show a watermark stamp for Pending documents
  final bool showPendingWatermark;

  const TemplateLayoutConfig({
    this.headerLayout = 'modern_split',
    this.logoPosition = 'left',
    this.logoSize = 'medium',
    this.companyInfoAlign = 'left',
    this.metaLayout = 'split',
    this.billToStyle = 'card',
    this.tableHeaderStyle = 'primary_filled',
    this.tableZebraStripes = true,
    this.tableDensity = 'standard',
    this.totalsPosition = 'right',
    this.bankDetailsLayout = 'left_column',
    this.signaturesLayout = 'split',
    this.footerAlignment = 'split',
    this.footerDivider = true,
    this.pageMargin = 'standard',
    this.showSealWhenPending = true,
    this.showSignatureWhenPending = true,
    this.showLogoWhenPending = true,
    this.showPendingWatermark = false,
  });

  factory TemplateLayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TemplateLayoutConfig();
    return TemplateLayoutConfig(
      headerLayout: json['headerLayout']?.toString() ?? 'modern_split',
      logoPosition: json['logoPosition']?.toString() ?? 'left',
      logoSize: json['logoSize']?.toString() ?? 'medium',
      companyInfoAlign: json['companyInfoAlign']?.toString() ?? 'left',
      metaLayout: json['metaLayout']?.toString() ?? 'split',
      billToStyle: json['billToStyle']?.toString() ?? 'card',
      tableHeaderStyle: json['tableHeaderStyle']?.toString() ?? 'primary_filled',
      tableZebraStripes: json['tableZebraStripes'] != false,
      tableDensity: json['tableDensity']?.toString() ?? 'standard',
      totalsPosition: json['totalsPosition']?.toString() ?? 'right',
      bankDetailsLayout: json['bankDetailsLayout']?.toString() ?? 'left_column',
      signaturesLayout: json['signaturesLayout']?.toString() ?? 'split',
      footerAlignment: json['footerAlignment']?.toString() ?? 'split',
      footerDivider: json['footerDivider'] != false,
      pageMargin: json['pageMargin']?.toString() ?? 'standard',
      showSealWhenPending: json['showSealWhenPending'] != false,
      showSignatureWhenPending: json['showSignatureWhenPending'] != false,
      showLogoWhenPending: json['showLogoWhenPending'] != false,
      showPendingWatermark: json['showPendingWatermark'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'headerLayout': headerLayout,
      'logoPosition': logoPosition,
      'logoSize': logoSize,
      'companyInfoAlign': companyInfoAlign,
      'metaLayout': metaLayout,
      'billToStyle': billToStyle,
      'tableHeaderStyle': tableHeaderStyle,
      'tableZebraStripes': tableZebraStripes,
      'tableDensity': tableDensity,
      'totalsPosition': totalsPosition,
      'bankDetailsLayout': bankDetailsLayout,
      'signaturesLayout': signaturesLayout,
      'footerAlignment': footerAlignment,
      'footerDivider': footerDivider,
      'pageMargin': pageMargin,
      'showSealWhenPending': showSealWhenPending,
      'showSignatureWhenPending': showSignatureWhenPending,
      'showLogoWhenPending': showLogoWhenPending,
      'showPendingWatermark': showPendingWatermark,
    };
  }

  TemplateLayoutConfig copyWith({
    String? headerLayout,
    String? logoPosition,
    String? logoSize,
    String? companyInfoAlign,
    String? metaLayout,
    String? billToStyle,
    String? tableHeaderStyle,
    bool? tableZebraStripes,
    String? tableDensity,
    String? totalsPosition,
    String? bankDetailsLayout,
    String? signaturesLayout,
    String? footerAlignment,
    bool? footerDivider,
    String? pageMargin,
    bool? showSealWhenPending,
    bool? showSignatureWhenPending,
    bool? showLogoWhenPending,
    bool? showPendingWatermark,
  }) {
    return TemplateLayoutConfig(
      headerLayout: headerLayout ?? this.headerLayout,
      logoPosition: logoPosition ?? this.logoPosition,
      logoSize: logoSize ?? this.logoSize,
      companyInfoAlign: companyInfoAlign ?? this.companyInfoAlign,
      metaLayout: metaLayout ?? this.metaLayout,
      billToStyle: billToStyle ?? this.billToStyle,
      tableHeaderStyle: tableHeaderStyle ?? this.tableHeaderStyle,
      tableZebraStripes: tableZebraStripes ?? this.tableZebraStripes,
      tableDensity: tableDensity ?? this.tableDensity,
      totalsPosition: totalsPosition ?? this.totalsPosition,
      bankDetailsLayout: bankDetailsLayout ?? this.bankDetailsLayout,
      signaturesLayout: signaturesLayout ?? this.signaturesLayout,
      footerAlignment: footerAlignment ?? this.footerAlignment,
      footerDivider: footerDivider ?? this.footerDivider,
      pageMargin: pageMargin ?? this.pageMargin,
      showSealWhenPending: showSealWhenPending ?? this.showSealWhenPending,
      showSignatureWhenPending: showSignatureWhenPending ?? this.showSignatureWhenPending,
      showLogoWhenPending: showLogoWhenPending ?? this.showLogoWhenPending,
      showPendingWatermark: showPendingWatermark ?? this.showPendingWatermark,
    );
  }

  /// Helper to serialize layout config into an invisible tag stored in terms_and_conditions
  static String embedInTerms(String termsText, TemplateLayoutConfig config) {
    final clean = stripFromTerms(termsText);
    final jsonStr = jsonEncode(config.toJson());
    return '$clean\n<!--LAYOUT_CONFIG:$jsonStr-->';
  }

  /// Helper to extract layout config from terms text
  static TemplateLayoutConfig extractFromTerms(String? raw) {
    if (raw == null || raw.isEmpty) return const TemplateLayoutConfig();
    final match = RegExp(r'<!--LAYOUT_CONFIG:(.*?)-->').firstMatch(raw);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(1)!);
        if (decoded is Map<String, dynamic>) {
          return TemplateLayoutConfig.fromJson(decoded);
        }
      } catch (_) {}
    }
    return const TemplateLayoutConfig();
  }

  /// Helper to strip the configuration tag from terms so only clean user text is displayed
  static String stripFromTerms(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'<!--LAYOUT_CONFIG:[\s\S]*?-->'), '').trim();
  }
}
