import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';

class _ProductInputRow {
  final TextEditingController nameCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;

  _ProductInputRow({
    String name = '',
    String unit = 'METER',
    String price = '',
  })  : nameCtrl = TextEditingController(text: name),
        unitCtrl = TextEditingController(text: unit),
        priceCtrl = TextEditingController(text: price);

  void dispose() {
    nameCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
  }
}

class AddProductScreen extends StatefulWidget {
  final Product? existingProduct;
  final String? initialClassName;
  final String? initialSubmoduleName;

  const AddProductScreen({
    super.key,
    this.existingProduct,
    this.initialClassName,
    this.initialSubmoduleName,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();

  final _formKey = GlobalKey<FormState>();

  bool _isLoadingMetadata = true;
  bool _isCreatingClass = false;
  bool _isCreatingSubmodule = false;
  bool _isSavingProducts = false;
  bool _hasSavedAny = false;

  List<ProductClass> _classes = [];
  List<ProductSubmodule> _submodules = [];
  List<Product> _allProducts = [];

  // Section 1: Create Class
  final TextEditingController _newClassCtrl = TextEditingController();

  // Section 2: Class Sub-Modules
  ProductClass? _section2SelectedClass;
  final TextEditingController _newSubmoduleCtrl = TextEditingController();

  // Section 3: Product Details (Dynamic multiple rows)
  ProductClass? _selectedProductClass;
  ProductSubmodule? _selectedProductSubmodule;
  final List<_ProductInputRow> _productRows = [];

  final List<String> _commonUnits = ['METER', 'LM', 'PCS', 'BAG', 'KG', 'NOS', 'SET', 'HOUR'];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _productRows.add(_ProductInputRow(
        name: p.name,
        unit: p.unit ?? 'METER',
        price: p.price > 0 ? p.price.toStringAsFixed(2) : '',
      ));
    } else {
      _productRows.add(_ProductInputRow(unit: 'METER'));
    }

    _loadMetadata();
  }

