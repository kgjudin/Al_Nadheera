class ProductClass {
  final String id;
  final String name;
  final DateTime? createdAt;

  ProductClass({
    required this.id,
    required this.name,
    this.createdAt,
  });

  factory ProductClass.fromJson(Map<String, dynamic> json) {
    return ProductClass(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductClass && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProductSubmodule {
  final String id;
  final String? classId;
  final String className;
  final String name;
  final DateTime? createdAt;

  ProductSubmodule({
    required this.id,
    this.classId,
    required this.className,
    required this.name,
    this.createdAt,
  });

  factory ProductSubmodule.fromJson(Map<String, dynamic> json) {
    return ProductSubmodule(
      id: json['id']?.toString() ?? '',
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (classId != null && classId!.isNotEmpty) 'class_id': classId,
      'class_name': className,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductSubmodule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Product {
  final String id;
  final String name;
  final String? unit;
  final double price;
  final String? className;
  final String? classId;
  final String? submoduleName;
  final String? submoduleId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    this.unit,
    required this.price,
    this.className,
    this.classId,
    this.submoduleName,
    this.submoduleId,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString(),
      price: (json['price'] != null) ? (json['price'] as num).toDouble() : 0.0,
      className: json['class_name']?.toString(),
      classId: json['class_id']?.toString(),
      submoduleName: json['submodule_name']?.toString(),
      submoduleId: json['submodule_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'unit': unit,
      'price': price,
      if (className != null && className!.isNotEmpty) 'class_name': className,
      if (classId != null && classId!.isNotEmpty) 'class_id': classId,
      if (submoduleName != null && submoduleName!.isNotEmpty) 'submodule_name': submoduleName,
      if (submoduleId != null && submoduleId!.isNotEmpty) 'submodule_id': submoduleId,
    };
  }
}
