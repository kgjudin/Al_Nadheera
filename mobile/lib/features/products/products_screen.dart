import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/profile_avatar_button.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import 'add_product_screen.dart';

class _ProductsCatalogData {
  final List<Product> products;
  final List<ProductClass> classes;
  final List<ProductSubmodule> submodules;

  _ProductsCatalogData({
    required this.products,
    required this.classes,
    required this.submodules,
  });
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService();

  late Future<_ProductsCatalogData> _dataFuture;
  String _searchQuery = '';
  String _selectedClassFilter = 'All';
  bool _isGroupedView = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchCatalogData();
    });
  }

  Future<_ProductsCatalogData> _fetchCatalogData() async {
    List<Product> products = [];
    List<ProductClass> classes = [];
    List<ProductSubmodule> submodules = [];

    // 1. Fetch products
    try {
      final pRes = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);
      products = (pRes as List).map((j) => Product.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Supabase products fetch failed: $e. Using fallback...');
      try {
        products = await _apiService.getProducts();
      } catch (e2) {
        debugPrint('Fallback getProducts failed: $e2');
      }
    }

    // 2. Fetch classes
    try {
      final cRes = await _supabase.from('product_classes').select().order('name');
      classes = (cRes as List).map((j) => ProductClass.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Supabase classes fetch failed: $e. Using fallback...');
      try {
        classes = await _apiService.getProductClasses();
      } catch (e2) {
        debugPrint('Fallback getProductClasses failed: $e2');
      }
    }

    // 3. Fetch submodules
    try {
      final sRes = await _supabase.from('product_submodules').select().order('name');
      submodules = (sRes as List).map((j) => ProductSubmodule.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Supabase submodules fetch failed: $e. Using fallback...');
      try {
        submodules = await _apiService.getProductSubmodules();
      } catch (e2) {
        debugPrint('Fallback getProductSubmodules failed: $e2');
      }
    }

    return _ProductsCatalogData(
      products: products,
      classes: classes,
      submodules: submodules,
    );
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      debugPrint('Supabase direct delete error: $e. Trying backend API...');
      await _apiService.deleteProduct(id);
    }
    _loadData();
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Specification'),
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
                    const SnackBar(content: Text('Specification deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error deleting specification: $e')),
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

  void _openAddEditProductScreen({
    Product? existingProduct,
    String? initialClassName,
    String? initialSubmoduleName,
  }) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          existingProduct: existingProduct,
          initialClassName: initialClassName,
          initialSubmoduleName: initialSubmoduleName,
        ),
      ),
    ).then((saved) {
      if (saved == true) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Products & Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2540),
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _isGroupedView ? Icons.view_agenda_outlined : Icons.account_tree_outlined,
              color: const Color(0xFF0A2540),
            ),
            tooltip: _isGroupedView ? 'Switch to Flat List' : 'Switch to Hierarchical View',
            onPressed: () {
              setState(() {
                _isGroupedView = !_isGroupedView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          await _dataFuture;
        },
        child: FutureBuilder<_ProductsCatalogData>(
          future: _dataFuture,
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
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData ||
                (snapshot.data!.products.isEmpty &&
                    snapshot.data!.classes.isEmpty &&
                    snapshot.data!.submodules.isEmpty)) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      const Text(
                        'No products added yet.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create classes (main headings), sub-modules, and product specifications with units and rates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2540),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openAddEditProductScreen(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Class, Sub-Module & Products'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final allProducts = data.products;

            // Extract unique class names for filter chips
            final classesSet = <String>{'All'};
            for (final c in data.classes) {
              if (c.name.trim().isNotEmpty) classesSet.add(c.name.trim());
            }
            for (final p in allProducts) {
              if (p.className != null && p.className!.trim().isNotEmpty) {
                classesSet.add(p.className!.trim());
              }
            }
            final classesList = classesSet.toList();

            // Filter products
            final filteredProducts = allProducts.where((p) {
              final query = _searchQuery.toLowerCase().trim();
              final matchesQuery = query.isEmpty ||
                  p.name.toLowerCase().contains(query) ||
                  (p.unit != null && p.unit!.toLowerCase().contains(query)) ||
                  (p.className != null && p.className!.toLowerCase().contains(query)) ||
                  (p.submoduleName != null && p.submoduleName!.toLowerCase().contains(query));

              final matchesClass = _selectedClassFilter == 'All' ||
                  (p.className != null && p.className!.trim() == _selectedClassFilter.trim());

              return matchesQuery && matchesClass;
            }).toList();

            return Column(
              children: [
                // Top Search and Filter Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search specification, class, or sub-module...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),

                      const SizedBox(height: 10),

                      // Class Filter Horizontal Chips
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: classesList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final c = classesList[i];
                            final isSelected = _selectedClassFilter == c;
                            return FilterChip(
                              selected: isSelected,
                              label: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                              backgroundColor: const Color(0xFFF1F5F9),
                              selectedColor: const Color(0xFF0A2540),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF0A2540) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              onSelected: (_) => setState(() => _selectedClassFilter = c),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Products Count Summary and View Mode Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredProducts.length} specifications found',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _isGroupedView = true),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isGroupedView ? const Color(0xFF0A2540) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isGroupedView ? const Color(0xFF0A2540) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_tree_outlined,
                                    size: 14,
                                    color: _isGroupedView ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hierarchy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _isGroupedView ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _isGroupedView = false),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_isGroupedView ? const Color(0xFF0A2540) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: !_isGroupedView ? const Color(0xFF0A2540) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.view_agenda_outlined,
                                    size: 14,
                                    color: !_isGroupedView ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Flat List',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: !_isGroupedView ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content View
                Expanded(
                  child: filteredProducts.isEmpty &&
                          (data.classes.isEmpty || _selectedClassFilter != 'All' || _searchQuery.isNotEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedClassFilter != 'All'
                                      ? 'No specifications saved under "$_selectedClassFilter" yet.'
                                      : 'No specifications match your search or filter.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A2540),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _openAddEditProductScreen(
                                    initialClassName: _selectedClassFilter != 'All' ? _selectedClassFilter : null,
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(
                                    _selectedClassFilter != 'All'
                                        ? 'Add Specification for $_selectedClassFilter'
                                        : 'Add Specification',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isGroupedView
                          ? _buildHierarchicalView(data, filteredProducts)
                          : _buildFlatListView(filteredProducts),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        onPressed: () => _openAddEditProductScreen(
          initialClassName: _selectedClassFilter != 'All' ? _selectedClassFilter : null,
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Specification', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFlatListView(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildHierarchicalView(_ProductsCatalogData data, List<Product> filteredProducts) {
    // 1. Group filtered products by Class and Submodule
    final Map<String, Map<String, List<Product>>> grouped = {};

    // Seed classes from data.classes (filtered if selected)
    for (final c in data.classes) {
      final cName = c.name.trim();
      if (_selectedClassFilter == 'All' || _selectedClassFilter.trim() == cName) {
        grouped.putIfAbsent(cName, () => {});
      }
    }

    // Seed submodules from data.submodules
    for (final s in data.submodules) {
      final cName = s.className.trim();
      final sName = s.name.trim();
      if (grouped.containsKey(cName)) {
        grouped[cName]!.putIfAbsent(sName, () => []);
      }
    }

    // Distribute filtered products into the hierarchy
    for (final p in filteredProducts) {
      final cName = (p.className != null && p.className!.trim().isNotEmpty)
          ? p.className!.trim()
          : 'General / Unclassified';
      final sName = (p.submoduleName != null && p.submoduleName!.trim().isNotEmpty)
          ? p.submoduleName!.trim()
          : 'General Specifications';

      if (_selectedClassFilter == 'All' || _selectedClassFilter.trim() == cName) {
        grouped.putIfAbsent(cName, () => {});
        grouped[cName]!.putIfAbsent(sName, () => []);
        if (!grouped[cName]![sName]!.any((x) => x.id == p.id)) {
          grouped[cName]![sName]!.add(p);
        }
      }
    }

    // In saved specifications view:
    // 1. Remove empty submodules if there are no specs in them so they don't list down down
    grouped.forEach((cName, subMap) {
      subMap.removeWhere((sName, specs) => specs.isEmpty);
    });

    // 2. If viewing 'All' classes (or searching), remove classes that have 0 specifications
    if (_selectedClassFilter == 'All' || _searchQuery.trim().isNotEmpty) {
      grouped.removeWhere((cName, subMap) => subMap.isEmpty);
    }

    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                _selectedClassFilter != 'All'
                    ? 'No specifications saved under "$_selectedClassFilter" yet.'
                    : 'No matching classes or specifications found.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2540),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openAddEditProductScreen(
                  initialClassName: _selectedClassFilter != 'All' ? _selectedClassFilter : null,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  _selectedClassFilter != 'All'
                      ? 'Add Specification for $_selectedClassFilter'
                      : 'Add Specification',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final classEntries = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: classEntries.length,
      itemBuilder: (context, index) {
        final classEntry = classEntries[index];
        final className = classEntry.key;
        final submodulesMap = classEntry.value;

        int totalSpecsInClass = 0;
        for (final list in submodulesMap.values) {
          totalSpecsInClass += list.length;
        }

        // Check if all items in this class share the same name as the class
        final isSingleSameName = submodulesMap.length == 1 &&
            (submodulesMap.keys.first.trim().toLowerCase() == className.trim().toLowerCase() ||
                submodulesMap.keys.first.trim().isEmpty ||
                submodulesMap.keys.first == 'General Specifications');

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Class Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A2540), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_special_rounded, color: Color(0xFF67E8F9), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            isSingleSameName
                                ? '$totalSpecsInClass Specifications'
                                : '${submodulesMap.length} Sub-modules • $totalSpecsInClass Specifications',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
                      tooltip: 'Add specification under $className',
                      onPressed: () => _openAddEditProductScreen(initialClassName: className),
                    ),
                  ],
                ),
              ),

              // Sub-modules & Specifications Body
              if (submodulesMap.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No specifications saved under "$className" yet.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openAddEditProductScreen(initialClassName: className),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Specification', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: submodulesMap.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, subIdx) {
                    final subEntry = submodulesMap.entries.elementAt(subIdx);
                    final subName = subEntry.key;
                    final specs = subEntry.value;

                    // If Class name and Sub name are the same, show as ONE unified section
                    final isSameName = subName.trim().toLowerCase() == className.trim().toLowerCase() ||
                        subName.trim().isEmpty ||
                        subName == 'General Specifications';

                    return Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only show Submodule header row if Class name and Sub name are DIFFERENT
                          if (!isSameName) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFBF1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.subdirectory_arrow_right_rounded,
                                    size: 16,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          subName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          '${specs.length}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(color: Color(0xFF0D9488)),
                                    foregroundColor: const Color(0xFF0F766E),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => _openAddEditProductScreen(
                                    initialClassName: className,
                                    initialSubmoduleName: subName,
                                  ),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add Spec', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Specifications list inside this group
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: specs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, specIdx) {
                              final product = specs[specIdx];
                              return Container(
                                margin: EdgeInsets.only(left: isSameName ? 0 : 20),
                                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Bullet index
                                    Text(
                                      '${specIdx + 1}.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Specification Name & Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              if (product.unit != null && product.unit!.isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                                  ),
                                                  child: Text(
                                                    product.unit!,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                'Rate: BHD ${product.price.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0A2540),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Edit and Delete Actions
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                      tooltip: 'Edit Specification',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _openAddEditProductScreen(existingProduct: product),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                      tooltip: 'Delete Specification',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteProduct(product),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final hasClass = product.className != null && product.className!.isNotEmpty;
    final hasSub = product.submoduleName != null && product.submoduleName!.isNotEmpty;
    final isSameName = hasClass &&
        hasSub &&
        product.className!.trim().toLowerCase() == product.submoduleName!.trim().toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class and Sub-module badges: if same name, show as ONE badge
            if (hasClass || hasSub) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (hasClass)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_outlined, size: 12, color: Color(0xFF0369A1)),
                          const SizedBox(width: 4),
                          Text(
                            product.className!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasSub && !isSameName)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: Color(0xFF0F766E)),
                          const SizedBox(width: 4),
                          Text(
                            product.submoduleName!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Product Name and Menu Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openAddEditProductScreen(existingProduct: product);
                    } else if (value == 'delete') {
                      _confirmDeleteProduct(product);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Specification'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Specification', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Unit and Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (product.unit != null && product.unit!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Unit: ${product.unit}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  'BHD ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2540),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
