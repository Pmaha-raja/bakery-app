import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

// ─── Expense Model ────────────────────────────────────────────────────────────
class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'].toString(),
        title: j['title'] as String,
        amount: double.tryParse(j['amount'].toString()) ?? 0,
        category: j['category'] as String? ?? 'General',
        note: j['note'] as String?,
        date: DateTime.tryParse(j['expense_date']?.toString() ?? '') ??
            DateTime.now(),
      );
}

// ─── Categories ───────────────────────────────────────────────────────────────
const _expenseCategories = [
  '🧾 General',
  '🛒 Raw Materials',
  '💡 Electricity',
  '🏠 Rent',
  '👨‍🍳 Staff Salary',
  '🚚 Delivery',
  '🔧 Maintenance',
  '📦 Packaging',
  '💊 Miscellaneous',
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class ExpensesScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const ExpensesScreen({super.key, this.onNavigate});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isLoading = true;
  List<Expense> _expenses = [];
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final res = await _db
          .from('vkb_expenses')
          .select()
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _expenses =
              (res as List).map((e) => Expense.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Expense> get _filtered {
    if (_filterCategory == null) return _expenses;
    return _expenses
        .where((e) => e.category == _filterCategory)
        .toList();
  }

  double get _totalAmount =>
      _filtered.fold(0, (s, e) => s + e.amount);

  double get _todayAmount {
    final today = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.day == today.day &&
            e.date.month == today.month &&
            e.date.year == today.year)
        .fold(0, (s, e) => s + e.amount);
  }

  void _showAddDialog({Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(
        expense: expense,
        onSave: (title, amount, category, note, date) async {
          if (expense == null) {
            await _db.from('vkb_expenses').insert({
              'title': title,
              'amount': amount,
              'category': category,
              'note': note,
              'expense_date': date.toIso8601String().substring(0, 10),
            });
          } else {
            await _db.from('vkb_expenses').update({
              'title': title,
              'amount': amount,
              'category': category,
              'note': note,
              'expense_date': date.toIso8601String().substring(0, 10),
            }).eq('id', int.parse(expense.id));
          }
          await _loadExpenses();
        },
      ),
    );
  }

  void _deleteExpense(String id) async {
    await _db
        .from('vkb_expenses')
        .delete()
        .eq('id', int.parse(id));
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AppShell(
      title: 'Expenses',
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          onPressed: _loadExpenses,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Summary Cards
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: _SummaryCard(
                  label: "Today's Expense",
                  value: '₹${_todayAmount.toStringAsFixed(0)}',
                  color: AppColors.error,
                  icon: Icons.today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Total Expense',
                  value: '₹${_totalAmount.toStringAsFixed(0)}',
                  color: AppColors.primary,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // ── Category Filter
          Container(
            color: AppColors.surfaceVariant,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _filterCategory == null,
                    onTap: () =>
                        setState(() => _filterCategory = null),
                  ),
                  ..._expenseCategories.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: c,
                          isSelected: _filterCategory == c,
                          onTap: () =>
                              setState(() => _filterCategory = c),
                        ),
                      )),
                ],
              ),
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
                    ? const EmptyState(
                        emoji: '🧾',
                        title: 'No expenses found',
                        subtitle: 'Tap + to add your first expense',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ExpenseCard(
                          expense: filtered[i],
                          onEdit: () =>
                              _showAddDialog(expense: filtered[i]),
                          onDelete: () =>
                              _deleteExpense(filtered[i].id),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Poppins')),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins')),
              ],
            ),
          ),
        ]),
      );
}

// ─── Expense Card ─────────────────────────────────────────────────────────────
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard(
      {required this.expense,
      required this.onEdit,
      required this.onDelete});

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
        // Category emoji circle
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.errorSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              expense.category.split(' ').first,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expense.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.category.replaceAll(RegExp(r'^\S+\s'), ''),
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryDark,
                        fontFamily: 'Poppins'),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontFamily: 'Poppins'),
                ),
              ]),
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(expense.note!,
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
        // Amount + Actions
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    fontFamily: 'Poppins')),
            Row(children: [
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_rounded,
                    size: 16, color: AppColors.error),
              ),
            ]),
          ],
        ),
      ]),
    );
  }
}

// ─── Expense Form Sheet ───────────────────────────────────────────────────────
class _ExpenseFormSheet extends StatefulWidget {
  final Expense? expense;
  final Future<void> Function(
      String, double, String, String?, DateTime) onSave;

  const _ExpenseFormSheet({this.expense, required this.onSave});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedCategory = _expenseCategories[0];
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      final e = widget.expense!;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
      _selectedCategory = e.category;
      _selectedDate = e.date;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    await widget.onSave(
      _titleCtrl.text.trim(),
      double.tryParse(_amountCtrl.text) ?? 0,
      _selectedCategory,
      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      _selectedDate,
    );
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              widget.expense == null ? '➕ Add Expense' : '✏️ Edit Expense',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 20),
            // Title
            const Text('Expense Title',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Flour purchase',
                prefixIcon: Icon(Icons.title_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            // Amount
            const Text('Amount (₹)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
              ],
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 14),
            // Category
            const Text('Category',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(),
              items: _expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            const SizedBox(height: 14),
            // Date
            const Text('Date',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            // Note
            const Text('Note (Optional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional notes...',
              ),
            ),
            const SizedBox(height: 20),
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
                  label: widget.expense == null ? 'Save' : 'Update',
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

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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