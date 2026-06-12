import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/printer_service.dart';
import '../widgets/app_theme.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<BluetoothDevice> _devices = [];
  bool _loading = false;
  String? _connectedName;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    final devices = await PrinterService().getPairedDevices();
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _loading = true);
    final ok = await PrinterService().connect(device);
    setState(() {
      _connectedName = ok ? device.name : null;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Connected to ${device.name}'
          : '❌ Connection failed'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🖨️ Bluetooth Printer'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Connected status
                if (_connectedName != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(children: [
                      const Icon(Icons.print_rounded,
                          color: AppColors.success),
                      const SizedBox(width: 10),
                      Text('Connected: $_connectedName',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await PrinterService().disconnect();
                          setState(() => _connectedName = null);
                        },
                        child: const Text('Disconnect',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ]),
                  ),

                // Paired devices list
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Text('Paired Devices',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins')),
                  ]),
                ),

                Expanded(
                  child: _devices.isEmpty
                      ? const Center(
                          child: Text(
                            'No paired devices found.\nPair your printer in Bluetooth settings first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _devices.length,
                          itemBuilder: (_, i) {
                            final d = _devices[i];
                            final isConnected =
                                _connectedName == d.name;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? AppColors.successSurface
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isConnected
                                      ? AppColors.success
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(children: [
                                Icon(Icons.print_rounded,
                                    color: isConnected
                                        ? AppColors.success
                                        : AppColors.textSecondary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name ?? 'Unknown',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins')),
                                      Text(d.address ?? '',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: isConnected
                                      ? null
                                      : () => _connect(d),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                  child: Text(
                                      isConnected ? 'Connected' : 'Connect',
                                      style: const TextStyle(
                                          color: Colors.white)),
                                ),
                              ]),
                            );
                          },
                        ),
                ),

                // Test print button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _connectedName == null
                          ? null
                          : () async {
                              await PrinterService().printBill(
                                businessName: 'VKB Bakery',
                                invoiceNo: 'TEST-001',
                                customerName: 'Test Customer',
                                items: [
                                  {'name': 'Test Item', 'qty': 1, 'price': 100}
                                ],
                                subtotal: 100,
                                gstRate: 5,
                                gstAmount: 5,
                                total: 105,
                                footerMsg: 'Thank you!',
                              );
                            },
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Test Print'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}