import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  DashboardStats _stats = DashboardStats.empty();
  String _bizName = 'VKB Bakery';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await SupabaseService().getDashboardStats();
    final settings = await SupabaseService().getSettings();
    if (mounted) {
      setState(() {
        _stats = stats;
        _bizName = settings.businessName;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _bizName,
      onNavigate: widget.onNavigate,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onNavigate?.call(2),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: const Text('New Bill',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins')),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi, $_bizName!',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                      color: AppColors.textPrimary)),
                              const Text("Today's bakery overview",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── KPI Cards — childAspectRatio fix (1.1 → 0.9)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9, // ← FIXED (was 1.1)
                      children: [
                        StatCard(
                          label: 'Total Products',
                          value: _stats.totalProducts.toString(),
                          subValue: '${_stats.totalCategories} categories',
                          color: AppColors.primary,
                          bgColor: AppColors.primarySurface,
                          icon: Icons.inventory_2_rounded,
                          trend: 'Live from DB',
                          isTrendUp: true,
                        ),
                        StatCard(
                          label: "Today's Revenue",
                          value: '₹${_stats.todayRevenue.toStringAsFixed(0)}',
                          subValue: '${_stats.todayBills} bills today',
                          color: AppColors.success,
                          bgColor: AppColors.successSurface,
                          icon: Icons.trending_up_rounded,
                          trend: 'Live from DB',
                          isTrendUp: true,
                        ),
                        StatCard(
                          label: 'Low Stock Items',
                          value: _stats.lowStockCount.toString(),
                          subValue: 'Need restocking',
                          color: AppColors.error,
                          bgColor: AppColors.errorSurface,
                          icon: Icons.warning_amber_rounded,
                          trend: _stats.lowStockCount > 0
                              ? 'Attention needed'
                              : 'All good ✅',
                          isTrendUp: _stats.lowStockCount == 0,
                        ),
                        StatCard(
                          label: 'Stock Value',
                          value: '₹${_stats.totalStockValue.toStringAsFixed(0)}',
                          subValue: 'Total inventory',
                          color: AppColors.info,
                          bgColor: AppColors.infoSurface,
                          icon: Icons.receipt_long_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Stock by Category
                    if (_stats.stockByCategory.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              title: '📊 Stock Value by Category',
                              subtitle: 'Inventory value breakdown',
                            ),
                            const SizedBox(height: 16),
                            ..._stats.stockByCategory.entries.map(
                              (e) => _CategoryBar(
                                label: e.key,
                                value: e.value,
                                maxValue: _stats.stockByCategory.values
                                    .reduce((a, b) => a > b ? a : b),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Products by Category
                    if (_stats.productsByCategory.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              title: '🍰 Products by Category',
                              subtitle: 'Count per category',
                            ),
                            const SizedBox(height: 16),
                            // childAspectRatio fix (1.4 → 1.1)
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.1, // ← FIXED (was 1.4)
                              children: _stats.productsByCategory.entries
                                  .map((e) => _CategoryProductCard(
                                      label: e.key, count: e.value))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Category Bar ─────────────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;

  const _CategoryBar(
      {required this.label, required this.value, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final pct = maxValue > 0 ? value / maxValue : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins')),
            Text('₹${value.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins')),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.primarySurface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Product Card ────────────────────────────────────────────────────
class _CategoryProductCard extends StatelessWidget {
  final String label;
  final int count;
  const _CategoryProductCard({required this.label, required this.count});

  String get _emoji {
    final l = label.toLowerCase();
    if (l.contains('bread')) return '🍞';
    if (l.contains('cake')) return '🎂';
    if (l.contains('cookie') || l.contains('biscuit')) return '🍪';
    if (l.contains('pastry') || l.contains('pastries')) return '🥐';
    if (l.contains('donut')) return '🍩';
    if (l.contains('muffin') || l.contains('cupcake')) return '🧁';
    return '🏷️';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      // ── Overflow fix — Column-ஐ FittedBox wrap பண்றோம்
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontFamily: 'Poppins'),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$count items',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}