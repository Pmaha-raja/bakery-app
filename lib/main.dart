import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/products_screen.dart';
import 'screens/billing_desk_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_login_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/customers_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://nnrjievanuqlealabihr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ucmppZXZhbnVxbGVhbGFiaWhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0ODgzOTMsImV4cCI6MjA5NjA2NDM5M30.jz60L6ZQlPHmj22XkDGIxL1WMYEYHpkhYsKyQ8w3has',
  );
  runApp(const VKBBakeryApp());
}

class VKBBakeryApp extends StatelessWidget {
  const VKBBakeryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VKB Bakery ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const MainNavShell(),
      },
    );
  }
}

// ─── Menu Item Model ──────────────────────────────────────────────────────────
class _MenuItem {
  final String label;
  final IconData icon;
  final int index;
  const _MenuItem(this.label, this.icon, this.index);
}

// ─── Main Shell ───────────────────────────────────────────────────────────────
class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    Navigator.of(context).pop(); // close drawer
  }

  void _navigateBottom(int index) {
    setState(() => _currentIndex = index);
  }

  // All screens
  List<Widget> get _screens => [
        DashboardScreen(onNavigate: _navigateBottom),
        ProductsScreen(onNavigate: _navigateBottom),
        BillingDeskScreen(onNavigate: _navigateBottom),
        ExpensesScreen(onNavigate: _navigateBottom),
        AccountsScreen(onNavigate: _navigateBottom),
        CustomersScreen(onNavigate: _navigateBottom),
        SettingsScreen(onNavigate: _navigateBottom),
      ];

  // Side menu items
  static const _menuItems = [
    _MenuItem('Dashboard', Icons.dashboard_rounded, 0),
    _MenuItem('Products', Icons.inventory_2_rounded, 1),
    _MenuItem('Billing', Icons.receipt_long_rounded, 2),
    _MenuItem('Expenses', Icons.money_off_rounded, 3),
    _MenuItem('Accounts', Icons.account_balance_wallet_rounded, 4),
    _MenuItem('Customers', Icons.people_rounded, 5),
    _MenuItem('Settings', Icons.settings_rounded, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Side Drawer ──
      drawer: _SideDrawer(
        currentIndex: _currentIndex,
        onNavigate: _navigateTo,
        menuItems: _menuItems,
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      // ── Bottom Nav — Dashboard + Billing only ──
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 0
            ? 0
            : _currentIndex == 2
                ? 1
                : 0,
        onTap: (i) {
          if (i == 0) _navigateBottom(0);
          if (i == 1) _navigateBottom(2);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.sidebarBg,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.sidebarText,
        selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontFamily: 'Poppins', fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Billing'),
        ],
      ),
    );
  }
}

// ─── Side Drawer ──────────────────────────────────────────────────────────────
class _SideDrawer extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final List<_MenuItem> menuItems;

  const _SideDrawer({
    required this.currentIndex,
    required this.onNavigate,
    required this.menuItems,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      child: Column(
        children: [
          // ── Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppColors.splashGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('🍞', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'VKB Bakery ERP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Text(
                  'Bakery Management System',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          // ── Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: menuItems.map((item) {
                final isActive = currentIndex == item.index;
                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isActive
                        ? Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isActive
                          ? AppColors.primaryLight
                          : AppColors.sidebarText,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive
                            ? AppColors.primaryLight
                            : AppColors.sidebarText,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    trailing: isActive
                        ? Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () => onNavigate(item.index),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'VKB Bakery ERP v1.0.0',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.sidebarText,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}