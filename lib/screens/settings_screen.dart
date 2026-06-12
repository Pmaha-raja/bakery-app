import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoading = true;
  bool _hasChanges = false;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _gstRateCtrl;
  late TextEditingController _footerCtrl;

  AppSettings _settings = AppSettings.defaults();

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController();
    _gstRateCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final s = await SupabaseService().getSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _businessNameCtrl.text = s.businessName;
        _gstRateCtrl.text = s.gstRate.toString();
        _footerCtrl.text = s.footerMessage;
        _isLoading = false;
      });
      for (final ctrl in [_businessNameCtrl, _gstRateCtrl, _footerCtrl]) {
        ctrl.addListener(() => setState(() => _hasChanges = true));
      }
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _gstRateCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final updated = _settings.copyWith(
      businessName: _businessNameCtrl.text.trim(),
      gstRate: double.tryParse(_gstRateCtrl.text) ?? 0,
      footerMessage: _footerCtrl.text.trim(),
    );
    await SupabaseService().saveSettings(updated);
    if (mounted) {
      setState(() {
        _settings = updated;
        _isSaving = false;
        _hasChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Settings',
      onNavigate: widget.onNavigate,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Text('⚙️', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 8),
                      Text('Settings',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins')),
                    ]),
                    const SizedBox(height: 4),
                    const Text(
                      'Connected to vkb_settings table',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 20),
                    _SettingsCard(
                      title: '🏪 Business Information',
                      subtitle: 'Saved in vkb_settings table',
                      children: [
                        _FormField(
                          label: 'Business Name',
                          hint: 'e.g. VKB Bakery',
                          controller: _businessNameCtrl,
                          icon: Icons.store_rounded,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        _FormField(
                          label: 'Bill Footer Message',
                          hint: 'e.g. Thank you! Visit again!',
                          controller: _footerCtrl,
                          icon: Icons.message_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsCard(
                      title: '💰 Tax & Billing',
                      subtitle: 'GST rate — used in all bills automatically',
                      children: [
                        _FormField(
                          label: 'GST Rate (%)',
                          hint: 'e.g. 5',
                          controller: _gstRateCtrl,
                          icon: Icons.percent_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final d = double.tryParse(v);
                            if (d == null) return 'Invalid number';
                            if (d < 0 || d > 100) return 'Must be 0–100';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _GstPreviewTile(
                          gstRate: double.tryParse(_gstRateCtrl.text) ?? 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: VKBButton(
                        label: _hasChanges ? 'Save Changes' : 'Settings Saved ✅',
                        isLoading: _isSaving,
                        onTap: _hasChanges ? _saveSettings : null,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Center(
                      child: Column(children: [
                        Text('🍞', style: TextStyle(fontSize: 24)),
                        SizedBox(height: 4),
                        Text('VKB Bakery ERP v1.0.0',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                fontFamily: 'Poppins')),
                        Text('Powered by Supabase',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontFamily: 'Poppins')),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _SettingsCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins')),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Poppins')),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
        ),
      ),
    ]);
  }
}

class _GstPreviewTile extends StatelessWidget {
  final double gstRate;
  const _GstPreviewTile({required this.gstRate});

  @override
  Widget build(BuildContext context) {
    const sample = 100.0;
    final gst = sample * (gstRate / 100);
    final total = sample + gst;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PreviewItem(label: 'Base', value: '₹100'),
          const Text('→', style: TextStyle(color: AppColors.textTertiary)),
          _PreviewItem(label: 'GST', value: '+₹${gst.toStringAsFixed(1)}', color: AppColors.warning),
          const Text('→', style: TextStyle(color: AppColors.textTertiary)),
          _PreviewItem(label: 'Total', value: '₹${total.toStringAsFixed(1)}', color: AppColors.primary, isBold: true),
        ],
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;
  const _PreviewItem({required this.label, required this.value, this.color = AppColors.textSecondary, this.isBold = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600, color: color, fontFamily: 'Poppins')),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontFamily: 'Poppins')),
      ]);
}