class InvoiceItem {
  final String? id;
  final String? invoiceId;
  final String itemDescription;
  final double quantity;
  final double unitPrice;
  final double amount;
  final int sortOrder;

  InvoiceItem({
    this.id,
    this.invoiceId,
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

    return InvoiceItem(
      id: json['id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      itemDescription: json['item_description']?.toString() ?? '',
      quantity: qty,
      unitPrice: price,
      amount: amt,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson({String? parentInvoiceId}) {
    return {
      if (parentInvoiceId != null) 'invoice_id': parentInvoiceId,
      'item_description': itemDescription,
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
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isPending => status.toLowerCase() == 'pending';

  factory Invoice.fromJson(Map<String, dynamic> json, {List<InvoiceItem>? items}) {
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
      notes: json['notes']?.toString(),
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (paymentTerms != null && paymentTerms!.isNotEmpty) 'payment_terms': paymentTerms,
    };
  }

  Invoice copyWith({
    String? status,
    List<InvoiceItem>? items,
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
    );
  }
}
