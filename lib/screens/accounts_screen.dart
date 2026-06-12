import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

// ─── Models ───────────────────────────────────────────────────────────────────
class AccountEntry {
  final String id;
  final String title;
  final double amount;
  final String type;
  final String? note;
  final DateTime date;
  final String? customerName;
  final String? customerId;

  AccountEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    this.note,
    required this.date,
    this.customerName,
    this.customerId,
  });

  bool get isCredit => type == 'credit';

  factory AccountEntry.fromJson(Map<String, dynamic> j) => AccountEntry(
        id: j['id'].toString(),
        title: j['title'] as String,
        amount: double.tryParse(j['amount'].toString()) ?? 0,
        type: j['type'] as String? ?? 'debit',
        note: j['note'] as String?,
        date: DateTime.tryParse(j['account_date']?.toString() ?? '') ??
            DateTime.now(),
        customerName: j['customer_name'] as String?,
        customerId: j['customer_id']?.toString(),
      );
}

class _CustomerOption {
  final String id;
  final String name;
  final String? phone;
  _CustomerOption(this.id, this.name, this.phone);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AccountsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const AccountsScreen({super.key, this.onNavigate});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;
  List<AccountEntry> _entries = [];
  List<_CustomerOption> _customers = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _db
            .from('vkb_accounts')
            .select()
            .order('account_date', ascending: false)
            .order('created_at', ascending: false)
            .limit(200),
        _db.from('vkb_customers').select('id, name, phone').order('name'),
      ]);
      if (mounted) {
        setState(() {
          _entries = (results[0] as List)
              .map((e) => AccountEntry.fromJson(e))
              .toList();
          _customers = (results[1] as List)
              .map((c) => _CustomerOption(
                    c['id'].toString(),
                    c['name'] as String,
                    c['phone'] as String?,
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<AccountEntry> get _credits =>
      _entries.where((e) => e.isCredit).toList();
  List<AccountEntry> get _debits =>
      _entries.where((e) => !e.isCredit).toList();

  double get _totalCredit => _credits.fold(0, (s, e) => s + e.amount);
  double get _totalDebit => _debits.fold(0, (s, e) => s + e.amount);
  double get _balance => _totalCredit - _totalDebit;

  void _showAddDialog({AccountEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountFormSheet(
        entry: entry,
        customers: _customers,
        onSave: (title, amount, type, note, date, customerId, customerName) async {
          final data = {
            'title': title,
            'amount': amount,
            'type': type,
            'note': note,
            'account_date': date.toIso8601String().substring(0, 10),
            'customer_id': customerId != null ? int.parse(customerId) : null,
            'customer_name': customerName,
          };
          if (entry == null) {
            await _db.from('vkb_accounts').insert(data);
          } else {
            await _db
                .from('vkb_accounts')
                .update(data)
                .eq('id', int.parse(entry.id));
          }
          await _loadAll();
        },
      ),
    );
  }

  void _deleteEntry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.from('vkb_accounts').delete().eq('id', int.parse(id));
      await _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Accounts',
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          onPressed: _loadAll,
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
          // ── Balance Card
          Container(
            decoration: const BoxDecoration(gradient: AppColors.cardGradient),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text('Current Balance',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontFamily: 'Poppins')),
              const SizedBox(height: 4),
              Text(
                '₹${_balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _balance >= 0 ? Colors.white : Colors.red[200],
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _BalanceTile(
                    label: 'Total Credit',
                    value: '₹${_totalCredit.toStringAsFixed(0)}',
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.green[300]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceTile(
                    label: 'Total Debit',
                    value: '₹${_totalDebit.toStringAsFixed(0)}',
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.red[300]!,
                  ),
                ),
              ]),
            ]),
          ),

          // ── Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'All (${_entries.length})'),
                Tab(text: '📥 Credit (${_credits.length})'),
                Tab(text: '📤 Debit (${_debits.length})'),
              ],
            ),
          ),

          // ── List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _EntryList(
                          entries: _entries,
                          onEdit: _showAddDialog,
                          onDelete: _deleteEntry),
                      _EntryList(
                          entries: _credits,
                          onEdit: _showAddDialog,
                          onDelete: _deleteEntry),
                      _EntryList(
                          entries: _debits,
                          onEdit: _showAddDialog,
                          onDelete: _deleteEntry),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Balance Tile ─────────────────────────────────────────────────────────────
