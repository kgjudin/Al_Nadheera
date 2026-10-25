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
  bool isHighlighted;
  String? highlightColor;

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
    this.isHighlighted = false,
    this.highlightColor,
  }) : amount = amount ?? (quantity * rate);

  bool get isHeading => itemType == 'heading';
  bool get isSubheading => itemType == 'subheading';
  bool get isItem => itemType == 'item';

  String get highlightColorHex {
    if (highlightColor != null && highlightColor!.isNotEmpty) {
      return highlightColor!.startsWith('#') ? highlightColor! : '#$highlightColor';
    }
    return '#FEF9C3'; // Soft yellow highlighter
  }

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
      isHighlighted: json['is_highlighted'] == true ||
          json['is_highlighted']?.toString().toLowerCase() == 'true',
      highlightColor: json['highlight_color'] as String?,
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
      'is_highlighted': isHighlighted,
      if (highlightColor != null) 'highlight_color': highlightColor,
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
    bool? isHighlighted,
    String? highlightColor,
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
      isHighlighted: isHighlighted ?? this.isHighlighted,
      highlightColor: highlightColor ?? this.highlightColor,
    );
  }
}

class IpcDeductionItem {
  final String? id;
  String? itemNumber; // e.g. '21', '22', '27'
  String description; // e.g. '1000mm Dia GRP Pipes', 'Machinery deduction'
  String? unit; // e.g. 'm', 'nrs', 'KG', 'roll', 'pcs', 'Sum'
  double? contractRate;
  double? previousQuantity;
  double? previousAmount;
  double? thisPeriodQuantity;
  double? thisPeriodAmount;
  double? cumulativeQuantity;
  double? cumulativeAmount;
  String? remarks; // e.g. 'as per site'
  bool isHighlighted;
  String? highlightColor;
  int sortOrder;

  IpcDeductionItem({
    this.id,
    this.itemNumber,
    required this.description,
    this.unit,
    this.contractRate,
    this.previousQuantity,
    this.previousAmount,
    this.thisPeriodQuantity,
    this.thisPeriodAmount,
    this.cumulativeQuantity,
    this.cumulativeAmount,
    this.remarks,
    this.isHighlighted = false,
    this.highlightColor,
    this.sortOrder = 0,
  });

  String get highlightColorHex {
    if (highlightColor != null && highlightColor!.isNotEmpty) {
      return highlightColor!.startsWith('#') ? highlightColor! : '#$highlightColor';
    }
    return '#FFFF00'; // Bright yellow highlighter as per sample sheet
  }

  void autoCompute() {
    final rate = contractRate;
    if (rate != null && rate > 0) {
      if (previousQuantity != null && previousQuantity! > 0 && previousAmount == null) {
        previousAmount = previousQuantity! * rate;
      }
      if (thisPeriodQuantity != null && thisPeriodQuantity! > 0 && thisPeriodAmount == null) {
        thisPeriodAmount = thisPeriodQuantity! * rate;
      }
    }
    // Cumulative Qty
    final prevQ = previousQuantity ?? 0.0;
    final thisQ = thisPeriodQuantity ?? 0.0;
    if (cumulativeQuantity == null && (prevQ > 0 || thisQ > 0)) {
      cumulativeQuantity = prevQ + thisQ;
    }
    // Cumulative Amount
    final prevA = previousAmount ?? 0.0;
    final thisA = thisPeriodAmount ?? 0.0;
    if (cumulativeAmount == null && (prevA > 0 || thisA > 0)) {
      cumulativeAmount = prevA + thisA;
    }
  }

