import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/reservation_service.dart';
import '../../utils/storage.dart';

/// Versi Web dari ReservationScreen.
/// Ditampilkan sebagai Dialog dari MainShell (web).
/// Layout: 2 kolom (kiri = pilih meja + tanggal, kanan = form data diri).
class ReservationWebScreen extends StatefulWidget {
  const ReservationWebScreen({super.key});

  @override
  State<ReservationWebScreen> createState() => _ReservationWebScreenState();
}

class _ReservationWebScreenState extends State<ReservationWebScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  List<dynamic> _tables      = [];
  List<dynamic> _packages    = [];
  List<dynamic> _bookedSlots = [];

  int?       _selectedTableId;
  int?       _selectedPackageId;
  DateTime?  _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoadingInit  = true;
  bool _isLoadingSlots = false;
  bool _isSubmitting   = false;
  bool _isGuest        = false;

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _bgColor     = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _warning     = Color(0xFFEA580C);
  static const Color _danger      = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final token = await Storage.getToken();
    if (token == null) {
      setState(() { _isGuest = true; _isLoadingInit = false; });
      return;
    }
    try {
      final results = await Future.wait([
        ReservationService.getTables(),
        ReservationService.getPackages(),
      ]);
      if (!mounted) return;
      setState(() {
        _tables   = results[0];
        _packages = results[1];
      });
    } catch (e) {
      _showSnackBar('Gagal memuat data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInit = false);
    }
  }

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context    : context,
      initialDate: now,
      firstDate  : now,
      lastDate   : now.add(const Duration(days: 30)),
      builder    : (ctx, child) => Theme(
        data : Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (date == null) return;
    setState(() {
      _selectedDate = date;
      _startTime    = null;
      _endTime      = null;
      _bookedSlots  = [];
    });
    if (_selectedTableId != null) await _loadBookedSlots();
  }

  Future<void> _loadBookedSlots() async {
    if (_selectedTableId == null || _selectedDate == null) return;
    setState(() => _isLoadingSlots = true);
    try {
      final slots = await ReservationService.getBookedSlots(
        idBilliards    : _selectedTableId!,
        reservationDate: _selectedDate!.toIso8601String().split('T').first,
      );
      if (mounted) setState(() => _bookedSlots = slots);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
      context    : context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder    : (ctx, child) => Theme(
        data : Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      _startTime = t;
      if (_endTime != null && !_isEndAfterStart(_endTime!)) _endTime = null;
    });
  }

  Future<void> _pickEndTime() async {
    if (_startTime == null) {
      _showSnackBar('Pilih jam mulai terlebih dahulu');
      return;
    }
    final t = await showTimePicker(
      context    : context,
      initialTime: _endTime ??
          TimeOfDay(
              hour  : (_startTime!.hour + 1).clamp(0, 23),
              minute: _startTime!.minute),
      builder: (ctx, child) => Theme(
        data : Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (t == null) return;
    if (!_isEndAfterStart(t)) {
      _showSnackBar('Jam selesai harus lebih dari jam mulai');
      return;
    }
    if (_bookedSlots.isNotEmpty && _isConflict(t)) {
      _showSnackBar('Jam tersebut bentrok dengan reservasi lain.');
      return;
    }
    setState(() => _endTime = t);
  }

  bool _isEndAfterStart(TimeOfDay end) {
    if (_startTime == null) return true;
    return (end.hour * 60 + end.minute) >
        (_startTime!.hour * 60 + _startTime!.minute);
  }

  bool _isConflict(TimeOfDay endTime) {
    if (_startTime == null || _bookedSlots.isEmpty) return false;
    final newStart = _startTime!.hour * 60 + _startTime!.minute;
    final newEnd   = endTime.hour * 60 + endTime.minute;
    for (final slot in _bookedSlots) {
      final startStr = (slot['start_time'] as String? ?? '').trim();
      final endStr   = (slot['end_time']   as String? ?? '').trim();
      if (startStr.isEmpty || endStr.isEmpty) continue;
      if (startStr.startsWith('00:00') && endStr.startsWith('00:00')) continue;
      final sp = startStr.split(':');
      final ep = endStr.split(':');
      if (sp.length < 2 || ep.length < 2) continue;
      final sStart = (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp[1]) ?? 0);
      final sEnd   = (int.tryParse(ep[0]) ?? 0) * 60 + (int.tryParse(ep[1]) ?? 0);
      if (newStart < sEnd && newEnd > sStart) return true;
    }
    return false;
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTableId == null) { _showSnackBar('Pilih meja terlebih dahulu'); return; }
    if (_selectedDate    == null) { _showSnackBar('Pilih tanggal reservasi'); return; }
    if (_startTime       == null) { _showSnackBar('Pilih jam mulai'); return; }
    if (_endTime         == null) { _showSnackBar('Pilih jam selesai'); return; }

    setState(() => _isSubmitting = true);
    try {
      final result = await ReservationService.createReservation(
        idBilliards    : _selectedTableId!,
        idPackages     : _selectedPackageId,
        customerName   : _nameCtrl.text.trim(),
        customerPhone  : _phoneCtrl.text.trim(),
        reservationDate: _selectedDate!.toIso8601String().split('T').first,
        startTime      : _formatTime(_startTime!),
        endTime        : _formatTime(_endTime!),
      );
      if (!mounted) return;
      if (result['status'] == 201) {
        _showSnackBar('Reservasi berhasil! Menunggu konfirmasi admin.', isError: false);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = result['data'];
        final code = data['code'] ?? '';
        final msg  = data['message'] ?? 'Reservasi gagal';
        if (code == 'TIME_CONFLICT') {
          _showSnackBar('Meja sudah dipesan pada jam tersebut. Pilih jam lain.');
          await _loadBookedSlots();
        } else {
          _showSnackBar(msg);
        }
      }
    } catch (_) {
      _showSnackBar('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? _danger : _success,
      behavior       : SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Buat Reservasi',
            style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: _textDark),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoadingInit
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _isGuest
              ? _buildGuestView()
              : _buildTwoColumnForm(),
    );
  }

  // ── Guest view ───────────────────────────────────────
  Widget _buildGuestView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 56, color: _primary),
            ),
            const SizedBox(height: 20),
            const Text('Login Diperlukan',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 8),
            Text('Kamu perlu login untuk membuat reservasi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _textGrey, height: 1.5)),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon : const Icon(Icons.login, size: 18),
                label: const Text('Masuk ke Akun',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Two Column Form ──────────────────────────────────
  Widget _buildTwoColumnForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            _buildInfoBanner(),
            const SizedBox(height: 24),

            // 2 kolom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kolom kiri: meja, paket, tanggal, jam
                Expanded(child: _buildLeftColumn()),
                const SizedBox(width: 24),
                // Kolom kanan: data diri + submit
                Expanded(child: _buildRightColumn()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reservasi akan menunggu konfirmasi admin. Setelah dikonfirmasi, QR pembayaran akan tersedia.',
              style: TextStyle(
                  fontSize: 12,
                  color: _primary.withOpacity(0.85),
                  height: 1.4),
            ),
          ),
        ]),
      );

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detail Reservasi', Icons.event_outlined),
        const SizedBox(height: 16),

        _buildLabel('Pilih Meja'),
        const SizedBox(height: 8),
        _buildDropdownMeja(),
        const SizedBox(height: 16),

        _buildLabel('Paket', suffix: 'Opsional'),
        const SizedBox(height: 8),
        _buildDropdownPaket(),
        const SizedBox(height: 16),

        _buildLabel('Tanggal Reservasi'),
        const SizedBox(height: 8),
        _buildDatePicker(),
        const SizedBox(height: 16),

        _buildLabel('Jam Bermain'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildTimePicker(
              label: 'Jam Mulai', time: _startTime,
              onTap: _pickStartTime, isActive: _selectedDate != null)),
          const SizedBox(width: 12),
          Expanded(child: _buildTimePicker(
              label: 'Jam Selesai', time: _endTime,
              onTap: _pickEndTime, isActive: _startTime != null)),
        ]),

        if (_isLoadingSlots) ...[
          const SizedBox(height: 10),
          const Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
            ),
          ),
        ] else if (_bookedSlots.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBookedSlotsInfo(),
        ],
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Data Pemesan', Icons.person_outline),
        const SizedBox(height: 16),

        _buildLabel('Nama Lengkap'),
        const SizedBox(height: 8),
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

        _buildLabel('Nomor Telepon'),
        const SizedBox(height: 8),
        _buildTextField(
          controller     : _phoneCtrl,
          hint           : 'contoh: 08123456789',
          icon           : Icons.phone_outlined,
          keyboardType   : TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.isEmpty) return 'Nomor telepon wajib diisi';
            if (v.length < 10) return 'Nomor telepon tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 32),

        // Submit button
        SizedBox(
          width : double.infinity,
          height: 52,
          child : ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor        : _primary,
              foregroundColor        : Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.6),
              elevation              : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Text('Buat Reservasi',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _textDark)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: _borderColor)),
      ]);

  Widget _buildLabel(String text, {String? suffix}) => Row(children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark)),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: Text(suffix,
                style:
                    const TextStyle(fontSize: 10, color: _textGrey)),
          ),
        ],
      ]);

  Widget _buildBookedSlotsInfo() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color : _warning.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _warning.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_busy_outlined, size: 13, color: _warning),
            const SizedBox(width: 6),
            Text('Jam yang sudah dipesan:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _warning)),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing   : 6,
            runSpacing: 4,
            children  : _bookedSlots
                .where((s) {
                  final str = s['start_time']?.toString() ?? '';
                  return str.isNotEmpty && !str.startsWith('00:00');
                })
                .map((slot) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color       : _warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${slot['start_time']} – ${slot['end_time']}',
                        style: TextStyle(
                            fontSize: 11,
                            color: _warning,
                            fontWeight: FontWeight.w500),
                      ),
                    ))
                .toList(),
          ),
        ]),
      );

  Widget _buildDropdownMeja() => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value    : _selectedTableId,
            isExpanded: true,
            hint     : Text('Pilih meja',
                style: TextStyle(
                    color: _textGrey.withOpacity(0.7), fontSize: 13)),
            icon: const Icon(Icons.keyboard_arrow_down, color: _textGrey),
            items: _tables.map<DropdownMenuItem<int>>((t) {
              final isNonaktif = t['table_status']?.toString() == 'nonaktif';
              final isOccupied = t['session_status']?.toString() == 'aktif';
              return DropdownMenuItem<int>(
                value  : t['id'] as int,
                enabled: !isNonaktif,
                child  : Row(children: [
                  Icon(Icons.table_bar,
                      size : 16,
                      color: isNonaktif
                          ? Colors.grey
                          : isOccupied ? _danger : _primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${t['name']} · ${t['size']} ft',
                        style: TextStyle(
                            fontSize: 13,
                            color: isNonaktif ? Colors.grey : _textDark)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isNonaktif
                          ? Colors.grey.withOpacity(0.1)
                          : isOccupied
                              ? _danger.withOpacity(0.1)
                              : _success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isNonaktif
                          ? 'Nonaktif'
                          : isOccupied ? 'Dipakai' : 'Kosong',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isNonaktif
                              ? Colors.grey
                              : isOccupied ? _danger : _success),
                    ),
                  ),
                ]),
              );
            }).toList(),
            onChanged: (val) async {
              setState(() {
                _selectedTableId = val;
                _startTime       = null;
                _endTime         = null;
                _bookedSlots     = [];
              });
              if (val != null && _selectedDate != null) {
                await _loadBookedSlots();
              }
            },
          ),
        ),
      );

  Widget _buildDropdownPaket() => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value    : _selectedPackageId,
            isExpanded: true,
            hint: Text('Tanpa paket',
                style: TextStyle(
                    color: _textGrey.withOpacity(0.7), fontSize: 13)),
            icon: const Icon(Icons.keyboard_arrow_down, color: _textGrey),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('Tanpa paket',
                    style: TextStyle(fontSize: 13, color: _textGrey)),
              ),
              ..._packages.map<DropdownMenuItem<int?>>((p) =>
                  DropdownMenuItem<int?>(
                    value: p['id'] as int,
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 15, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(p['package_name']?.toString() ?? '-',
                              style: const TextStyle(
                                  fontSize: 13, color: _textDark))),
                      Text('${p['time']} menit',
                          style: const TextStyle(
                              fontSize: 11, color: _textGrey)),
                    ]),
                  )),
            ],
            onChanged: (val) =>
                setState(() => _selectedPackageId = val),
          ),
        ),
      );

  Widget _buildDatePicker() {
    final hasDate   = _selectedDate != null;
    final formatted = hasDate
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/'
          '${_selectedDate!.month.toString().padLeft(2, '0')}/'
          '${_selectedDate!.year}'
        : null;

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasDate ? _primary.withOpacity(0.4) : _borderColor),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 18,
              color: hasDate ? _primary : _textGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatted ?? 'Pilih tanggal',
              style: TextStyle(
                  fontSize: 13,
                  color: hasDate ? _textDark : _textGrey.withOpacity(0.7),
                  fontWeight:
                      hasDate ? FontWeight.w500 : FontWeight.w400),
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: _textGrey, size: 20),
        ]),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    final hasValue = time != null;
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasValue ? _primary.withOpacity(0.4) : _borderColor),
        ),
        child: Row(children: [
          Icon(Icons.access_time_outlined,
              size : 16,
              color: hasValue
                  ? _primary
                  : isActive ? _textGrey : _borderColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasValue ? _formatTime(time) : label,
              style: TextStyle(
                  fontSize  : 13,
                  color     : hasValue
                      ? _textDark
                      : isActive
                          ? _textGrey.withOpacity(0.7)
                          : _borderColor,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller     : controller,
        keyboardType   : keyboardType,
        inputFormatters: inputFormatters,
        style          : const TextStyle(color: _textDark, fontSize: 14),
        decoration     : InputDecoration(
          hintText  : hint,
          hintStyle : TextStyle(
              color: _textGrey.withOpacity(0.6), fontSize: 13),
          prefixIcon: Icon(icon, color: _textGrey, size: 20),
          filled    : true,
          fillColor : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  : const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  : const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  :
                  const BorderSide(color: _primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  : const BorderSide(color: _danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide  :
                  const BorderSide(color: _danger, width: 1.5)),
        ),
        validator: validator,
      );
}