class _BalanceTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _BalanceTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFamily: 'Poppins')),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          fontFamily: 'Poppins')),
                ]),
          ),
        ]),
      );
}

// ─── Entry List ───────────────────────────────────────────────────────────────
class _EntryList extends StatelessWidget {
  final List<AccountEntry> entries;
  final void Function({AccountEntry? entry}) onEdit;
  final void Function(String) onDelete;
  const _EntryList(
      {required this.entries, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
          emoji: '📒',
          title: 'No entries found',
          subtitle: 'Tap + to add an entry');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EntryCard(
        entry: entries[i],
        onEdit: () => onEdit(entry: entries[i]),
        onDelete: () => onDelete(entries[i].id),
      ),
    );
  }
}

// ─── Entry Card ───────────────────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final AccountEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EntryCard(
      {required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.isCredit;
    final color = isCredit ? AppColors.success : AppColors.error;
    final bgColor = isCredit ? AppColors.successSurface : AppColors.errorSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // Type icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),

                // Customer name
                if (entry.customerName != null) ...[
                  Row(children: [
                    const Icon(Icons.person_rounded,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(entry.customerName!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins')),
                  ]),
                  const SizedBox(height: 3),
                ],

                // Credit/Debit badge + Date
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      isCredit ? 'Credit வரவு' : 'Debit செலவு',
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontFamily: 'Poppins'),
                  ),
                ]),

                // Note
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(entry.note!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ]),
        ),

        // Amount + Actions
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${isCredit ? '+' : '-'}₹${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.primary)),
            const SizedBox(width: 10),
            GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_rounded,
                    size: 16, color: AppColors.error)),
          ]),
        ]),
      ]),
    );
  }
}

// ─── Account Form Sheet ───────────────────────────────────────────────────────
class _AccountFormSheet extends StatefulWidget {
  final AccountEntry? entry;
  final List<_CustomerOption> customers;
  final Future<void> Function(
      String, double, String, String?, DateTime, String?, String?) onSave;

  const _AccountFormSheet(
      {this.entry, required this.customers, required this.onSave});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'credit';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  _CustomerOption? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _selectedDate = e.date;
      if (e.customerId != null) {
        try {
          _selectedCustomer =
              widget.customers.firstWhere((c) => c.id == e.customerId);
        } catch (_) {}
      }
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
      _type,
      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      _selectedDate,
      _selectedCustomer?.id,
      _selectedCustomer?.name,
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
              widget.entry == null ? '➕ Add Entry' : '✏️ Edit Entry',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 20),

            // ── Credit / Debit Toggle ──
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = 'credit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _type == 'credit'
                          ? AppColors.success
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _type == 'credit'
                            ? AppColors.success
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_downward_rounded,
                            size: 18,
                            color: _type == 'credit'
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('வரவு',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _type == 'credit'
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = 'debit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _type == 'debit'
                          ? AppColors.error
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _type == 'debit'
                            ? AppColors.error
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 18,
                            color: _type == 'debit'
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('செலவு',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: _type == 'debit'
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Customer Dropdown ──
            _Label('Customer'),
            const SizedBox(height: 6),
            DropdownButtonFormField<_CustomerOption>(
              value: _selectedCustomer,
              decoration: const InputDecoration(
                hintText: 'Select customer...',
                prefixIcon: Icon(Icons.person_rounded, size: 18),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<_CustomerOption>(
                  value: null,
                  child: Text('-- No Customer --',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textTertiary)),
                ),
                ...widget.customers.map((c) => DropdownMenuItem(
                      value: c,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          if (c.phone != null)
                            Text(c.phone!,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedCustomer = v),
            ),
            const SizedBox(height: 14),

            // ── Title ──
            _Label('Title / Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Cash received, Payment made...',
                prefixIcon: Icon(Icons.title_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),

            // ── Amount ──
            _Label('Amount (₹)'),
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

            // ── Date ──
            _Label('Date'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
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

            // ── Note ──
            _Label('Note (Optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Additional notes...',
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
                  label: widget.entry == null ? 'Save' : 'Update',
                  isLoading: _isSaving,
                  onTap: _save,
                ),
              ),
            ]),
            const SizedBox(height: 16),
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