  @override
  void dispose() {
    _newClassCtrl.dispose();
    _newSubmoduleCtrl.dispose();
    for (final row in _productRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoadingMetadata = true);
    try {
      final classData = await _supabase.from('product_classes').select().order('name');
      final classes = (classData as List).map((j) => ProductClass.fromJson(j)).toList();

      final submoduleData = await _supabase.from('product_submodules').select().order('name');
      final submodules = (submoduleData as List).map((j) => ProductSubmodule.fromJson(j)).toList();

      final productsData = await _supabase.from('products').select().order('created_at', ascending: false);
      final products = (productsData as List).map((j) => Product.fromJson(j)).toList();

      if (mounted) {
        setState(() {
          _classes = classes;
          _submodules = submodules;
          _allProducts = products;
          _isLoadingMetadata = false;
          _syncSelections();
        });
      }
    } catch (e) {
      debugPrint('Supabase metadata query failed: $e. Using fallback...');
      try {
        final classes = await _apiService.getProductClasses();
        final submodules = await _apiService.getProductSubmodules();
        final products = await _apiService.getProducts();
        if (mounted) {
          setState(() {
            _classes = classes;
            _submodules = submodules;
            _allProducts = products;
            _isLoadingMetadata = false;
            _syncSelections();
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingMetadata = false);
      }
    }
  }

  void _syncSelections() {
    final p = widget.existingProduct;

    // 1. Initial selection from existingProduct or initialClassName
    String? targetClassName = p?.className ?? widget.initialClassName;
    String? targetSubmoduleName = p?.submoduleName ?? widget.initialSubmoduleName;

    if (p != null && p.classId != null && p.classId!.isNotEmpty) {
      final found = _classes.where((c) => c.id == p.classId);
      if (found.isNotEmpty) _selectedProductClass = found.first;
    }
    if (_selectedProductClass == null && targetClassName != null && targetClassName.isNotEmpty) {
      final found = _classes.where((c) => c.name.toLowerCase() == targetClassName.toLowerCase());
      if (found.isNotEmpty) _selectedProductClass = found.first;
    }

    if (_selectedProductClass == null && _classes.isNotEmpty) {
      _selectedProductClass = _classes.first;
    }

    _section2SelectedClass ??= _selectedProductClass ?? (_classes.isNotEmpty ? _classes.first : null);

    // 2. Submodule selection
    if (_selectedProductClass != null) {
      final availableSubs = _getSubmodulesForClass(_selectedProductClass);
      if (p != null && p.submoduleId != null && p.submoduleId!.isNotEmpty) {
        final found = availableSubs.where((s) => s.id == p.submoduleId);
        if (found.isNotEmpty) _selectedProductSubmodule = found.first;
      }
      if (_selectedProductSubmodule == null && targetSubmoduleName != null && targetSubmoduleName.isNotEmpty) {
        final found = availableSubs.where((s) => s.name.toLowerCase() == targetSubmoduleName.toLowerCase());
        if (found.isNotEmpty) _selectedProductSubmodule = found.first;
      }

      if (_selectedProductSubmodule == null && availableSubs.isNotEmpty) {
        _selectedProductSubmodule = availableSubs.first;
      }
    }
  }

  List<ProductSubmodule> _getSubmodulesForClass(ProductClass? pc) {
    if (pc == null) return [];
    return _submodules.where((s) {
      if (s.classId != null && s.classId!.isNotEmpty && pc.id.isNotEmpty) {
        if (s.classId == pc.id) return true;
      }
      return s.className.toLowerCase() == pc.name.toLowerCase();
    }).toList();
  }

  List<Product> _getSavedProductsForCurrentSelection() {
    if (_selectedProductClass == null) return [];
    final cName = _selectedProductClass!.name.toLowerCase();
    final sName = _selectedProductSubmodule?.name.toLowerCase() ?? '';

    return _allProducts.where((p) {
      final pc = (p.className ?? '').toLowerCase();
      if (pc != cName) return false;
      if (sName.isNotEmpty) {
        final ps = (p.submoduleName ?? '').toLowerCase();
        return ps == sName;
      }
      return true;
    }).toList();
  }

  Future<void> _createClass() async {
    final name = _newClassCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Class name (e.g. CLASS I PIPE WORK)')),
      );
      return;
    }

    if (_classes.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Class "$name" already exists.')),
      );
      return;
    }

    setState(() => _isCreatingClass = true);

