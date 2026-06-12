import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

// ─── Customer Model ───────────────────────────────────────────────────────────
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String category;
  final String? note;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.category,
    this.note,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'].toString(),
        name: j['name'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        category: j['category'] as String? ?? 'Regular',
        note: j['note'] as String?,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

const _customerCategories = [
  'Regular',
  'Wholesale',
  'Hotel',
  'Restaurant',
  'Canteen',
  'Retail Shop',
  'Online',
  'VIP',
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class CustomersScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const CustomersScreen({super.key, this.onNavigate});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _isLoading = true;
  List<Customer> _customers = [];
  String _searchQuery = '';
  String? _filterCategory;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final res = await _db
          .from('vkb_customers')
          .select()
          .order('name');
      if (mounted) {
        setState(() {
          _customers =
              (res as List).map((e) => Customer.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Customer> get _filtered {
    return _customers.where((c) {
      final matchSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.phone ?? '').contains(_searchQuery);
      final matchCat =
          _filterCategory == null || c.category == _filterCategory;
      return matchSearch && matchCat;
    }).toList();
  }

  void _showAddEdit({Customer? customer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerFormSheet(
        customer: customer,
        onSave: (name, phone, address, category, note) async {
          if (customer == null) {
            await _db.from('vkb_customers').insert({
              'name': name,
              'phone': phone,
              'address': address,
              'category': category,
              'note': note,
            });
          } else {
            await _db.from('vkb_customers').update({
              'name': name,
              'phone': phone,
              'address': address,
              'category': category,
              'note': note,
            }).eq('id', int.parse(customer.id));
          }
          await _loadCustomers();
        },
      ),
    );
  }

  void _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.from('vkb_customers').delete().eq('id', int.parse(id));
      await _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AppShell(
      title: 'Customers',
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          onPressed: _loadCustomers,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEdit(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Search + Filter
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        label: 'All (${_customers.length})',
                        isSelected: _filterCategory == null,
                        onTap: () =>
                            setState(() => _filterCategory = null),
                      ),
                      ..._customerCategories.map((c) {
                        final count = _customers
                            .where((x) => x.category == c)
                            .length;
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _Chip(
                            label: '$c ($count)',
                            isSelected: _filterCategory == c,
                            onTap: () =>
                                setState(() => _filterCategory = c),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Summary
          Container(
            color: AppColors.surfaceVariant,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.people_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${filtered.length} customers',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : filtered.isEmpty
                    ? EmptyState(
                        emoji: '👤',
                        title: 'No customers found',
                        subtitle: 'Tap + to add your first customer',
                        action: VKBButton(
                          label: 'Add Customer',
                          icon: Icons.person_add_rounded,
                          onTap: () => _showAddEdit(),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CustomerCard(
                          customer: filtered[i],
                          onEdit: () =>
                              _showAddEdit(customer: filtered[i]),
                          onDelete: () => _delete(filtered[i].id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Card ────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard(
      {required this.customer, required this.onEdit, required this.onDelete});

  Color get _catColor {
    switch (customer.category) {
      case 'VIP':
        return const Color(0xFF9C6FDE);
      case 'Wholesale':
        return AppColors.info;
      case 'Hotel':
      case 'Restaurant':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _catColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: _catColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Center(
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _catColor,
                  fontFamily: 'Poppins'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                if (customer.phone != null) ...[
                  const Icon(Icons.phone_rounded,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(customer.phone!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins')),
                  const SizedBox(width: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(customer.category,
                      style: TextStyle(
                          fontSize: 10,
                          color: _catColor,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins')),
                ),
              ]),
              if (customer.address != null &&
                  customer.address!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(customer.address!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontFamily: 'Poppins'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              if (customer.note != null &&
                  customer.note!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(customer.note!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins',
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        // Actions
        Column(children: [
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_rounded,
                size: 18, color: AppColors.error),
          ),
        ]),
      ]),
    );
  }
}

// ─── Customer Form Sheet ──────────────────────────────────────────────────────
class _CustomerFormSheet extends StatefulWidget {
  final Customer? customer;
  final Future<void> Function(
      String, String?, String?, String, String?) onSave;

  const _CustomerFormSheet({this.customer, required this.onSave});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedCategory = _customerCategories[0];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone ?? '';
      _addressCtrl.text = c.address ?? '';
      _noteCtrl.text = c.note ?? '';
      _selectedCategory = c.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _nameCtrl.text.trim(),
      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      _selectedCategory,
      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              widget.customer == null
                  ? '👤 Add Customer'
                  : '✏️ Edit Customer',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 20),

            // Name
            _Label('Customer Name *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Ravi Kumar',
                prefixIcon: Icon(Icons.person_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Phone
            _Label('Phone Number'),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '9876543210',
                prefixIcon: Icon(Icons.phone_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Category
            _Label('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.label_rounded, size: 18),
              ),
              items: _customerCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            const SizedBox(height: 14),

            // Address
            _Label('Address'),
            const SizedBox(height: 6),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Street, City...',
                prefixIcon: Icon(Icons.location_on_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // Note
            _Label('Note (Optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Any special notes...',
              ),
            ),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VKBButton(
                  label: widget.customer == null ? 'Save' : 'Update',
                  isLoading: _isSaving,
                  onTap: _save,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontFamily: 'Poppins'));
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppColors.primaryDark)),
        ),
      );
}