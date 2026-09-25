import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();

  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _productsFuture = _fetchProducts();
    });
  }

  Future<List<Product>> _fetchProducts() async {
    try {
      // Primary: query Supabase database directly
      final response = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (supabaseError) {
      debugPrint('Supabase direct query error: $supabaseError. Trying backend API...');
      // Fallback: try backend API
      try {
        return await _apiService.getProducts();
      } catch (apiError) {
        throw Exception('Failed to load products: $supabaseError');
      }
    }
  }

  Future<void> _addProduct(String name, String unit, double price) async {
    final productData = {
      'name': name,
      'unit': unit.isEmpty ? null : unit,
      'price': price,
    };

    try {
      await _supabase.from('products').insert(productData);
    } catch (e) {
      debugPrint('Supabase direct insert error: $e. Trying backend API...');
      await _apiService.createProduct(productData);
    }
    _loadProducts();
  }

  Future<void> _updateProduct(String id, String name, String unit, double price) async {
    final productData = {
      'name': name,
      'unit': unit.isEmpty ? null : unit,
      'price': price,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('products').update(productData).eq('id', id);
    } catch (e) {
      debugPrint('Supabase direct update error: $e. Trying backend API...');
      await _apiService.updateProduct(id, productData);
    }
    _loadProducts();
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      debugPrint('Supabase direct delete error: $e. Trying backend API...');
      await _apiService.deleteProduct(id);
    }
    _loadProducts();
  }

  void _showAddEditProductDialog([Product? existingProduct]) {
    final nameController = TextEditingController(text: existingProduct?.name ?? '');
    final unitController = TextEditingController(text: existingProduct?.unit ?? '');
    final priceController = TextEditingController(
      text: existingProduct != null ? existingProduct.price.toString() : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingProduct == null ? 'Add Product' : 'Edit Product'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Product Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g., kg, pieces, bags)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: 'QAR ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          try {
                            final name = nameController.text.trim();
                            final unit = unitController.text.trim();
                            final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                            if (existingProduct == null) {
                              await _addProduct(name, unit, price);
                            } else {
                              await _updateProduct(existingProduct.id, name, unit, price);
                            }

                            if (mounted) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(existingProduct == null
                                      ? 'Product added successfully'
                                      : 'Product updated successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isSaving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error saving product: $e')),
                              );
                            }
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(existingProduct == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await _deleteProduct(product.id);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Product deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error deleting product: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadProducts();
          await _productsFuture;
        },
        child: FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load products',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No products added yet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditProductDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Product'),
                    ),
                  ],
                ),
              );
            }

            final products = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: product.unit != null && product.unit!.isNotEmpty
                        ? Text('Unit: ${product.unit}')
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'QAR ${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddEditProductDialog(product);
                            } else if (value == 'delete') {
                              _confirmDeleteProduct(product);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
