import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class ProductsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const ProductsScreen({super.key, this.onNavigate});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategoryFilter; // stores category NAME (not id)
  final TextEditingController _searchController = TextEditingController();

  List<Category> _categories = [];
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final cats = await SupabaseService().getCategories();
    final prods = await SupabaseService().getProducts();
    if (mounted) {
      setState(() {
        _categories = cats;
        _products = prods;
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    return _products.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      // categoryId = category name in our bridge
      final matchesCategory = _selectedCategoryFilter == null ||
          p.categoryId == _selectedCategoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  // categoryId = category name (bridge)
  String _getCategoryName(String categoryId) => categoryId;

  void _showAddEditDialog({Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(
        categories: _categories,
        product: product,
        onSave: (p) async {
          if (product == null) {
            // CREATE
            final created = await SupabaseService().createProduct(p);
            setState(() => _products.add(created));
          } else {
            // UPDATE
            final updated = await SupabaseService().updateProduct(p);
            setState(() {
              final idx = _products.indexWhere((x) => x.id == product.id);
              if (idx != -1) _products[idx] = updated;
            });
          }
        },
      ),
    );
  }

  void _showManageCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageCategoriesSheet(
        categories: _categories,
        onAdd: (cat) async {
          final created = await SupabaseService().createCategory(cat);
          setState(() => _categories.add(created));
        },
        onDelete: (id) async {
          await SupabaseService().deleteCategory(id);
          setState(() => _categories.removeWhere((c) => c.id == id));
        },
      ),
    );
  }

  void _deleteProduct(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await SupabaseService().deleteProduct(id);
              setState(() => _products.removeWhere((p) => p.id == id));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleProductStatus(Product p) async {
    final newStock = p.isActive ? 0 : 10; // toggle active via stock
    await SupabaseService().updateStock(p.id, newStock);
    setState(() {
      final idx = _products.indexWhere((x) => x.id == p.id);
      if (idx != -1) {
        _products[idx] = p.copyWith(
            isActive: !p.isActive, stock: newStock);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return AppShell(
      title: 'Product Management',
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: _showManageCategories,
          icon: const Icon(Icons.label_rounded, color: AppColors.primary),
          tooltip: 'Manage Categories',
        ),
      ],
      body: Column(
        children: [
          // ── Toolbar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                // Category Filter Chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedCategoryFilter == null,
                        onTap: () =>
                            setState(() => _selectedCategoryFilter = null),
                      ),
                      ..._categories.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label: '${c.emoji} ${c.name}',
                              // filter by name (bridge)
                              isSelected: _selectedCategoryFilter == c.name,
                              onTap: () => setState(
                                  () => _selectedCategoryFilter = c.name),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Product List
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? EmptyState(
                        emoji: '🍰',
                        title: 'No products found',
                        subtitle: _products.isEmpty
                            ? 'Add your first product!'
                            : 'Try different filter',
                        action: _products.isEmpty
                            ? VKBButton(
                                label: 'Add Product',
                                icon: Icons.add_rounded,
                                onTap: () => _showAddEditDialog(),
                              )
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ProductCard(
                          product: filtered[i],
                          categoryName:
                              _getCategoryName(filtered[i].categoryId),
                          onEdit: () =>
                              _showAddEditDialog(product: filtered[i]),
                          onDelete: () => _deleteProduct(filtered[i].id),
                          onToggle: () => _toggleProductStatus(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.stock > 0 && product.stock <= 5;
    final isOutOfStock = product.stock == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? AppColors.error.withValues(alpha: 0.3)
              : isLowStock
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Emoji / Image
         // இதா REPLACE பண்ணுங்க:
Container(
  width: 52,
  height: 52,
  decoration: BoxDecoration(
    color: AppColors.primarySurface,
    borderRadius: BorderRadius.circular(10),
  ),
  clipBehavior: Clip.antiAlias,
  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
      ? Image.network(
          product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(product.emoji,
                style: const TextStyle(fontSize: 26)),
          ),
        )
      : Center(
          child: Text(product.emoji,
              style: const TextStyle(fontSize: 26)),
        ),
),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(categoryName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryDark,
                            fontFamily: 'Poppins')),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.errorSurface
                          : isLowStock
                              ? AppColors.warningSurface
                              : AppColors.successSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'Out of stock'
                          : isLowStock
                              ? 'Low: ${product.stock}'
                              : 'Stock: ${product.stock}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isOutOfStock
                              ? AppColors.error
                              : isLowStock
                                  ? AppColors.warning
                                  : AppColors.success,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('₹${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontFamily: 'Poppins')),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    size: 18, color: AppColors.primary),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded,
                    size: 18, color: AppColors.error),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primaryLight.withValues(alpha: 0.4)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.primaryDark)),
        ),
      );
}

// ─── Product Form Sheet ───────────────────────────────────────────────────────
class _ProductFormSheet extends StatefulWidget {
  final List<Category> categories;
  final Product? product;
  final Future<void> Function(Product) onSave;

  const _ProductFormSheet(
      {required this.categories, this.product, required this.onSave});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '🍰');
  late String _selectedCategoryName;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toString();
      _stockCtrl.text = p.stock.toString();
      _emojiCtrl.text = p.emoji;
      _selectedCategoryName = p.categoryId; // categoryId = name
      _isActive = p.isActive;
    } else {
      _selectedCategoryName =
          widget.categories.isNotEmpty ? widget.categories[0].name : '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);

    final p = Product(
      id: widget.product?.id ?? '',
      emoji: _emojiCtrl.text.trim().isEmpty ? '🍰' : _emojiCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      categoryId: _selectedCategoryName, // name as bridge
      price: double.tryParse(_priceCtrl.text) ?? 0,
      stock: int.tryParse(_stockCtrl.text) ?? 0,
      isActive: _isActive,
    );

    await widget.onSave(p);
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
                widget.product == null ? '➕ Add Product' : '✏️ Edit Product',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 20),
            // Emoji + Name row
            Row(children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emojiCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                  decoration: const InputDecoration(
                      hintText: '🍰',
                      contentPadding: EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Product name'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategoryName.isNotEmpty &&
                      widget.categories.any((c) => c.name == _selectedCategoryName)
                  ? _selectedCategoryName
                  : (widget.categories.isNotEmpty ? widget.categories[0].name : null),
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map((c) => DropdownMenuItem(
                      value: c.name,
                      child: Text('${c.emoji} ${c.name}')))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategoryName = v ?? ''),
            ),
            const SizedBox(height: 14),
            // Price + Stock row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Price (₹)', prefixText: '₹ '),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock Qty'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            // Active toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    Switch(
                        value: _isActive,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isActive = v)),
                  ]),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VKBButton(
                  label: widget.product == null ? 'Save Product' : 'Update',
                  isLoading: _isSaving,
                  onTap: _save,
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Manage Categories Sheet ──────────────────────────────────────────────────
class _ManageCategoriesSheet extends StatefulWidget {
  final List<Category> categories;
  final Future<void> Function(Category) onAdd;
  final Future<void> Function(String) onDelete;

  const _ManageCategoriesSheet(
      {required this.categories,
      required this.onAdd,
      required this.onDelete});

  @override
  State<_ManageCategoriesSheet> createState() =>
      _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState
    extends State<_ManageCategoriesSheet> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '🏷️');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    await widget.onAdd(Category(
      id: '',
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '🏷️' : _emojiCtrl.text.trim(),
    ));
    setState(() {
      _isSaving = false;
      _nameCtrl.clear();
      _emojiCtrl.text = '🏷️';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Row(children: [
                Text('🏷️ ', style: TextStyle(fontSize: 18)),
                Text('Manage Categories',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins')),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _emojiCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                    decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Category name...')),
                ),
                const SizedBox(width: 10),
                VKBButton(
                    label: 'Add',
                    isSmall: true,
                    isLoading: _isSaving,
                    icon: Icons.add_rounded,
                    onTap: _add),
              ]),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.categories.isEmpty
                ? const Center(
                    child: Text('No categories yet',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final cat = widget.categories[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Text(cat.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(cat.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins'))),
                          IconButton(
                            icon: const Icon(Icons.delete_rounded,
                                size: 18),
                            color: AppColors.error,
                            onPressed: () async {
                              await widget.onDelete(cat.id);
                              setState(() {});
                            },
                          ),
                        ]),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ),
          ),
        ],
      ),
    );
  }
}