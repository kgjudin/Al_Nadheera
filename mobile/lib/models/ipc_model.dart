class IpcItem {
  final String? id;
  final String? ipcId;
  String itemType; // 'heading', 'subheading', 'item'
  String? itemNumber; // e.g. 'I1', 'I2', 'I4A', 'I4B'
  String description;
  String? unit; // e.g. 'm', 'METER', 'LM'
  double quantity;
  double rate;
  double amount;
  int sortOrder;
  String? className;
  String? submoduleName;
  String? productId;

  IpcItem({
    this.id,
    this.ipcId,
    this.itemType = 'item',
    this.itemNumber,
    required this.description,
    this.unit,
    this.quantity = 0.0,
    this.rate = 0.0,
    double? amount,
    this.sortOrder = 0,
    this.className,
    this.submoduleName,
    this.productId,
  }) : amount = amount ?? (quantity * rate);

  bool get isHeading => itemType == 'heading';
  bool get isSubheading => itemType == 'subheading';
  bool get isItem => itemType == 'item';

  void calculateAmount() {
    if (isItem) {
      amount = quantity * rate;
    } else {
      amount = 0.0;
    }
  }

  factory IpcItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final r = (json['rate'] as num?)?.toDouble() ?? 0.0;
    final amt = (json['amount'] as num?)?.toDouble() ?? (qty * r);

    return IpcItem(
      id: json['id'] as String?,
      ipcId: json['ipc_id'] as String?,
      itemType: json['item_type'] as String? ?? 'item',
      itemNumber: json['item_number'] as String?,
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String?,
      quantity: qty,
      rate: r,
      amount: amt,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      className: json['class_name'] as String?,
      submoduleName: json['submodule_name'] as String?,
      productId: json['product_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ipcId != null) 'ipc_id': ipcId,
      'item_type': itemType,
      'item_number': itemNumber,
      'description': description,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
      'sort_order': sortOrder,
      'class_name': className,
      'submodule_name': submoduleName,
      'product_id': productId,
    };
  }

  IpcItem copyWith({
    String? id,
    String? ipcId,
    String? itemType,
    String? itemNumber,
    String? description,
    String? unit,
    double? quantity,
    double? rate,
    double? amount,
    int? sortOrder,
    String? className,
    String? submoduleName,
    String? productId,
  }) {
    return IpcItem(
      id: id ?? this.id,
      ipcId: ipcId ?? this.ipcId,
      itemType: itemType ?? this.itemType,
      itemNumber: itemNumber ?? this.itemNumber,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      sortOrder: sortOrder ?? this.sortOrder,
      className: className ?? this.className,
      submoduleName: submoduleName ?? this.submoduleName,
      productId: productId ?? this.productId,
    );
  }
}

class IpcDocument {
  final String id;
  String documentNumber; // e.g. IPC-001
  String projectName; // e.g. PROJECT: IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD
  String? clientName;
  DateTime date;
  String status; // Draft, Submitted, Approved, Paid
  double totalAmount;
  List<IpcItem> items;
  String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  IpcDocument({
    required this.id,
    this.documentNumber = 'IPC-001',
    required this.projectName,
    this.clientName,
    DateTime? date,
    this.status = 'Draft',
    this.totalAmount = 0.0,
    List<IpcItem>? items,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : date = date ?? DateTime.now(),
        items = items ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  void calculateTotal() {
    double total = 0.0;
    for (final item in items) {
      if (item.isItem) {
        item.calculateAmount();
        total += item.amount;
      }
    }
    totalAmount = total;
  }

  factory IpcDocument.fromJson(Map<String, dynamic> json) {
    List<IpcItem> parsedItems = [];
    if (json['items'] != null && json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => IpcItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['ipc_items'] != null && json['ipc_items'] is List) {
      parsedItems = (json['ipc_items'] as List)
          .map((i) => IpcItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    parsedItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return IpcDocument(
      id: json['id']?.toString() ?? '',
      documentNumber: json['document_number'] as String? ?? 'IPC-001',
      projectName: json['project_name'] as String? ?? 'PROJECT',
      clientName: json['client_name'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: json['status'] as String? ?? 'Draft',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'document_number': documentNumber,
      'project_name': projectName,
      'client_name': clientName,
      'date': date.toIso8601String().split('T')[0],
      'status': status,
      'total_amount': totalAmount,
      'items': items.map((i) => i.toJson()).toList(),
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
