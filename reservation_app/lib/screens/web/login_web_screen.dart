import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../mobile/register_screen.dart';

/// Versi Web dari LoginScreen.
/// Layout: kiri = branding panel gradient, kanan = form login.
/// Sama sekali BEDA dari mobile — bukan stretch.
class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({super.key});

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _bgColor     = Color(0xFFF8FAFC);
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
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
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

  void _continueAsGuest() =>
      Navigator.pushReplacementNamed(context, '/home');

  // ════════════════════════════════════════════════════
  //  BUILD — 2 kolom penuh layar
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Kiri 55%: Branding Panel ──
          Expanded(
            flex: 55,
            child: _buildBrandPanel(),
          ),

          // ── Kanan 45%: Form ──
          Expanded(
            flex: 45,
            child: Container(
              color: _bgColor,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 56, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Branding Panel ───────────────────────────────────
  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin : Alignment.topLeft,
          end   : Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Dekorasi lingkaran
          Positioned(top: -80, right: -80,
              child: _circle(260, Colors.white.withOpacity(0.05))),
          Positioned(bottom: -60, left: -60,
              child: _circle(220, Colors.white.withOpacity(0.04))),
          Positioned(top: 120, left: -40,
              child: _circle(140, Colors.white.withOpacity(0.06))),
          Positioned(bottom: 80, right: 40,
              child: _circle(80, Colors.white.withOpacity(0.07))),

          // Konten
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.sports_bar_rounded,
                      size: 48, color: Colors.white),
                ),
                const SizedBox(height: 36),

                const Text(
                  'Etan Patung\nBooking System',
                  style: TextStyle(
                    color     : Colors.white,
                    fontSize  : 38,
                    fontWeight: FontWeight.bold,
                    height    : 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sistem reservasi meja billiard\nmodern, mudah, dan real-time.',
                  style: TextStyle(
                    color : Colors.white.withOpacity(0.75),
                    fontSize: 16,
                    height  : 1.6,
                  ),
                ),
                const SizedBox(height: 52),

                // Feature list
                ...[
                  (Icons.bolt_outlined,       'Informasi meja secara real-time'),
                  (Icons.event_available,     'Reservasi mudah & cepat'),
                  (Icons.queue_play_next,     'Sistem antrian otomatis'),
                  (Icons.security_outlined,   'Login aman dengan Google'),
                ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.$1, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Text(e.$2,
                        style: TextStyle(
                            color  : Colors.white.withOpacity(0.88),
                            fontSize: 15)),
                  ]),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── Form ─────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Selamat datang kembali',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _textDark)),
          const SizedBox(height: 6),
          const Text('Masuk ke akun Anda untuk melanjutkan',
              style: TextStyle(fontSize: 14, color: _textGrey)),
          const SizedBox(height: 36),

          // Email
          _buildLabel('Email'),
          const SizedBox(height: 8),
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
          const SizedBox(height: 20),

          // Password
          _buildLabel('Password'),
          const SizedBox(height: 8),
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
                color: _textGrey,
                size : 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password wajib diisi';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 28),

          // Tombol Masuk
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor        : _primary,
                foregroundColor        : Colors.white,
                disabledBackgroundColor: _primary.withOpacity(0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Masuk',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(children: [
            const Expanded(child: Divider(color: _borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('atau masuk dengan',
                  style: TextStyle(color: _textGrey, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: _borderColor)),
          ]),
          const SizedBox(height: 20),

          // Google
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: _textDark,
                side : const BorderSide(color: _borderColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _textGrey))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata_rounded,
                            size: 26, color: Color(0xFF4285F4)),
                        SizedBox(width: 10),
                        Text('Masuk dengan Google',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Lanjutkan tanpa login
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: _continueAsGuest,
              style: TextButton.styleFrom(
                foregroundColor: _textGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side        : const BorderSide(color: _borderColor),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Lanjutkan tanpa login',
                      style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Link daftar
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Belum punya akun? ',
                style: TextStyle(color: _textGrey, fontSize: 13)),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text('Daftar sekarang',
                  style: TextStyle(
                      color     : _primary,
                      fontWeight: FontWeight.bold,
                      fontSize  : 13)),
            ),
          ]),
        ],
      ),
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
      style: const TextStyle(color: _textDark, fontSize: 14),
      decoration: InputDecoration(
        hintText  : hint,
        hintStyle : TextStyle(color: _textGrey.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _textGrey, size: 20),
        suffixIcon: suffixIcon,
        filled    : true,
        fillColor : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
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
            borderSide  :
                const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
      ),
      validator: validator,
    );
  }
}