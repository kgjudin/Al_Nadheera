class DocumentTemplate {
  final String id;
  final String templateType;
  final String templateName;
  final String companyNameEn;
  final String? companyNameAr;
  final String? tagline;
  final String? logoUrl;
  final String? sealUrl;
  final String? signatureUrl;
  final String address;
  final String phone;
  final String email;
  final String? website;
  final String? crNumber;
  final String? vatNumber;
  final String? bankName;
  final String? accountName;
  final String? iban;
  final String? swiftCode;
  final String? termsAndConditions;
  final String? footerText;
  final String primaryColor;
  final String accentColor;
  final bool showSeal;
  final bool showSignature;
  final bool showBankDetails;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DocumentTemplate({
    required this.id,
    required this.templateType,
    required this.templateName,
    this.companyNameEn = 'AL NADHEERA CONTRACTING W.L.L',
    this.companyNameAr = 'شركة النذيرة للمقاولات ذ.م.م',
    this.tagline = 'Civil Engineering & General Contracting',
    this.logoUrl,
    this.sealUrl,
    this.signatureUrl,
    this.address = 'Kingdom of Bahrain • Manama',
    this.phone = '+973 3982 4512 / +973 1740 1234',
    this.email = 'info@alnadheera.com',
    this.website = 'www.alnadheera.com',
    this.crNumber = '142857-1',
    this.vatNumber = '200014589200003',
    this.bankName = 'National Bank of Bahrain (NBB)',
    this.accountName = 'AL NADHEERA CONTRACTING W.L.L',
    this.iban = 'BH64 NBOB 0000 0012 3456 7890 01',
    this.swiftCode = 'NBOBBHBM',
    this.termsAndConditions =
        'Payment is due within 14 days of invoice date. Thank you for your business.',
    this.footerText = 'Al Nadheera Contracting W.L.L. • Kingdom of Bahrain',
    this.primaryColor = '#0A2540',
    this.accentColor = '#0B5ED7',
    this.showSeal = true,
    this.showSignature = true,
    this.showBankDetails = true,
    this.isDefault = true,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentTemplate.defaultTemplate(String type) {
    String name = 'Invoice Template';
    String color = '#0A2540';
    String tagline = 'Civil Engineering & General Contracting';

    if (type == 'vat_statement') {
      name = 'Site VAT Statement Template';
      color = '#0B5ED7';
      tagline = 'Official Site VAT Report & Accounting';
    } else if (type == 'receipt') {
      name = 'Payment Voucher & Receipt Template';
      color = '#137333';
      tagline = 'Official Payment Voucher & Disbursement';
    } else if (type == 'quotation') {
      name = 'Quotation & Estimation Template';
      color = '#4338CA';
      tagline = 'Engineering Quotations & Project Proposals';
    }

    return DocumentTemplate(
      id: '',
      templateType: type,
      templateName: name,
      tagline: tagline,
      primaryColor: color,
    );
  }

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) {
    return DocumentTemplate(
      id: json['id']?.toString() ?? '',
      templateType: json['template_type']?.toString() ?? 'invoice',
      templateName: json['template_name']?.toString() ?? 'Default Template',
      companyNameEn: json['company_name_en']?.toString() ??
          'AL NADHEERA CONTRACTING W.L.L',
      companyNameAr: json['company_name_ar']?.toString(),
      tagline: json['tagline']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      sealUrl: json['seal_url']?.toString(),
      signatureUrl: json['signature_url']?.toString(),
      address: json['address']?.toString() ?? 'Kingdom of Bahrain • Manama',
      phone: json['phone']?.toString() ?? '+973 3982 4512 / +973 1740 1234',
      email: json['email']?.toString() ?? 'info@alnadheera.com',
      website: json['website']?.toString(),
      crNumber: json['cr_number']?.toString() ?? '142857-1',
      vatNumber: json['vat_number']?.toString() ?? '200014589200003',
      bankName: json['bank_name']?.toString() ?? 'National Bank of Bahrain (NBB)',
      accountName: json['account_name']?.toString() ??
          'AL NADHEERA CONTRACTING W.L.L',
      iban: json['iban']?.toString() ?? 'BH64 NBOB 0000 0012 3456 7890 01',
      swiftCode: json['swift_code']?.toString() ?? 'NBOBBHBM',
      termsAndConditions: json['terms_and_conditions']?.toString() ??
          'Payment is due within 14 days of invoice date. Thank you for your business.',
      footerText: json['footer_text']?.toString() ??
          'Al Nadheera Contracting W.L.L. • Kingdom of Bahrain',
      primaryColor: json['primary_color']?.toString() ?? '#0A2540',
      accentColor: json['accent_color']?.toString() ?? '#0B5ED7',
      showSeal: json['show_seal'] != false,
      showSignature: json['show_signature'] != false,
      showBankDetails: json['show_bank_details'] != false,
      isDefault: json['is_default'] != false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template_type': templateType,
      'template_name': templateName,
      'company_name_en': companyNameEn,
      'company_name_ar': companyNameAr,
      'tagline': tagline,
      'logo_url': logoUrl,
      'seal_url': sealUrl,
      'signature_url': signatureUrl,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'cr_number': crNumber,
      'vat_number': vatNumber,
      'bank_name': bankName,
      'account_name': accountName,
      'iban': iban,
      'swift_code': swiftCode,
      'terms_and_conditions': termsAndConditions,
      'footer_text': footerText,
      'primary_color': primaryColor,
      'accent_color': accentColor,
      'show_seal': showSeal,
      'show_signature': showSignature,
      'show_bank_details': showBankDetails,
      'is_default': isDefault,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  DocumentTemplate copyWith({
    String? templateType,
    String? templateName,
    String? companyNameEn,
    String? companyNameAr,
    String? tagline,
    String? logoUrl,
    String? sealUrl,
    String? signatureUrl,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? crNumber,
    String? vatNumber,
    String? bankName,
    String? accountName,
    String? iban,
    String? swiftCode,
    String? termsAndConditions,
    String? footerText,
    String? primaryColor,
    String? accentColor,
    bool? showSeal,
    bool? showSignature,
    bool? showBankDetails,
    bool? isDefault,
  }) {
    return DocumentTemplate(
      id: id,
      templateType: templateType ?? this.templateType,
      templateName: templateName ?? this.templateName,
      companyNameEn: companyNameEn ?? this.companyNameEn,
      companyNameAr: companyNameAr ?? this.companyNameAr,
      tagline: tagline ?? this.tagline,
      logoUrl: logoUrl ?? this.logoUrl,
      sealUrl: sealUrl ?? this.sealUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      crNumber: crNumber ?? this.crNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      iban: iban ?? this.iban,
      swiftCode: swiftCode ?? this.swiftCode,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      footerText: footerText ?? this.footerText,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      showSeal: showSeal ?? this.showSeal,
      showSignature: showSignature ?? this.showSignature,
      showBankDetails: showBankDetails ?? this.showBankDetails,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