  factory IpcDeductionItem.fromJson(Map<String, dynamic> json) {
    return IpcDeductionItem(
      id: json['id'] as String?,
      itemNumber: json['item_number'] as String?,
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String?,
      contractRate: (json['contract_rate'] as num?)?.toDouble(),
      previousQuantity: (json['previous_quantity'] as num?)?.toDouble(),
      previousAmount: (json['previous_amount'] as num?)?.toDouble(),
      thisPeriodQuantity: (json['this_period_quantity'] as num?)?.toDouble(),
      thisPeriodAmount: (json['this_period_amount'] as num?)?.toDouble(),
      cumulativeQuantity: (json['cumulative_quantity'] as num?)?.toDouble(),
      cumulativeAmount: (json['cumulative_amount'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
      isHighlighted: json['is_highlighted'] == true ||
          json['is_highlighted']?.toString().toLowerCase() == 'true',
      highlightColor: json['highlight_color'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'item_number': itemNumber,
      'description': description,
      'unit': unit,
      'contract_rate': contractRate,
      'previous_quantity': previousQuantity,
      'previous_amount': previousAmount,
      'this_period_quantity': thisPeriodQuantity,
      'this_period_amount': thisPeriodAmount,
      'cumulative_quantity': cumulativeQuantity,
      'cumulative_amount': cumulativeAmount,
      'remarks': remarks,
      'is_highlighted': isHighlighted,
      if (highlightColor != null) 'highlight_color': highlightColor,
      'sort_order': sortOrder,
    };
  }

  IpcDeductionItem copyWith({
    String? id,
    String? itemNumber,
    String? description,
    String? unit,
    double? contractRate,
    double? previousQuantity,
    double? previousAmount,
    double? thisPeriodQuantity,
    double? thisPeriodAmount,
    double? cumulativeQuantity,
    double? cumulativeAmount,
    String? remarks,
    bool? isHighlighted,
    String? highlightColor,
    int? sortOrder,
  }) {
    return IpcDeductionItem(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      contractRate: contractRate ?? this.contractRate,
      previousQuantity: previousQuantity ?? this.previousQuantity,
      previousAmount: previousAmount ?? this.previousAmount,
      thisPeriodQuantity: thisPeriodQuantity ?? this.thisPeriodQuantity,
      thisPeriodAmount: thisPeriodAmount ?? this.thisPeriodAmount,
      cumulativeQuantity: cumulativeQuantity ?? this.cumulativeQuantity,
      cumulativeAmount: cumulativeAmount ?? this.cumulativeAmount,
      remarks: remarks ?? this.remarks,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      highlightColor: highlightColor ?? this.highlightColor,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class IpcDocument {
  final String id;
  String documentNumber; // e.g. IPC-001
  String projectName; // e.g. PROJECT: IMPROVEMENT OF HIGHWAY 96 - PHASE 1 - DESIGN & BUILD
  String? clientName;
  String mainContractor; // e.g. custom or empty
  String subContractor; // e.g. custom or empty
  DateTime date;
  String status; // Draft, Submitted, Approved, Paid
  double totalAmount;
  List<IpcItem> items;
  List<IpcDeductionItem> deductions;
  String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  IpcDocument({
    required this.id,
    this.documentNumber = 'IPC-001',
    required this.projectName,
    this.clientName,
    this.mainContractor = '',
    this.subContractor = '',
    DateTime? date,
    this.status = 'Draft',
    this.totalAmount = 0.0,
    List<IpcItem>? items,
    List<IpcDeductionItem>? deductions,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : date = date ?? DateTime.now(),
        items = items ?? [],
        deductions = deductions ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasDeductions => deductions.isNotEmpty;

  double get totalDeductionPrevious {
    double total = 0.0;
    for (final d in deductions) {
      total += (d.previousAmount ?? 0.0);
    }
    return total;
  }

  double get totalDeductionThisPeriod {
    double total = 0.0;
    for (final d in deductions) {
      total += (d.thisPeriodAmount ?? 0.0);
    }
    return total;
  }

  double get totalDeductionCumulative {
    double total = 0.0;
    for (final d in deductions) {
      total += (d.cumulativeAmount ?? 0.0);
    }
    return total;
  }

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

    List<IpcDeductionItem> parsedDeductions = [];
    if (json['deductions'] != null && json['deductions'] is List) {
      parsedDeductions = (json['deductions'] as List)
          .map((d) => IpcDeductionItem.fromJson(d as Map<String, dynamic>))
          .toList();
    }
    parsedDeductions.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return IpcDocument(
      id: json['id']?.toString() ?? '',
      documentNumber: json['document_number'] as String? ?? 'IPC-001',
      projectName: json['project_name'] as String? ?? 'PROJECT',
      clientName: json['client_name'] as String?,
      mainContractor: json['main_contractor'] as String? ?? '',
      subContractor: json['sub_contractor'] as String? ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: json['status'] as String? ?? 'Draft',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items: parsedItems,
      deductions: parsedDeductions,
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
      'main_contractor': mainContractor,
      'sub_contractor': subContractor,
      'date': date.toIso8601String().split('T')[0],
      'status': status,
      'total_amount': totalAmount,
      'items': items.map((i) => i.toJson()).toList(),
      'deductions': deductions.map((d) => d.toJson()).toList(),
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
