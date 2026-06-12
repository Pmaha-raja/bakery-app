import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class PrinterService {
  static final PrinterService _i = PrinterService._();
  factory PrinterService() => _i;
  PrinterService._();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await _printer.getBondedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await _printer.connect(device);
      _connectedDevice = device;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await _printer.disconnect();
    _connectedDevice = null;
  }

  Future<void> printBill({
    required String businessName,
    required String invoiceNo,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double gstRate,
    required double gstAmount,
    required double total,
    required String footerMsg,
  }) async {
    if (!isConnected) return;

    // Header
    _printer.printCustom(businessName, 3, 1);
    _printer.printCustom('================================', 1, 1);
    _printer.printCustom('Invoice: $invoiceNo', 1, 1);
    _printer.printCustom('Customer: $customerName', 1, 1);
    _printer.printCustom(_formatDate(DateTime.now()), 1, 1);
    _printer.printCustom('================================', 1, 1);

    // Items header
    _printer.printCustom('Item          Qty  Price   Total', 1, 0);
    _printer.printCustom('--------------------------------', 1, 0);

    // Items — safe type cast பண்றோம்
    for (final item in items) {
      final name = '${item['name']}'.padRight(14).substring(0, 14);

      // qty — int or num எதுவா இருந்தாலும் handle பண்ணு
      final qtyNum = (item['qty'] is int)
          ? (item['qty'] as int)
          : (item['qty'] as num).toInt();

      // price — double or num எதுவா இருந்தாலும் handle பண்ணு
      final priceNum = (item['price'] is double)
          ? (item['price'] as double)
          : (item['price'] as num).toDouble();

      final itemTotal = priceNum * qtyNum;

      final qty = qtyNum.toString().padLeft(3);
      final price = priceNum.toStringAsFixed(0).padLeft(6);
      final totalStr = itemTotal.toStringAsFixed(0).padLeft(6);

      _printer.printCustom('$name $qty $price $totalStr', 1, 0);
    }

    // Totals
    _printer.printCustom('--------------------------------', 1, 0);
    _printer.printCustom(
      'Subtotal:'.padRight(20) +
          'Rs.${subtotal.toStringAsFixed(2)}'.padLeft(11),
      1,
      0,
    );
    if (gstRate > 0) {
      _printer.printCustom(
        'GST (${gstRate.toStringAsFixed(0)}%):'.padRight(20) +
            'Rs.${gstAmount.toStringAsFixed(2)}'.padLeft(11),
        1,
        0,
      );
    }
    _printer.printCustom('================================', 1, 0);
    _printer.printCustom(
      'TOTAL:'.padRight(20) +
          'Rs.${total.toStringAsFixed(2)}'.padLeft(11),
      2,
      0,
    );
    _printer.printCustom('================================', 1, 1);

    // Footer
    _printer.printCustom(footerMsg, 1, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.printNewLine();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}