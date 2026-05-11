import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _bgColor     = Color(0xFFF8FAFC);
  static const Color _cardColor   = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.login(
        email   : _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      if (result['status'] == 200) {
        _showSnackBar('Login berhasil! Selamat datang 👋', isError: false);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnackBar(result['data']['message'] ?? 'Login gagal');
      }
    } catch (_) {
      _showSnackBar('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (!mounted) return;
      if (result == null) return;
      if (result['status'] == 200) {
        _showSnackBar('Login dengan Google berhasil!', isError: false);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnackBar(result['data']['message'] ?? 'Login Google gagal');
      }
    } catch (_) {
      _showSnackBar('Google Sign-In gagal');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // 🔥 Lanjutkan tanpa login
  void _continueAsGuest() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4))
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Masuk',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _textDark)),
                      const SizedBox(height: 4),
                      const Text('Selamat datang kembali!',
                          style: TextStyle(color: _textGrey, fontSize: 13)),
                      const SizedBox(height: 24),

                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller  : _emailCtrl,
                        hint        : 'contoh@email.com',
                        icon        : Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator   : (v) {
                          if (v == null || v.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _passwordCtrl,
                        hint      : 'Minimal 8 karakter',
                        icon      : Icons.lock_outline,
                        obscure   : _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textGrey, size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 8) return 'Minimal 8 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      _buildPrimaryButton(
                        label    : 'Masuk',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        const Expanded(child: Divider(color: _borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('atau masuk dengan',
                              style: TextStyle(color: _textGrey, fontSize: 12)),
                        ),
                        const Expanded(child: Divider(color: _borderColor)),
                      ]),
                      const SizedBox(height: 16),

                      _buildGoogleButton(),
                      const SizedBox(height: 16),

                      // 🔥 Tombol lanjutkan tanpa login
                      _buildGuestButton(),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Belum punya akun? ',
                              style: TextStyle(color: _textGrey, fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen())),
                            child: const Text('Daftar sekarang',
                                style: TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft : Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -30, right: -30,
          child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08)),
          ),
        ),
        Positioned(
          bottom: -20, left: -20,
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06)),
          ),
        ),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                'assets/images/brand.png', // Sesuaikan nama file
                width: 90,  // Atur ukuran sesuai keinginan
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Etan Patung Booking',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text('Reservasi meja billiard mudah & cepat',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _textDark));

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller  : controller,
      obscureText : obscure,
      keyboardType: keyboardType,
      style       : const TextStyle(color: _textDark, fontSize: 14),
      decoration  : InputDecoration(
        hintText  : hint,
        hintStyle : TextStyle(color: _textGrey.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _textGrey, size: 20),
        suffixIcon: suffixIcon,
        filled    : true,
        fillColor : _bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide  : const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide  : const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide  : const BorderSide(color: _primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide  : const BorderSide(color: Color(0xFFDC2626))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide  : const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor        : _primary,
          foregroundColor        : Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          foregroundColor: _textDark,
          side : const BorderSide(color: _borderColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _textGrey))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset(
                  'assets/images/google.png', 
                  width: 22, 
                  height: 22,
                ),
                const SizedBox(width: 10),
                const Text('Masuk dengan Google',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }

  // 🔥 Tombol guest
  Widget _buildGuestButton() {
    return SizedBox(
      height: 50,
      child: TextButton(
        onPressed: _continueAsGuest,
        style: TextButton.styleFrom(
          foregroundColor: _textGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _borderColor),
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_outline, size: 18, color: _textGrey),
          const SizedBox(width: 8),
          Text('Lanjutkan tanpa login',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textGrey)),
        ]),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint  = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 3.14, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, -1.57, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        3.14, 0.79, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        3.93, 0.78, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(
            center.dx, center.dy - radius * 0.18, radius, radius * 0.36),
        paint);
  }

  @override
  bool shouldRepaint(_) => false;
}