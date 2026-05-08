import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _nameCtrl            = TextEditingController();
  final _emailCtrl           = TextEditingController();
  final _passwordCtrl        = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _bgColor     = Color(0xFFF8FAFC);
  static const Color _cardColor   = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size : 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior       : SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.register(
        name                : _nameCtrl.text.trim(),
        email               : _emailCtrl.text.trim(),
        password            : _passwordCtrl.text,
        passwordConfirmation: _passwordConfirmCtrl.text,
      );
      if (!mounted) return;
      if (result['status'] == 201) {
        _showSnackBar('Registrasi berhasil! Selamat datang 🎱', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      } else {
        final data   = result['data'];
        String msg   = data['message'] ?? 'Registrasi gagal';
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          msg = errors.values.first[0];
        }
        _showSnackBar(msg);
      }
    } catch (_) {
      _showSnackBar('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation      : 0,
        leading        : IconButton(
          icon     : const Icon(Icons.arrow_back_ios_new,
              color: _textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Akun',
          style: TextStyle(
              color: _textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              // ── ILUSTRASI HEADER ───────────────────────────
              Container(
                padding   : const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                    begin : Alignment.topLeft,
                    end   : Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding   : const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color       : _primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daftar Sekarang',
                            style: TextStyle(
                              color     : _textDark,
                              fontSize  : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Buat akun untuk mulai reservasi meja billiard',
                            style: TextStyle(
                                color  : _textGrey,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── FORM CARD ──────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color       : _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow   : [
                    BoxShadow(
                      color     : Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset    : const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // Nama
                      _buildLabel('Nama Lengkap'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _nameCtrl,
                        hint      : 'Masukkan nama lengkap',
                        icon      : Icons.person_outline,
                        validator : (v) {
                          if (v == null || v.isEmpty) return 'Nama wajib diisi';
                          if (v.length < 3) return 'Nama minimal 3 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
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

                      // Password
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _passwordCtrl,
                        hint      : 'Minimal 8 karakter',
                        icon      : Icons.lock_outline,
                        obscure   : _obscurePass,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textGrey, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 8) return 'Minimal 8 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Konfirmasi Password
                      _buildLabel('Konfirmasi Password'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _passwordConfirmCtrl,
                        hint      : 'Ulangi password Anda',
                        icon      : Icons.lock_outline,
                        obscure   : _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textGrey, size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Konfirmasi password wajib diisi';
                          if (v != _passwordCtrl.text)
                            return 'Password tidak cocok';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Tombol Daftar
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor        : _primary,
                            foregroundColor        : Colors.white,
                            disabledBackgroundColor: _primary.withOpacity(0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : const Text(
                                  'Daftar Sekarang',
                                  style: TextStyle(
                                      fontSize  : 15,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Setelah tombol Daftar Sekarang, sebelum SizedBox(height: 20)
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text('Lanjutkan tanpa login',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Link Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sudah punya akun? ',
                      style: TextStyle(color: _textGrey, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Masuk di sini',
                      style: TextStyle(
                        color     : _primary,
                        fontWeight: FontWeight.bold,
                        fontSize  : 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize  : 13,
          fontWeight: FontWeight.w600,
          color     : _textDark,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure         = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller  : controller,
      obscureText : obscure,
      keyboardType: keyboardType,
      style       : const TextStyle(color: _textDark, fontSize: 14),
      decoration  : InputDecoration(
        hintText      : hint,
        hintStyle     : TextStyle(color: _textGrey.withOpacity(0.6), fontSize: 13),
        prefixIcon    : Icon(icon, color: _textGrey, size: 20),
        suffixIcon    : suffixIcon,
        filled        : true,
        fillColor     : _bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide  : const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}