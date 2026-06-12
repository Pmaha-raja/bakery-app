// ─── Product Model ───────────────────────────────────────────────────────────
class Product {
  final String id;
  final String emoji;
  final String name;
  final String categoryId;
  final double price;
  int stock;
  bool isActive;
  final String imageUrl;

  Product({
    required this.id,
    required this.emoji,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.stock,
    this.isActive = true,
    this.imageUrl = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        emoji: json['emoji'] as String? ?? '🍞',
        name: json['name'] as String,
        categoryId: json['category_id'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        isActive: json['is_active'] as bool? ?? true,
        imageUrl: json['image_url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'name': name,
        'category_id': categoryId,
        'price': price,
        'stock': stock,
        'is_active': isActive,
        'image_url': imageUrl,
      };

  Product copyWith({
    String? emoji,
    String? name,
    String? categoryId,
    double? price,
    int? stock,
    bool? isActive,
    String? imageUrl,
  }) =>
      Product(
        id: id,
        emoji: emoji ?? this.emoji,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        isActive: isActive ?? this.isActive,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

// ─── Category Model ───────────────────────────────────────────────────────────
class Category {
  final String id;
  final String name;
  final String emoji;

  const Category({
    required this.id,
    required this.name,
    required this.emoji,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '🏷️',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
      };
}

// ─── Cart Item Model ──────────────────────────────────────────────────────────
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;

  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'product_name': product.name,
        'price': product.price,
        'quantity': quantity,
        'total': total,
      };
}

// ─── Bill / Invoice Model ─────────────────────────────────────────────────────
class Bill {
  final String id;
  final String billNumber;
  final DateTime createdAt;
  final List<CartItem> items;
  final double subtotal;
  final double gstRate;
  final double gstAmount;
  final double total;
  final String? customerName;
  final String? customerPhone;

  Bill({
    required this.id,
    required this.billNumber,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.gstRate,
    required this.gstAmount,
    required this.total,
    this.customerName,
    this.customerPhone,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String,
        billNumber: json['bill_number'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItem(
                  product: Product.fromJson(e['product'] as Map<String, dynamic>),
                  quantity: e['quantity'] as int,
                ))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        gstRate: (json['gst_rate'] as num).toDouble(),
        gstAmount: (json['gst_amount'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bill_number': billNumber,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'gst_rate': gstRate,
        'gst_amount': gstAmount,
        'total': total,
        'customer_name': customerName,
        'customer_phone': customerPhone,
      };
}

// ─── Settings Model ───────────────────────────────────────────────────────────
class AppSettings {
  final String businessName;
  final double gstRate;
  final String footerMessage;
  final String? logoUrl;
  final String? address;
  final String? phone;

  const AppSettings({
    required this.businessName,
    required this.gstRate,
    required this.footerMessage,
    this.logoUrl,
    this.address,
    this.phone,
  });

  factory AppSettings.defaults() => const AppSettings(
        businessName: 'VKB Bakery',
        gstRate: 5.0,
        footerMessage: 'Thank you for your purchase!',
      );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        businessName: json['business_name'] as String,
        gstRate: (json['gst_rate'] as num).toDouble(),
        footerMessage: json['footer_message'] as String,
        logoUrl: json['logo_url'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'gst_rate': gstRate,
        'footer_message': footerMessage,
        'logo_url': logoUrl,
        'address': address,
        'phone': phone,
      };

  AppSettings copyWith({
    String? businessName,
    double? gstRate,
    String? footerMessage,
    String? logoUrl,
    String? address,
    String? phone,
  }) =>
      AppSettings(
        businessName: businessName ?? this.businessName,
        gstRate: gstRate ?? this.gstRate,
        footerMessage: footerMessage ?? this.footerMessage,
        logoUrl: logoUrl ?? this.logoUrl,
        address: address ?? this.address,
        phone: phone ?? this.phone,
      );
}

// ─── Dashboard Stats Model ────────────────────────────────────────────────────
class DashboardStats {
  final int totalProducts;
  final double totalStockValue;
  final int totalCategories;
  final int lowStockCount;
  final double todayRevenue;
  final int todayBills;
  final Map<String, double> stockByCategory;
  final Map<String, int> productsByCategory;

  const DashboardStats({
    required this.totalProducts,
    required this.totalStockValue,
    required this.totalCategories,
    required this.lowStockCount,
    required this.todayRevenue,
    required this.todayBills,
    required this.stockByCategory,
    required this.productsByCategory,
  });

  factory DashboardStats.empty() => const DashboardStats(
        totalProducts: 0,
        totalStockValue: 0,
        totalCategories: 0,
        lowStockCount: 0,
        todayRevenue: 0,
        todayBills: 0,
        stockByCategory: {},
        productsByCategory: {},
      );
}