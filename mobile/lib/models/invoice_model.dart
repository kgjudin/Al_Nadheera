import 'dart:convert';

class InvoiceItem {
  final String? id;
  final String? invoiceId;
  final String? itemClass;
  final String itemDescription;
  final double quantity;
  final double unitPrice;
  final double amount;
  final int sortOrder;

  InvoiceItem({
    this.id,
    this.invoiceId,
    this.itemClass,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    double? amount,
    this.sortOrder = 0,
  }) : amount = amount ?? (quantity * unitPrice);

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 1.0;
    final price = (json['unit_price'] as num?)?.toDouble() ?? 0.0;
    final amt = (json['amount'] as num?)?.toDouble() ?? (qty * price);

    String desc = json['item_description']?.toString() ?? '';
    String? itemClass = json['item_class']?.toString() ?? json['class']?.toString();

    // If itemClass was not in dedicated column, check if it was packed into item_description as [CLASS: X]
    if ((itemClass == null || itemClass.isEmpty) && desc.startsWith('[CLASS:')) {
      final closeIdx = desc.indexOf(']');
      if (closeIdx != -1) {
        itemClass = desc.substring(7, closeIdx).trim();
        desc = desc.substring(closeIdx + 1).trim();
      }
    }

    return InvoiceItem(
      id: json['id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      itemClass: itemClass,
      itemDescription: desc,
      quantity: qty,
      unitPrice: price,
      amount: amt,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson({String? parentInvoiceId, bool useDedicatedColumns = true}) {
    String desc = itemDescription;
    if (!useDedicatedColumns && itemClass != null && itemClass!.isNotEmpty) {
      desc = '[CLASS: $itemClass] $desc';
    }

    return {
      if (parentInvoiceId != null) 'invoice_id': parentInvoiceId,
      if (useDedicatedColumns && itemClass != null && itemClass!.isNotEmpty) 'item_class': itemClass,
      'item_description': desc,
      'quantity': quantity,
      'unit_price': unitPrice,
      'amount': amount,
      'sort_order': sortOrder,
    };
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime date;
  final DateTime? dueDate;
  final String status; // 'Pending' or 'Paid'
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerVatNumber;
  final String? siteId;
  final String? siteName;
  final String? description;
  final double subtotal;
  final double discount;
  final String discountType; // 'amount' or 'percentage'
  final double vatRate;
  final double vatAmount;
  final double totalAmount;
  final String? notes;
  final String? paymentTerms;
  final List<InvoiceItem> items;
  final DateTime createdAt;
  final String? documentType;
  final String? subject;
  final String? salutation;
  final String? introText;
  final String? tableHeaderTitle;
  final Map<String, dynamic>? sourceConfig;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    this.dueDate,
    this.status = 'Pending',
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerVatNumber,
    this.siteId,
    this.siteName,
    this.description,
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.discountType = 'amount',
    this.vatRate = 0.0,
    this.vatAmount = 0.0,
    this.totalAmount = 0.0,
    this.notes,
    this.paymentTerms,
    this.items = const [],
    required this.createdAt,
    this.documentType = 'B2B',
    this.subject,
    this.salutation,
    this.introText,
    this.tableHeaderTitle,
    this.sourceConfig,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isPending => status.toLowerCase() == 'pending';

  factory Invoice.fromJson(Map<String, dynamic> json, {List<InvoiceItem>? items}) {
    String? rawNotes = json['notes']?.toString();
    String? displayNotes = rawNotes;
    Map<String, dynamic>? embeddedMeta;

    if (rawNotes != null && rawNotes.contains('<!--B2B_META:')) {
      final startIndex = rawNotes.indexOf('<!--B2B_META:') + '<!--B2B_META:'.length;
      final endIndex = rawNotes.indexOf('-->', startIndex);
      if (endIndex != -1) {
        final metaJsonStr = rawNotes.substring(startIndex, endIndex);
        try {
          final decoded = jsonDecode(metaJsonStr);
          if (decoded is Map<String, dynamic>) {
            embeddedMeta = decoded;
          }
          final before = rawNotes.substring(0, rawNotes.indexOf('<!--B2B_META:'));
          final after = rawNotes.substring(endIndex + 3);
          displayNotes = ('$before $after').trim();
          if (displayNotes.isEmpty) displayNotes = null;
        } catch (_) {}
      }
    }

    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? 'INV',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      status: json['status']?.toString() ?? 'Pending',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Unknown Customer',
      customerPhone: json['customer_phone']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      customerVatNumber: json['customer_vat_number']?.toString(),
      siteId: json['site_id']?.toString(),
      siteName: json['site_name']?.toString(),
      description: json['description']?.toString(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discount_type']?.toString() ?? 'amount',
      vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: displayNotes,
      paymentTerms: json['payment_terms']?.toString(),
      items: items ??
          (json['invoice_items'] is List
              ? (json['invoice_items'] as List)
                  .map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>))
                  .toList()
              : []),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      documentType: json['document_type']?.toString() ?? embeddedMeta?['documentType']?.toString() ?? 'B2B',
      subject: json['subject']?.toString() ?? embeddedMeta?['subject']?.toString(),
      salutation: json['salutation']?.toString() ?? embeddedMeta?['salutation']?.toString(),
      introText: json['intro_text']?.toString() ?? embeddedMeta?['introText']?.toString(),
      tableHeaderTitle: json['table_header_title']?.toString() ?? embeddedMeta?['tableHeaderTitle']?.toString(),
      sourceConfig: (json['source_config'] is Map
          ? Map<String, dynamic>.from(json['source_config'] as Map)
          : null) ?? (embeddedMeta?['sourceConfig'] is Map ? Map<String, dynamic>.from(embeddedMeta!['sourceConfig'] as Map) : null),
    );
  }

  Map<String, dynamic> toJson({bool useDedicatedColumns = true}) {
    final Map<String, dynamic> data = {
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String().substring(0, 10),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String().substring(0, 10),
      'status': status,
      if (customerId != null && customerId!.isNotEmpty) 'customer_id': customerId,
      'customer_name': customerName,
      if (customerPhone != null && customerPhone!.isNotEmpty) 'customer_phone': customerPhone,
      if (customerAddress != null && customerAddress!.isNotEmpty) 'customer_address': customerAddress,
      if (customerVatNumber != null && customerVatNumber!.isNotEmpty) 'customer_vat_number': customerVatNumber,
      if (siteId != null && siteId!.isNotEmpty) 'site_id': siteId,
      if (siteName != null && siteName!.isNotEmpty) 'site_name': siteName,
      if (description != null && description!.isNotEmpty) 'description': description,
      'subtotal': subtotal,
      'discount': discount,
      'discount_type': discountType,
      'vat_rate': vatRate,
      'vat_amount': vatAmount,
      'total_amount': totalAmount,
      if (paymentTerms != null && paymentTerms!.isNotEmpty) 'payment_terms': paymentTerms,
    };

    if (useDedicatedColumns) {
      if (notes != null && notes!.isNotEmpty) data['notes'] = notes;
      if (documentType != null && documentType!.isNotEmpty) data['document_type'] = documentType;
      if (subject != null && subject!.isNotEmpty) data['subject'] = subject;
      if (salutation != null && salutation!.isNotEmpty) data['salutation'] = salutation;
      if (introText != null && introText!.isNotEmpty) data['intro_text'] = introText;
      if (tableHeaderTitle != null && tableHeaderTitle!.isNotEmpty) data['table_header_title'] = tableHeaderTitle;
      if (sourceConfig != null) data['source_config'] = sourceConfig;
    } else {
      final meta = <String, dynamic>{
        if (documentType != null) 'documentType': documentType,
        if (subject != null) 'subject': subject,
        if (salutation != null) 'salutation': salutation,
        if (introText != null) 'introText': introText,
        if (tableHeaderTitle != null) 'tableHeaderTitle': tableHeaderTitle,
        if (sourceConfig != null) 'sourceConfig': sourceConfig,
      };

      String combinedNotes = notes ?? '';
      if (meta.isNotEmpty) {
        final metaString = '<!--B2B_META:${jsonEncode(meta)}-->';
        combinedNotes = combinedNotes.isNotEmpty ? '$combinedNotes\n$metaString' : metaString;
      }
      if (combinedNotes.isNotEmpty) {
        data['notes'] = combinedNotes;
      }
    }

    return data;
  }

  Invoice copyWith({
    String? status,
    List<InvoiceItem>? items,
    String? documentType,
    String? subject,
    String? salutation,
    String? introText,
    String? tableHeaderTitle,
    Map<String, dynamic>? sourceConfig,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      date: date,
      dueDate: dueDate,
      status: status ?? this.status,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      customerVatNumber: customerVatNumber,
      siteId: siteId,
      siteName: siteName,
      description: description,
      subtotal: subtotal,
      discount: discount,
      discountType: discountType,
      vatRate: vatRate,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      notes: notes,
      paymentTerms: paymentTerms,
      items: items ?? this.items,
      createdAt: createdAt,
      documentType: documentType ?? this.documentType,
      subject: subject ?? this.subject,
      salutation: salutation ?? this.salutation,
      introText: introText ?? this.introText,
      tableHeaderTitle: tableHeaderTitle ?? this.tableHeaderTitle,
      sourceConfig: sourceConfig ?? this.sourceConfig,
    );
  }
}
