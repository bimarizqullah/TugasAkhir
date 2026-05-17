import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Edit Profile Screen — dipakai oleh mobile (ProfileScreen)
/// dan web (dropdown sidebar). Layout adaptif.
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDialog; // true = tampil sebagai dialog di web

  const EditProfileScreen({
    super.key,
    required this.user,
    this.isDialog = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey        = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  final _currPassCtrl   = TextEditingController();
  final _newPassCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoading       = false;
  bool _changePassword  = false;
  bool _showCurrPass    = false;
  bool _showNewPass     = false;
  bool _showConfirmPass = false;

  static const Color _primary  = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _bgColor  = Color(0xFFF8FAFC);
  static const Color _danger   = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.user['name']  ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.updateProfile(
        name : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        currentPassword     : _changePassword ? _currPassCtrl.text : null,
        newPassword         : _changePassword ? _newPassCtrl.text  : null,
        newPasswordConfirmation: _changePassword ? _confirmPassCtrl.text : null,
      );

      if (!mounted) return;
      final status = result['status'] as int;

      if (status == 200) {
        _showSnack('Profil berhasil diperbarui', isError: false);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, result['data']['user']);
      } else {
        final msg = result['data']['message'] ?? 'Gagal memperbarui profil';
        _showSnack(msg, isError: true);
      }
    } catch (e) {
      _showSnack('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _danger : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) return _buildDialogBody();
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primary))
                : const Text('Simpan',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildForm(),
    );
  }

  // ── Untuk web — tampil sebagai dialog body ──────────
  Widget _buildDialogBody() {
    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Text('Edit Profil',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textDark)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _textGrey, size: 20),
                ),
              ],
            ),
          ),
          // Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: _buildFields()),
            ),
          ),
          // Footer buttons
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal', style: TextStyle(color: _textGrey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile — form di dalam Scaffold body ───────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(key: _formKey, child: _buildFields()),
    );
  }

  // ── Fields — shared mobile & web ───────────────────
  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar info
        Center(
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 38, color: _primary),
            ),
            const SizedBox(height: 8),
            Text(widget.user['email'] ?? '',
                style: const TextStyle(fontSize: 13, color: _textGrey)),
            const SizedBox(height: 24),
          ]),
        ),

        _sectionLabel('Informasi Akun'),
        const SizedBox(height: 10),
        _buildField(
          controller: _nameCtrl,
          label: 'Nama Lengkap',
          icon: Icons.person_outline,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
            if (!v.contains('@')) return 'Format email tidak valid';
            return null;
          },
        ),

        const SizedBox(height: 24),

        // Toggle ganti password
        GestureDetector(
          onTap: () => setState(() {
            _changePassword = !_changePassword;
            if (!_changePassword) {
              _currPassCtrl.clear();
              _newPassCtrl.clear();
              _confirmPassCtrl.clear();
            }
          }),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: _changePassword ? _primary : Colors.transparent,
                border: Border.all(
                    color: _changePassword ? _primary : const Color(0xFFCBD5E1),
                    width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: _changePassword
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Text('Ganti Password',
                style: TextStyle(fontWeight: FontWeight.w600, color: _textDark, fontSize: 14)),
          ]),
        ),

        if (_changePassword) ...[
          const SizedBox(height: 16),
          _sectionLabel('Password'),
          const SizedBox(height: 10),
          _buildPasswordField(
            controller: _currPassCtrl,
            label: 'Password Lama',
            show: _showCurrPass,
            onToggle: () => setState(() => _showCurrPass = !_showCurrPass),
            validator: (v) => (v == null || v.isEmpty) ? 'Masukkan password lama' : null,
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: _newPassCtrl,
            label: 'Password Baru',
            show: _showNewPass,
            onToggle: () => setState(() => _showNewPass = !_showNewPass),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Masukkan password baru';
              if (v.length < 8) return 'Minimal 8 karakter';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: _confirmPassCtrl,
            label: 'Konfirmasi Password Baru',
            show: _showConfirmPass,
            onToggle: () => setState(() => _showConfirmPass = !_showConfirmPass),
            validator: (v) =>
                v != _newPassCtrl.text ? 'Password tidak cocok' : null,
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _textGrey, letterSpacing: 0.5),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _textGrey),
        prefixIcon: Icon(icon, size: 18, color: _textGrey),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _textGrey),
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _textGrey),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: _textGrey),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}