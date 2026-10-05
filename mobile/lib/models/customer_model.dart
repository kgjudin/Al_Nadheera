class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? vatNumber;
  final String? crNumber;
  final String? notes;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.vatNumber,
    this.crNumber,
    this.notes,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      vatNumber: json['vat_number']?.toString(),
      crNumber: json['cr_number']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (vatNumber != null && vatNumber!.isNotEmpty) 'vat_number': vatNumber,
      if (crNumber != null && crNumber!.isNotEmpty) 'cr_number': crNumber,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
