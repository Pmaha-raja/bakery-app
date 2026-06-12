import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/printer_service.dart';
import 'printer_screen.dart';

// ─── Cart Item ────────────────────────────────────────────────────────────────
class BillingCartItem {
  final Product product;
  int quantity;
  double customPrice;

  BillingCartItem({
    required this.product,
    this.quantity = 0,
    double? customPrice,
  }) : customPrice = customPrice ?? product.price;

  double get total => customPrice * quantity;

  // ── Deep copy ──
  BillingCartItem copyWith() => BillingCartItem(
        product: product,
        customPrice: customPrice,
      )..quantity = quantity;
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class BillingDeskScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const BillingDeskScreen({super.key, this.onNavigate});

  @override
  State<BillingDeskScreen> createState() => _BillingDeskScreenState();
}

class _BillingDeskScreenState extends State<BillingDeskScreen> {
  String _searchQuery = '';
  String? _selectedCategoryName;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  List<Category> _categories = [];
  List<BillingCartItem> _items = [];
  double _gstRate = 0;
  String _bizName = 'VKB Bakery';
  String _footerMsg = 'Thank you for your purchase!';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final settings = await SupabaseService().getSettings();
    final cats = await SupabaseService().getCategories();
    final products = await SupabaseService().getProducts();
    if (mounted) {
      setState(() {
        _gstRate = settings.gstRate;
        _bizName = settings.businessName;
        _footerMsg = settings.footerMessage;
        _categories = cats;
        _items = products.map((p) => BillingCartItem(product: p)).toList();
        _isLoading = false;
      });
    }
  }

  List<BillingCartItem> get _filteredItems {
    return _items.where((item) {
      final matchSearch = _searchQuery.isEmpty ||
          item.product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCat = _selectedCategoryName == null ||
          item.product.categoryId == _selectedCategoryName;
      return matchSearch && matchCat;
    }).toList();
  }

  List<BillingCartItem> get _selectedItems =>
      _items.where((i) => i.quantity > 0).toList();

  int get _totalQty => _selectedItems.fold(0, (s, i) => s + i.quantity);
  double get _subtotal => _selectedItems.fold(0.0, (s, i) => s + i.total);
  double get _gstAmount => _subtotal * (_gstRate / 100);
  double get _grandTotal => _subtotal + _gstAmount;

  void _increment(BillingCartItem item) => setState(() => item.quantity++);
  void _decrement(BillingCartItem item) {
    setState(() {
      if (item.quantity > 0) item.quantity--;
    });
  }

  void _clearAll() {
    setState(() {
      for (final item in _items) {
        item.quantity = 0;
      }
    });
  }

  void _goToOrderReview() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one item.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    // ── Deep copy — quantity சரியா போகணும் ──
    final deepCopied = _selectedItems.map((i) => i.copyWith()).toList();

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _OrderReviewPage(
        selectedItems: deepCopied,
        gstRate: _gstRate,
        businessName: _bizName,
        footerMessage: _footerMsg,
        onConfirmed: () {
          setState(() {
            for (final item in _items) {
              item.quantity = 0;
            }
          });
        },
      ),
    ));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppShell(
        title: 'Billing Desk',
        onNavigate: widget.onNavigate,
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final filtered = _filteredItems;
    final hasItems = _selectedItems.isNotEmpty;

    return AppShell(
      title: 'Billing Desk',
      onNavigate: widget.onNavigate,
      actions: [
        IconButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PrinterScreen())),
          icon: Icon(
            PrinterService().isConnected
                ? Icons.print_rounded
                : Icons.print_outlined,
            color: PrinterService().isConnected
                ? AppColors.success
                : AppColors.primary,
          ),
          tooltip: PrinterService().isConnected
              ? 'Printer Connected'
              : 'Connect Printer',
        ),
        IconButton(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Refresh',
        ),
      ],
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search bakery items...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _BillFilterChip(
                        label: 'All',
                        isSelected: _selectedCategoryName == null,
                        onTap: () =>
                            setState(() => _selectedCategoryName = null),
                      ),
                      ..._categories.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _BillFilterChip(
                              label: '${c.emoji} ${c.name}',
                              isSelected: _selectedCategoryName == c.name,
                              onTap: () => setState(
                                  () => _selectedCategoryName = c.name),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: AppColors.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('🧾 Products',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: AppColors.textPrimary)),
                const Spacer(),
                Text('${filtered.length} items',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins')),
                if (hasItems) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _clearAll,
                    child: const Text('Clear All',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins')),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    emoji: '🍞',
                    title: 'No products found',
                    subtitle: 'Try a different filter or add products first',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ci = filtered[i];
                      return _BillingItemRow(
                        item: ci,
                        onIncrement: () => _increment(ci),
                        onDecrement: () => _decrement(ci),
                      );
                    },
                  ),
          ),
          if (hasItems)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_totalQty items • ${_selectedItems.length} products',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Poppins'),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sub: ₹${_subtotal.toStringAsFixed(2)}  +  GST ${_gstRate.toStringAsFixed(0)}%: ₹${_gstAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                  fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${_grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: VKBButton(
                      label: 'Review & Generate Bill  ›',
                      onTap: _goToOrderReview,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Billing Item Row ─────────────────────────────────────────────────────────
class _BillingItemRow extends StatelessWidget {
  final BillingCartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _BillingItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = item.quantity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(item.product.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${item.product.categoryId}  •  Stock: ${item.product.stock}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          Text('₹${item.product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFamily: 'Poppins')),
          const SizedBox(width: 14),
          Row(
            children: [
              _QtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: onDecrement,
                  enabled: item.quantity > 0),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                alignment: Alignment.center,
                child: Text(
                  item.quantity == 0 ? '–' : item.quantity.toString(),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textTertiary,
                      fontFamily: 'Poppins'),
                ),
              ),
              _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: onIncrement,
                  enabled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  const _QtyBtn(
      {required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16,
              color: enabled ? Colors.white : AppColors.textTertiary),
        ),
      );
}

// ─── Bill Filter Chip ─────────────────────────────────────────────────────────
class _BillFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _BillFilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primaryLight.withValues(alpha: 0.4),
            ),
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

// ─── Order Review Page ────────────────────────────────────────────────────────
class _OrderReviewPage extends StatefulWidget {
  final List<BillingCartItem> selectedItems;
  final double gstRate;
  final String businessName;
  final String footerMessage;
  final VoidCallback onConfirmed;

  const _OrderReviewPage({
    required this.selectedItems,
    required this.gstRate,
    required this.businessName,
    required this.footerMessage,
    required this.onConfirmed,
  });

  @override
  State<_OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<_OrderReviewPage> {
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isPrinting = false;

  double get subtotal =>
      widget.selectedItems.fold(0, (s, i) => s + i.total);
  double get gstAmount => subtotal * (widget.gstRate / 100);
  double get grandTotal => subtotal + gstAmount;

  String get _billNo =>
      'VKB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmBill() async {
    setState(() => _isSaving = true);
    final billNo = _billNo;
    final cartItems = widget.selectedItems
        .map((i) => CartItem(product: i.product, quantity: i.quantity))
        .toList();

    await SupabaseService().createBill(Bill(
      id: '',
      billNumber: billNo,
      createdAt: DateTime.now(),
      items: cartItems,
      subtotal: subtotal,
      gstRate: widget.gstRate,
      gstAmount: gstAmount,
      total: grandTotal,
      customerName: _customerNameCtrl.text.trim().isEmpty
          ? 'Walk-in'
          : _customerNameCtrl.text.trim(),
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty
          ? null
          : _customerPhoneCtrl.text.trim(),
    ));

    setState(() => _isSaving = false);
    widget.onConfirmed();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Bill $billNo saved!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _printBill() async {
    if (!PrinterService().isConnected) {
      final connected = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PrinterScreen()),
      );
      if (connected != true) return;
    }

    setState(() => _isPrinting = true);
    final billNo = _billNo;

    // ── items-ஐ explicit-ஆ pass பண்றோம் ──
    final printItems = widget.selectedItems.map((i) => {
          'name': i.product.name,
          'qty': i.quantity,            // int — actual quantity
          'price': i.product.price,     // double — actual price
        }).toList();

    await PrinterService().printBill(
      businessName: widget.businessName,
      invoiceNo: billNo,
      customerName: _customerNameCtrl.text.trim().isEmpty
          ? 'Walk-in'
          : _customerNameCtrl.text.trim(),
      items: printItems,
      subtotal: subtotal,
      gstRate: widget.gstRate,
      gstAmount: gstAmount,
      total: grandTotal,
      footerMsg: widget.footerMessage,
    );

    setState(() => _isPrinting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🖨️ Printing...'),
        backgroundColor: AppColors.info,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Order Review',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins')),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrinterScreen())),
            icon: Icon(
              PrinterService().isConnected
                  ? Icons.print_rounded
                  : Icons.print_outlined,
              color: PrinterService().isConnected
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Edit',
                style:
                    TextStyle(color: AppColors.primary, fontFamily: 'Poppins')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const Text('🍞', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Text(widget.businessName,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Poppins')),
                        Text(
                          '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontFamily: 'Poppins'),
                        ),
                      ],
                    ),
                  ),

                  // Customer info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Customer Name (optional)',
                            prefixIcon: Icon(Icons.person_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Phone Number (optional)',
                            prefixIcon: Icon(Icons.phone_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Items list
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(children: [
                          Expanded(
                              flex: 3,
                              child: Text('Item',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Poppins'))),
                          Expanded(
                              child: Text('Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Poppins'))),
                          Expanded(
                              child: Text('Price',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Poppins'))),
                          Expanded(
                              child: Text('Total',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Poppins'))),
                        ]),
                        const Divider(height: 12),
                        ...widget.selectedItems.map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                Expanded(
                                    flex: 3,
                                    child: Text(
                                        '${item.product.emoji} ${item.product.name}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Poppins'))),
                                Expanded(
                                    child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins'))),
                                Expanded(
                                    child: Text(
                                        '₹${item.customPrice.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Poppins'))),
                                Expanded(
                                    child: Text(
                                        '₹${item.total.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins'))),
                              ]),
                            )),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Totals
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        _TotalLine(
                            label: 'Subtotal:',
                            value: '₹${subtotal.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        _TotalLine(
                            label:
                                'GST (${widget.gstRate.toStringAsFixed(0)}%):',
                            value: '₹${gstAmount.toStringAsFixed(2)}',
                            isSubtle: true),
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1)),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark)),
                              Text('₹${grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error)),
                            ]),
                      ]),
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(widget.footerMessage,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isPrinting ? null : _printBill,
                              icon: _isPrinting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Icon(
                                      PrinterService().isConnected
                                          ? Icons.print_rounded
                                          : Icons.bluetooth_searching_rounded,
                                      size: 16),
                              label: Text(_isPrinting
                                  ? 'Printing...'
                                  : PrinterService().isConnected
                                      ? 'Print Bill'
                                      : 'Connect & Print'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PrinterService().isConnected
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: VKBButton(
                              label: 'Confirm & Save',
                              isLoading: _isSaving,
                              onTap: _confirmBill,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_isSaving || _isPrinting)
                                ? null
                                : () async {
                                    await _confirmBill();
                                    if (mounted) await _printBill();
                                  },
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Save & Print'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Total Line ───────────────────────────────────────────────────────────────
class _TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isSubtle;
  const _TotalLine(
      {required this.label, required this.value, this.isSubtle = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$label  $value',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isSubtle
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.right),
        ],
      );
}