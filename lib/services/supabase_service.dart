import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// ─── Supabase Client ──────────────────────────────────────────────────────────
final _db = Supabase.instance.client;

/// VKB Bakery — Supabase Service
/// Drop-in replacement for ApiService TODOs
/// Tables: vkb_settings, vkb_categories, vkb_products, vkb_invoices
class SupabaseService {
  // Singleton
  static final SupabaseService _i = SupabaseService._();
  factory SupabaseService() => _i;
  SupabaseService._();

  // ── SETTINGS (vkb_settings) ─────────────────────────────────────────────────
  // DB columns: id, business_name, gst_rate, footer_text

  Future<AppSettings> getSettings() async {
    try {
      final res = await _db.from('vkb_settings').select().limit(1);
      if (res.isEmpty) return AppSettings.defaults();
      final row = res[0] as Map<String, dynamic>;
      return AppSettings(
        businessName: row['business_name'] as String? ?? 'VKB Bakery',
        gstRate: double.tryParse(row['gst_rate']?.toString() ?? '0') ?? 0,
        footerMessage: row['footer_text'] as String? ?? 'Thank you!',
      );
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    try {
      // Check if row exists
      final res = await _db.from('vkb_settings').select('id').limit(1);
      final data = {
        'business_name': settings.businessName,
        'gst_rate': settings.gstRate,
        'footer_text': settings.footerMessage,
      };
      if (res.isNotEmpty) {
        final id = res[0]['id'];
        await _db.from('vkb_settings').update(data).eq('id', id);
      } else {
        await _db.from('vkb_settings').insert(data);
      }
      return settings;
    } catch (_) {
      return settings;
    }
  }

  // ── CATEGORIES (vkb_categories) ─────────────────────────────────────────────
  // DB columns: id (bigint), name (text)
  // Model: Category(id: String, name: String, emoji: String)
  // Note: DB-ல் emoji column இல்ல — name-ல் இருந்து auto assign பண்றோம்

  Future<List<Category>> getCategories() async {
    try {
      final res = await _db
          .from('vkb_categories')
          .select('id, name')
          .order('name');
      return (res as List).map((row) {
        final name = row['name'] as String;
        return Category(
          id: row['id'].toString(),
          name: name,
          emoji: _emojiForCategory(name),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Category> createCategory(Category category) async {
    final res = await _db
        .from('vkb_categories')
        .insert({'name': category.name})
        .select('id, name')
        .single();
    return Category(
      id: res['id'].toString(),
      name: res['name'] as String,
      emoji: category.emoji,
    );
  }

  Future<void> updateCategory(String id, String newName) async {
    await _db
        .from('vkb_categories')
        .update({'name': newName})
        .eq('id', int.parse(id));
    // Update all products with old category name
    final oldCat = await _db
        .from('vkb_categories')
        .select('name')
        .eq('id', int.parse(id))
        .single();
    if (oldCat['name'] != newName) {
      await _db
          .from('vkb_products')
          .update({'category': newName})
          .eq('category', oldCat['name']);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('vkb_categories').delete().eq('id', int.parse(id));
  }

  // ── PRODUCTS (vkb_products) ─────────────────────────────────────────────────
  // DB columns: id (bigint), name, category (text), price, stock, emoji, image_url
  // Model: Product(id: String, emoji, name, categoryId: String, price, stock, isActive)
  // Bridge: categoryId = category name (since DB has text, not FK id)

  Future<List<Product>> getProducts({
    int page = 1,
    int limit = 50,
    String? categoryId, // categoryId = category name in our bridge
    String? search,
  }) async {
    try {
      var query = _db.from('vkb_products').select(
          'id, name, category, price, stock, emoji, image_url');

      // Filter by category name (categoryId is used as name bridge)
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category', categoryId) as dynamic;
      }

      // Search filter
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%') as dynamic;
      }

      final res = await (query as dynamic)
          .order('name')
          .range((page - 1) * limit, page * limit - 1);

      return (res as List).map((row) => _productFromRow(row)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Product> createProduct(Product product) async {
    final res = await _db
        .from('vkb_products')
        .insert({
          'name': product.name,
          'category': product.categoryId, // categoryId = category name
          'price': product.price,
          'stock': product.stock,
          'emoji': product.emoji,
        })
        .select()
        .single();
    return _productFromRow(res);
  }

  Future<Product> updateProduct(Product product) async {
    final res = await _db
        .from('vkb_products')
        .update({
          'name': product.name,
          'category': product.categoryId,
          'price': product.price,
          'stock': product.stock,
          'emoji': product.emoji,
        })
        .eq('id', int.parse(product.id))
        .select()
        .single();
    return _productFromRow(res);
  }

  Future<void> deleteProduct(String id) async {
    await _db.from('vkb_products').delete().eq('id', int.parse(id));
  }

  Future<void> updateStock(String id, int newStock) async {
    await _db
        .from('vkb_products')
        .update({'stock': newStock})
        .eq('id', int.parse(id));
  }

  // ── INVOICES (vkb_invoices) ─────────────────────────────────────────────────
  // DB columns: id, invoice_no, customer_name, items(jsonb),
  //             subtotal, gst_percent, gst_amount, total_amount, created_at

  Future<Bill> createBill(Bill bill) async {
    final res = await _db
        .from('vkb_invoices')
        .insert({
          'invoice_no': bill.billNumber,
          'customer_name': bill.customerName ?? 'Walk-in',
          'items': bill.items.map((i) => i.toJson()).toList(),
          'subtotal': bill.subtotal,
          'gst_percent': bill.gstRate,
          'gst_amount': bill.gstAmount,
          'total_amount': bill.total,
        })
        .select()
        .single();
    return _billFromRow(res, bill.items);
  }

  Future<List<Bill>> getBills({
    int page = 1,
    int limit = 20,
    DateTime? date,
  }) async {
    try {
      var query = _db.from('vkb_invoices').select(
          'id, invoice_no, customer_name, items, subtotal, gst_percent, gst_amount, total_amount, created_at');

      if (date != null) {
        final start = DateTime(date.year, date.month, date.day)
            .toIso8601String();
        final end = DateTime(date.year, date.month, date.day, 23, 59, 59)
            .toIso8601String();
        query = query.gte('created_at', start).lte('created_at', end) as dynamic;
      }

      final res = await (query as dynamic)
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return (res as List).map((row) => _billFromRow(row, [])).toList();
    } catch (_) {
      return [];
    }
  }

  // ── DASHBOARD STATS ─────────────────────────────────────────────────────────
  Future<DashboardStats> getDashboardStats() async {
    try {
      final products = await getProducts(limit: 500);
      final today = DateTime.now();
      final bills = await getBills(date: today);

      final catStock = <String, double>{};
      final catCount = <String, int>{};
      int lowStock = 0;

      for (final p in products) {
        catStock[p.categoryId] =
            (catStock[p.categoryId] ?? 0) + (p.price * p.stock);
        catCount[p.categoryId] = (catCount[p.categoryId] ?? 0) + 1;
        if (p.stock > 0 && p.stock <= 5) lowStock++;
      }

      final todayRevenue =
          bills.fold<double>(0, (s, b) => s + b.total);

      final cats = await getCategories();

      return DashboardStats(
        totalProducts: products.length,
        totalStockValue:
            products.fold(0, (s, p) => s + p.price * p.stock),
        totalCategories: cats.length,
        lowStockCount: lowStock,
        todayRevenue: todayRevenue,
        todayBills: bills.length,
        stockByCategory: catStock,
        productsByCategory: catCount,
      );
    } catch (_) {
      return DashboardStats.empty();
    }
  }

  // ── RESET ───────────────────────────────────────────────────────────────────
  Future<void> resetToSampleData() async {
    // Delete existing
    await _db.from('vkb_products').delete().neq('id', 0);
    await _db.from('vkb_categories').delete().neq('id', 0);

    // Insert sample categories
    await _db.from('vkb_categories').insert([
      {'name': 'Breads'},
      {'name': 'Pastries'},
      {'name': 'Cakes'},
      {'name': 'Cookies'},
    ]);

    // Insert sample products
    await _db.from('vkb_products').insert([
      {'name': 'Sourdough Bread', 'category': 'Breads', 'price': 45, 'stock': 30, 'emoji': '🍞'},
      {'name': 'Butter Croissant', 'category': 'Pastries', 'price': 35, 'stock': 25, 'emoji': '🥐'},
      {'name': 'Chocolate Cake', 'category': 'Cakes', 'price': 350, 'stock': 8, 'emoji': '🎂'},
      {'name': 'Oat Cookies', 'category': 'Cookies', 'price': 20, 'stock': 50, 'emoji': '🍪'},
      {'name': 'Danish Pastry', 'category': 'Pastries', 'price': 40, 'stock': 15, 'emoji': '🥨'},
      {'name': 'Whole Wheat Bread', 'category': 'Breads', 'price': 38, 'stock': 20, 'emoji': '🍞'},
    ]);
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────────
  Product _productFromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'].toString(),
      emoji: row['emoji'] as String? ?? '🍰',
      name: row['name'] as String,
      categoryId: row['category'] as String, // category name = categoryId
      price: double.tryParse(row['price']?.toString() ?? '0') ?? 0,
      stock: (row['stock'] as int?) ?? 0,
      isActive: (row['stock'] as int? ?? 0) > 0,
    );
  }

  Bill _billFromRow(Map<String, dynamic> row, List<CartItem> items) {
    return Bill(
      id: row['id'].toString(),
      billNumber: row['invoice_no'] as String,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      items: items,
      subtotal: double.tryParse(row['subtotal']?.toString() ?? '0') ?? 0,
      gstRate: double.tryParse(row['gst_percent']?.toString() ?? '0') ?? 0,
      gstAmount: double.tryParse(row['gst_amount']?.toString() ?? '0') ?? 0,
      total: double.tryParse(row['total_amount']?.toString() ?? '0') ?? 0,
      customerName: row['customer_name'] as String?,
    );
  }

  String _emojiForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('cake')) return '🎂';
    if (lower.contains('cookie') || lower.contains('biscuit')) return '🍪';
    if (lower.contains('pastry') || lower.contains('pastries')) return '🥐';
    if (lower.contains('donut') || lower.contains('doughnut')) return '🍩';
    if (lower.contains('muffin') || lower.contains('cupcake')) return '🧁';
    return '🏷️';
  }
  // ── LOGIN VERIFY ────────────────────────────────────────────
// vkb_users table-ல் pin match பண்றோம்
Future<bool> verifyPin(String pin) async {
  try {
    final res = await _db
        .from('vkb_users')
        .select('id')
        .eq('pin', pin)
        .limit(1);
    return (res as List).isNotEmpty;
  } catch (_) {
    return false;
  }
}
}