    try {
      final res = await _supabase.from('product_classes').insert({'name': name}).select().single();
      final newClass = ProductClass.fromJson(res);

      if (mounted) {
        setState(() {
          _classes.add(newClass);
          _classes.sort((a, b) => a.name.compareTo(b.name));
          _newClassCtrl.clear();
          _section2SelectedClass = newClass;
          _selectedProductClass = newClass;
          _selectedProductSubmodule = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class "$name" created successfully!'),
            backgroundColor: const Color(0xFF137333),
          ),
        );
      }
    } catch (e) {
      debugPrint('Supabase direct insert error: $e. Trying API...');
      try {
        final newClass = await _apiService.createProductClass(name);
        if (mounted) {
          setState(() {
            _classes.add(newClass);
            _classes.sort((a, b) => a.name.compareTo(b.name));
            _newClassCtrl.clear();
            _section2SelectedClass = newClass;
            _selectedProductClass = newClass;
            _selectedProductSubmodule = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Class "$name" created successfully!'),
              backgroundColor: const Color(0xFF137333),
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating class: $err'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCreatingClass = false);
    }
  }

  Future<void> _createSubmodule() async {
    final subName = _newSubmoduleCtrl.text.trim();
    if (_section2SelectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Class main heading first')),
      );
      return;
    }

    if (subName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Sub-module name (e.g. Pipe, Nominal bore)')),
      );
      return;
    }

    final currentClass = _section2SelectedClass!;
    final existingSubs = _getSubmodulesForClass(currentClass);
    if (existingSubs.any((s) => s.name.toLowerCase() == subName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sub-module "$subName" already exists under ${currentClass.name}.')),
      );
      return;
    }

    setState(() => _isCreatingSubmodule = true);

    final payload = {
      'class_id': currentClass.id.isNotEmpty ? currentClass.id : null,
      'class_name': currentClass.name,
      'name': subName,
    };

    try {
      final res = await _supabase.from('product_submodules').insert(payload).select().single();
      final newSub = ProductSubmodule.fromJson(res);

      if (mounted) {
        setState(() {
          _submodules.add(newSub);
          _submodules.sort((a, b) => a.name.compareTo(b.name));
          _newSubmoduleCtrl.clear();
          if (_selectedProductClass?.id == currentClass.id ||
              _selectedProductClass?.name.toLowerCase() == currentClass.name.toLowerCase()) {
            _selectedProductSubmodule = newSub;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sub-module "$subName" added to ${currentClass.name}!'),
            backgroundColor: const Color(0xFF137333),
          ),
        );
      }
    } catch (e) {
      debugPrint('Supabase direct insert error: $e. Trying API...');
      try {
        final newSub = await _apiService.createProductSubmodule(
          name: subName,
          className: currentClass.name,
          classId: currentClass.id,
        );
        if (mounted) {
          setState(() {
            _submodules.add(newSub);
            _submodules.sort((a, b) => a.name.compareTo(b.name));
            _newSubmoduleCtrl.clear();
            if (_selectedProductClass?.id == currentClass.id ||
                _selectedProductClass?.name.toLowerCase() == currentClass.name.toLowerCase()) {
              _selectedProductSubmodule = newSub;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sub-module "$subName" added to ${currentClass.name}!'),
              backgroundColor: const Color(0xFF137333),
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding sub-module: $err'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isCreatingSubmodule = false);
    }
  }

  Future<void> _deleteSubmodule(ProductSubmodule sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-module?'),
        content: Text('Are you sure you want to remove "${sub.name}" from ${sub.className}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('product_submodules').delete().eq('id', sub.id);
      if (mounted) {
        setState(() {
          _submodules.removeWhere((s) => s.id == sub.id);
          if (_selectedProductSubmodule?.id == sub.id) {
            final remaining = _getSubmodulesForClass(_selectedProductClass);
            _selectedProductSubmodule = remaining.isNotEmpty ? remaining.first : null;
          }
        });
      }
    } catch (_) {
      try {
        await _apiService.deleteProductSubmodule(sub.id);
        if (mounted) {
          setState(() {
            _submodules.removeWhere((s) => s.id == sub.id);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteExistingProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Specification?'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('products').delete().eq('id', product.id);
      if (mounted) {
        setState(() {
          _allProducts.removeWhere((p) => p.id == product.id);
          _hasSavedAny = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Specification deleted successfully')),
        );
      }
    } catch (_) {
      try {
        await _apiService.deleteProduct(product.id);
        if (mounted) {
          setState(() {
            _allProducts.removeWhere((p) => p.id == product.id);
            _hasSavedAny = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _addNewProductRow() {
    final lastUnit = _productRows.isNotEmpty ? _productRows.last.unitCtrl.text.trim() : 'METER';
    setState(() {
      _productRows.add(_ProductInputRow(unit: lastUnit.isNotEmpty ? lastUnit : 'METER'));
    });
  }

  void _removeProductRow(int index) {
    if (_productRows.length <= 1) return;
    setState(() {
      final removed = _productRows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _saveAllProducts() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Class / Main Heading in Section 3')),
      );
      return;
    }

    final validRows = _productRows.where((r) => r.nameCtrl.text.trim().isNotEmpty).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one Product / Specification Name')),
      );
      return;
    }

    final className = _selectedProductClass!.name;
    final classId = _selectedProductClass!.id;
    final subName = _selectedProductSubmodule?.name;
    final subId = _selectedProductSubmodule?.id;

    setState(() => _isSavingProducts = true);

    try {
      if (widget.existingProduct != null && validRows.length == 1) {
        // Edit existing single product
        final r = validRows.first;
        final payload = {
          'name': r.nameCtrl.text.trim(),
          'unit': r.unitCtrl.text.trim().isEmpty ? null : r.unitCtrl.text.trim(),
          'price': double.tryParse(r.priceCtrl.text.trim()) ?? 0.0,
          'class_name': className,
          'class_id': classId.isNotEmpty ? classId : null,
          'submodule_name': subName,
          'submodule_id': (subId != null && subId.isNotEmpty) ? subId : null,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('products').update(payload).eq('id', widget.existingProduct!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product "${r.nameCtrl.text.trim()}" updated successfully!'),
              backgroundColor: const Color(0xFF137333),
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      // Insert multiple products
      final payloads = validRows.map((r) {
        return {
          'name': r.nameCtrl.text.trim(),
          'unit': r.unitCtrl.text.trim().isEmpty ? null : r.unitCtrl.text.trim(),
          'price': double.tryParse(r.priceCtrl.text.trim()) ?? 0.0,
          'class_name': className,
          'class_id': classId.isNotEmpty ? classId : null,
          'submodule_name': subName,
          'submodule_id': (subId != null && subId.isNotEmpty) ? subId : null,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      final res = await _supabase.from('products').insert(payloads).select();
      final addedProducts = (res as List).map((j) => Product.fromJson(j)).toList();

      if (mounted) {
        final lastUnit = validRows.last.unitCtrl.text.trim();
        setState(() {
          _allProducts.insertAll(0, addedProducts);
          _hasSavedAny = true;

          // Clear inputs and keep 1 fresh row with the unit pre-filled
          for (final row in _productRows) {
            row.dispose();
          }
          _productRows.clear();
          _productRows.add(_ProductInputRow(unit: lastUnit));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${addedProducts.length} Product(s) / Specification(s) saved under ${subName ?? className}!',
            ),
            backgroundColor: const Color(0xFF137333),
          ),
        );
      }
    } catch (e) {
      debugPrint('Supabase direct insert error: $e. Trying fallback loop...');
      int successCount = 0;
      for (final r in validRows) {
        try {
          final payload = {
            'name': r.nameCtrl.text.trim(),
            'unit': r.unitCtrl.text.trim().isEmpty ? null : r.unitCtrl.text.trim(),
            'price': double.tryParse(r.priceCtrl.text.trim()) ?? 0.0,
            'class_name': className,
            'class_id': classId.isNotEmpty ? classId : null,
            'submodule_name': subName,
            'submodule_id': (subId != null && subId.isNotEmpty) ? subId : null,
          };
          final added = await _apiService.createProduct(payload);
          _allProducts.insert(0, added);
          successCount++;
        } catch (_) {}
      }

      if (mounted) {
        if (successCount > 0) {
          final lastUnit = validRows.last.unitCtrl.text.trim();
          setState(() {
            _hasSavedAny = true;
            for (final row in _productRows) {
              row.dispose();
            }
            _productRows.clear();
            _productRows.add(_ProductInputRow(unit: lastUnit));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount Product(s) saved successfully!'),
              backgroundColor: const Color(0xFF137333),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving products: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSavingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProduct != null;
    final savedProducts = _getSavedProductsForCurrentSelection();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // If we saved items and pop, notify parent
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(
            isEditing ? 'Edit Specification' : 'Add Products & Specifications',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0A2540),
          elevation: 1,
          actions: [
            if (_hasSavedAny)
              TextButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: _isLoadingMetadata
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== SECTION 1: CREATE CLASS ====================
                      _buildCard(
                        title: '1. Create Class (Main Heading)',
                        subtitle: 'e.g. CLASS I PIPE WORK, CLASS J PIPEWORK - FITTINGS',
                        icon: Icons.category_rounded,
                        accentColor: const Color(0xFF0284C7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _newClassCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Class Name / Main Heading',
                                      hintText: 'e.g. CLASS I PIPE WORK',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isCreatingClass ? null : _createClass,
                                    icon: _isCreatingClass
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.add, size: 18),
                                    label: const Text('Save Class', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                            if (_classes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Existing Classes:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _classes.map((c) {
                                  final isSelected = _selectedProductClass?.id == c.id ||
                                      _selectedProductClass?.name == c.name;
                                  return FilterChip(
                                    selected: isSelected,
                                    label: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    selectedColor: const Color(0xFFE0F2FE),
                                    checkmarkColor: const Color(0xFF0284C7),
                                    onSelected: (_) {
                                      setState(() {
                                        _section2SelectedClass = c;
                                        _selectedProductClass = c;
                                        final subs = _getSubmodulesForClass(c);
                                        _selectedProductSubmodule = subs.isNotEmpty ? subs.first : null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==================== SECTION 2: CLASS SUB-MODULES ====================
                      _buildCard(
                        title: '2. Class Sub-Modules',
                        subtitle: 'Add sub-modules under a main heading (e.g. Nominal bore, Pipe)',
                        icon: Icons.account_tree_outlined,
                        accentColor: const Color(0xFF0D9488),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dropdown to pick Main Heading for sub-modules
                            _buildDropdownField<ProductClass>(
                              label: 'Select Main Heading / Class',
                              prefixIcon: Icons.folder_open_rounded,
                              value: _section2SelectedClass != null &&
                                      _classes.any((c) => c.name == _section2SelectedClass!.name)
                                  ? _classes.firstWhere((c) => c.name == _section2SelectedClass!.name)
                                  : (_classes.isNotEmpty ? _classes.first : null),
                              items: _classes.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (c) {
                                if (c != null) {
                                  setState(() {
                                    _section2SelectedClass = c;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 12),

                            // Add sub-module row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _newSubmoduleCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Sub-Module Name',
                                      hintText: 'e.g. Pipe, Nominal bore',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      prefixIcon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9488),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isCreatingSubmodule ? null : _createSubmodule,
                                    icon: _isCreatingSubmodule
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.add, size: 18),
                                    label: const Text('Save Sub-Module', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Display existing submodules under the selected class
                            if (_section2SelectedClass != null) ...[
                              Builder(
                                builder: (context) {
                                  final currentSubs = _getSubmodulesForClass(_section2SelectedClass);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sub-Modules under "${_section2SelectedClass!.name}":',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (currentSubs.isEmpty)
                                        const Text(
                                          'No sub-modules added under this class yet. Enter one above!',
                                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                        )
                                      else
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: currentSubs.map((s) {
                                            return Chip(
                                              backgroundColor: const Color(0xFFCCFBF1),
                                              label: Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F766E),
                                                ),
                                              ),
                                              deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF0F766E)),
                                              onDeleted: () => _deleteSubmodule(s),
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ==================== SECTION 3: ADD PRODUCT / SPECIFICATIONS ====================
                      _buildCard(
                        title: '3. Add Products / Specifications',
                        subtitle: 'Select Class & Sub-Module, then add one or more specifications',
                        icon: Icons.inventory_2_rounded,
                        accentColor: const Color(0xFF0A2540),
                        headerAction: !isEditing
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: const Color(0xFF0A2540),
                                  side: const BorderSide(color: Color(0xFF0A2540)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _addNewProductRow,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add More (+)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Select Main Heading / Class
                            _buildDropdownField<ProductClass>(
                              label: '1. Select Main Heading / Class *',
                              prefixIcon: Icons.view_headline_rounded,
                              value: _selectedProductClass != null &&
                                      _classes.any((c) => c.name == _selectedProductClass!.name)
                                  ? _classes.firstWhere((c) => c.name == _selectedProductClass!.name)
                                  : (_classes.isNotEmpty ? _classes.first : null),
                              items: _classes.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (c) {
                                if (c != null) {
                                  setState(() {
                                    _selectedProductClass = c;
                                    final subs = _getSubmodulesForClass(c);
                                    _selectedProductSubmodule = subs.isNotEmpty ? subs.first : null;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 14),

                            // 2. Select Sub-Module (dynamically filtered by selected class)
                            Builder(
                              builder: (context) {
                                final currentSubs = _getSubmodulesForClass(_selectedProductClass);
                                return _buildDropdownField<ProductSubmodule>(
                                  label: '2. Select Sub-Module *',
                                  prefixIcon: Icons.subdirectory_arrow_right_rounded,
                                  hintText: currentSubs.isEmpty ? 'No sub-modules found for this class' : 'Select Sub-Module',
                                  value: _selectedProductSubmodule != null &&
                                          currentSubs.any((s) => s.name == _selectedProductSubmodule!.name)
                                      ? currentSubs.firstWhere((s) => s.name == _selectedProductSubmodule!.name)
                                      : (currentSubs.isNotEmpty ? currentSubs.first : null),
                                  items: currentSubs.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (s) {
                                    if (s != null) {
                                      setState(() => _selectedProductSubmodule = s);
                                    }
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Multiple Product / Specification Rows
                            for (int i = 0; i < _productRows.length; i++) ...[
                              _buildProductRowItem(i),
                              if (i < _productRows.length - 1) const SizedBox(height: 12),
                            ],

                            const SizedBox(height: 12),

                            // Add More Button
                            if (!isEditing)
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _addNewProductRow,
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    label: const Text('Add Another Specification / Item', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 16),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A2540),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isSavingProducts ? null : _saveAllProducts,
                                icon: _isSavingProducts
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  isEditing
                                      ? 'Update Specification'
                                      : (_productRows.length > 1
                                          ? 'Save All ${_productRows.length} Specifications'
                                          : 'Save Specification to Catalog'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================== SECTION 4: LIVE VIEW OF SAVED SPECIFICATIONS ====================
                      _buildSavedSpecificationsLiveCard(savedProducts),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProductRowItem(int index) {
    final row = _productRows[index];
    final isMultiple = _productRows.length > 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMultiple)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item / Specification #${index + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  tooltip: 'Remove Row',
                  onPressed: () => _removeProductRow(index),
                ),
              ],
            ),

          // Product / Specification Name Field
          TextFormField(
            controller: row.nameCtrl,
            decoration: InputDecoration(
              labelText: isMultiple ? 'Product / Specification #${index + 1} *' : 'Product Name / Specification *',
              hintText: 'e.g. In trenches, depth not exceeding 1.50 m',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
            ),
            validator: (v) {
              if (index == 0 && (v == null || v.trim().isEmpty)) {
                return 'Specification Name is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 10),

          // Unit Field & Price Field in a Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: row.unitCtrl,
                  decoration: InputDecoration(
                    labelText: 'Unit *',
                    hintText: 'e.g. METER, LM, PCS',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
                  ),
                  validator: (v) {
                    if (row.nameCtrl.text.trim().isNotEmpty && (v == null || v.trim().isEmpty)) {
                      return 'Unit is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: row.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price / Rate (BHD)',
                    hintText: '0.00',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    prefixText: 'BHD ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick unit selector chips for this row
          Wrap(
            spacing: 6,
            children: _commonUnits.map((u) {
              return InkWell(
                onTap: () => setState(() => row.unitCtrl.text = u),
                child: Chip(
                  label: Text(u, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSpecificationsLiveCard(List<Product> savedProducts) {
    final hasSelection = _selectedProductClass != null;
    final isSameName = _selectedProductClass != null &&
        _selectedProductSubmodule != null &&
        _selectedProductClass!.name.trim().toLowerCase() ==
            _selectedProductSubmodule!.name.trim().toLowerCase();

    final title = _selectedProductSubmodule != null
        ? (isSameName
            ? _selectedProductClass!.name
            : '${_selectedProductClass!.name} > ${_selectedProductSubmodule!.name}')
        : (_selectedProductClass?.name ?? 'All');

    return _buildCard(
      title: 'Saved Specifications in Catalog',
      subtitle: 'Currently stored under "$title" (${savedProducts.length} items)',
      icon: Icons.list_alt_rounded,
      accentColor: const Color(0xFF7C3AED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasSelection)
            const Text(
              'Select a Class and Sub-Module above to view saved specifications.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else if (savedProducts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No products or specifications saved under this sub-module yet.\nAdd them above!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: savedProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, idx) {
                final prod = savedProducts[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prod.name,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (prod.unit != null && prod.unit!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'Unit: ${prod.unit}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'BHD ${prod.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                      tooltip: 'Delete Item',
                      onPressed: () => _deleteExistingProduct(prod),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData prefixIcon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hintText,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(prefixIcon, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: hintText != null ? Text(hintText, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))) : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget child,
    Widget? headerAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              border: Border(
                top: BorderSide(color: accentColor, width: 3),
                bottom: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (headerAction != null) headerAction,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
