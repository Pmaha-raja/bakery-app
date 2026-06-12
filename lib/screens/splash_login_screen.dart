import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_theme.dart';
import '../services/supabase_service.dart';

// ─── Splash Screen ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  String _bizName = 'VKB Bakery';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    final settings = await SupabaseService().getSettings();
    if (mounted) setState(() => _bizName = settings.businessName);
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ── Red → Black gradient background ──
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ──
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('🍞', style: TextStyle(fontSize: 64)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Business Name ──
                  Text(
                    _bizName,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Subtitle ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'Bakery Management System',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),

                  // ── Loading ──
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _isError = false;
  bool _isLoading = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKeyTap(String val) {
    if (_enteredPin.length >= 4 || _isLoading) return;
    setState(() {
      _enteredPin += val;
      _isError = false;
    });
    if (_enteredPin.length == 4) {
      Future.delayed(
          const Duration(milliseconds: 200), () => _verify());
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty || _isLoading) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _isError = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    final isValid = await SupabaseService().verifyPin(_enteredPin);
    if (!mounted) return;
    if (isValid) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _shakeCtrl.forward(from: 0);
      setState(() {
        _isError = true;
        _isLoading = false;
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ── Red → Black gradient ──
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // ── Logo ──
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child:
                              Text('🍞', style: TextStyle(fontSize: 44)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Title ──
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your PIN to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 44),

                  // ── PIN Dots ──
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) {
                      final shake = _isError
                          ? 14 *
                              (_shakeAnim.value < 0.5
                                  ? _shakeAnim.value
                                  : 1 - _shakeAnim.value)
                          : 0.0;
                      return Transform.translate(
                          offset: Offset(shake, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 14),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isError
                                ? AppColors.error
                                : filled
                                    ? AppColors.primary
                                    : Colors.transparent,
                            border: Border.all(
                              color: _isError
                                  ? AppColors.error
                                  : filled
                                      ? AppColors.primary
                                      : Colors.white30,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── Error / Loading ──
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 20,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : AnimatedOpacity(
                            opacity: _isError ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Text(
                              '❌ Wrong PIN. Try again.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 36),

                  // ── Number Pad ──
                  _buildNumPad(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 72);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _NumKey(
                  label: key,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    key == '⌫' ? _onDelete() : _onKeyTap(key);
                  },
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Number Key ───────────────────────────────────────────────────────────────
class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDelete = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDelete
              ? null
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDelete
              ? AppColors.error.withValues(alpha: 0.15)
              : null,
          border: Border.all(
            color: isDelete
                ? AppColors.error.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isDelete ? 20 : 26,
              fontWeight: FontWeight.w600,
              color: isDelete ? AppColors.error : Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }
}