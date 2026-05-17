import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/reservation_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/storage.dart';
import '../mobile/payment_screen.dart';

/// Versi Web dari HistoryScreen.
/// Layout: tabel di kiri + panel detail di kanan (master-detail pattern).
class HistoryWebScreen extends StatefulWidget {
  const HistoryWebScreen({super.key});

  @override
  State<HistoryWebScreen> createState() => _HistoryWebScreenState();
}

class _HistoryWebScreenState extends State<HistoryWebScreen> {
  List<dynamic> _reservations = [];
  dynamic       _selected;
  bool          _isLoading = true;
  int?          _currentUserId;
  StreamSubscription? _wsSub;
  String _filterStatus = 'semua';

  static const Color _primary  = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _bgColor  = Color(0xFFF8FAFC);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _success  = Color(0xFF16A34A);
  static const Color _warning  = Color(0xFFEA580C);
  static const Color _info     = Color(0xFF0284C7);

  static const List<Map<String, String>> _filters = [
    {'key': 'semua',               'label': 'Semua'},
    {'key': 'menunggu_konfirmasi', 'label': 'Menunggu'},
    {'key': 'dikonfirmasi',        'label': 'Dikonfirmasi'},
    {'key': 'berhasil',            'label': 'Berhasil'},
    {'key': 'gagal',               'label': 'Gagal'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReservations();
    _listenWebSocket();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _listenWebSocket() {
    _wsSub = WebSocketService.onReservationEvent.listen((data) {
      if (!mounted) return;
      final eventUserId = data['id_users'];
      if (_currentUserId != null &&
          eventUserId != null &&
          eventUserId.toString() != _currentUserId.toString()) return;

      if (data['reservation_status']?.toString() == 'dikonfirmasi') {
        _showApprovalNotif(data);
      }
      setState(() {
        _reservations.removeWhere(
            (r) => r['id']?.toString() == data['id']?.toString());
        _reservations.insert(0, data);
        if (_selected != null &&
            _selected['id']?.toString() == data['id']?.toString()) {
          _selected = data;
        }
      });
    });
  }

  void _showApprovalNotif(Map<String, dynamic> data) {
    final reservationId = data['id'] as int?;
    if (reservationId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Reservasi dikonfirmasi! QR pembayaran sudah siap.',
              style: TextStyle(fontSize: 13)),
        ),
      ]),
      backgroundColor: _success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      action: SnackBarAction(
        label: 'Bayar',
        textColor: Colors.white,
        onPressed: () => _openPayment(reservationId),
      ),
    ));
  }

  Future<void> _loadReservations() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final userStr = await Storage.getUser();
      if (userStr != null) {
        final user = jsonDecode(userStr);
        _currentUserId = (user['id'] ?? user['id_users']) as int?;
      }
      final data = await ReservationService.getReservations();
      if (!mounted) return;
      data.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      setState(() {
        _reservations = data;
        if (_selected != null) {
          _selected = _reservations.firstWhere(
            (r) => r['id']?.toString() == _selected['id']?.toString(),
            orElse: () => null,
          );
        }
      });
    } catch (e) {
      debugPrint('Load reservations error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPayment(int reservationId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentScreen(reservationId: reservationId, fromHistory: true),
      ),
    );
    if (result == true && mounted) await _loadReservations();
  }

  Future<void> _cancelReservation(dynamic r) async {
    final id   = r['id'] as int;
    final name = r['customer_name']?.toString() ?? 'reservasi ini';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Reservasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Yakin ingin membatalkan reservasi atas nama "$name"?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await ReservationService.cancelReservation(id);
      if (!mounted) return;
      if (result['status'] == 200) {
        setState(() {
          final idx = _reservations
              .indexWhere((r) => r['id']?.toString() == id.toString());
          if (idx != -1) {
            _reservations[idx] = {
              ..._reservations[idx] as Map,
              'reservation_status': 'gagal',
            };
            if (_selected?['id']?.toString() == id.toString()) {
              _selected = _reservations[idx];
            }
          }
        });
        _showSnackBar('Reservasi berhasil dibatalkan', isError: false);
      } else {
        _showSnackBar(result['data']['message'] ?? 'Gagal membatalkan');
      }
    } catch (_) {
      _showSnackBar('Gagal terhubung ke server');
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: isError ? _danger : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  List<dynamic> get _filtered => _filterStatus == 'semua'
      ? _reservations
      : _reservations
          .where((r) => r['reservation_status']?.toString() == _filterStatus)
          .toList();

  Color    _statusColor(String s) => switch (s) {
    'berhasil'            => _success,
    'selesai'             => _success,
    'dikonfirmasi'        => _info,
    'menunggu_konfirmasi' => _warning,
    'pending'             => _warning,
    'gagal'               => _danger,
    _                     => _textGrey,
  };

  String   _statusLabel(String s) => switch (s) {
    'berhasil'            => 'Berhasil',
    'selesai'             => 'Selesai',
    'dikonfirmasi'        => 'Dikonfirmasi',
    'menunggu_konfirmasi' => 'Menunggu',
    'pending'             => 'Menunggu',
    'gagal'               => 'Gagal',
    _                     => s,
  };

  IconData _statusIcon(String s) => switch (s) {
    'berhasil'            => Icons.check_circle_outline,
    'selesai'             => Icons.task_alt_outlined,
    'dikonfirmasi'        => Icons.thumb_up_outlined,
    'menunggu_konfirmasi' => Icons.access_time_outlined,
    'gagal'               => Icons.cancel_outlined,
    _                     => Icons.help_outline,
  };

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      const m = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      return '${dt.day.toString().padLeft(2,'0')} ${m[dt.month]} ${dt.year}';
    } catch (_) { return '-'; }
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _reservations.isEmpty
                    ? _buildEmptyState()
                    : _buildMasterDetail(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Riwayat Reservasi',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: _textDark)),
              Text('Pantau dan kelola semua reservasimu',
                  style: TextStyle(fontSize: 13, color: _textGrey)),
            ],
          ),
          const Spacer(),
          ..._filters.map((f) {
            final active = _filterStatus == f['key'];
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  _filterStatus = f['key']!;
                  _selected     = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? _primary : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(f['label']!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : _textGrey)),
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: _textGrey),
            onPressed: _loadReservations,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── Master-Detail ────────────────────────────────────
  Widget _buildMasterDetail() {
    final list = _filtered;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kiri: list
        SizedBox(
          width: 400,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Header list
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(children: [
                    Text('${list.length} Reservasi',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    const Spacer(),
                    const Text('Pilih untuk detail',
                        style: TextStyle(fontSize: 11, color: _textGrey)),
                  ]),
                ),
                // Rows
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text('Tidak ada data',
                              style: TextStyle(fontSize: 13, color: _textGrey)))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, i) => _buildRow(list[i]),
                        ),
                ),
              ],
            ),
          ),
        ),

        // Kanan: detail
        Expanded(
          child: _selected == null
              ? _buildDetailPlaceholder()
              : _buildDetailPanel(_selected!),
        ),
      ],
    );
  }

  Widget _buildRow(dynamic r) {
    final status     = r['reservation_status']?.toString() ?? '';
    final color      = _statusColor(status);
    final isSelected = _selected?['id']?.toString() == r['id']?.toString();

    final billiardName = r['billiard_name']?.toString().isNotEmpty == true
        ? r['billiard_name'].toString()
        : r['billiard']?['name']?.toString() ?? '-';

    return GestureDetector(
      onTap: () => setState(() => _selected = r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? _primary.withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: isSelected ? _primary : color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['customer_name']?.toString() ?? '-',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _primary : _textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  '$billiardName  ·  ${_formatDate(r['reservation_date']?.toString())}',
                  style: const TextStyle(fontSize: 11, color: _textGrey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statusLabel(status),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right,
              size: 16, color: isSelected ? _primary : _textGrey),
        ]),
      ),
    );
  }

  Widget _buildDetailPlaceholder() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.touch_app_outlined,
            size: 56, color: _textGrey.withValues(alpha: 0.25)),
        const SizedBox(height: 14),
        const Text('Pilih reservasi',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: _textGrey)),
        const SizedBox(height: 6),
        Text('Klik baris di kiri untuk melihat detail',
            style: TextStyle(
                fontSize: 13, color: _textGrey.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _buildDetailPanel(dynamic r) {
    final status        = r['reservation_status']?.toString() ?? '';
    final color         = _statusColor(status);
    final hasActiveQr   = r['has_active_qr'] == true;
    final paymentStatus = r['payment_status']?.toString();
    final reservationId = r['id'] as int;
    final canCancel     = status == 'menunggu_konfirmasi' ||
        status == 'dikonfirmasi' || status == 'pending';

    final billiardName = r['billiard_name']?.toString().isNotEmpty == true
        ? r['billiard_name'].toString()
        : r['billiard']?['name']?.toString() ?? '-';
    final packageName  = r['package_name']?.toString().isNotEmpty == true
        ? r['package_name'].toString()
        : r['package']?['package_name']?.toString() ?? '-';
    final startTime    = r['start_time']?.toString();
    final endTime      = r['end_time']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info card ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(r['customer_name']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textDark)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon(status), size: 13, color: color),
                      const SizedBox(width: 6),
                      Text(_statusLabel(status),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(r['customer_phone']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13, color: _textGrey)),

                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(child: _buildDetailItem(
                      icon: Icons.table_bar_outlined,
                      label: 'Meja', value: billiardName)),
                  Expanded(child: _buildDetailItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Paket', value: packageName)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildDetailItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Tanggal',
                      value: _formatDate(r['reservation_date']?.toString()))),
                  Expanded(child: _buildDetailItem(
                      icon: Icons.access_time_outlined,
                      label: 'Jam',
                      value: (startTime != null && endTime != null)
                          ? '$startTime – $endTime'
                          : '-')),
                ]),
                if (paymentStatus != null && paymentStatus.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      icon: Icons.payment_outlined,
                      label: 'Status Pembayaran',
                      value: paymentStatus),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Status info ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_statusIcon(status), size: 15, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (status) {
                    'menunggu_konfirmasi' =>
                      'Reservasi sedang menunggu konfirmasi dari admin.',
                    'dikonfirmasi' => hasActiveQr
                        ? 'Reservasi dikonfirmasi. QR pembayaran tersedia — tap tombol di bawah.'
                        : 'Reservasi dikonfirmasi. Lanjutkan ke pembayaran.',
                    'berhasil' =>
                      'Reservasi dan pembayaran telah berhasil. Selamat menikmati!',
                    'selesai' =>
                      'Reservasi telah selesai dilaksanakan. Terima kasih!',
                    'gagal' =>
                      'Reservasi ini telah dibatalkan atau ditolak oleh admin.',
                    _ => 'Status tidak diketahui.',
                  },
                  style: TextStyle(fontSize: 12, color: color, height: 1.5),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Tombol ──
          if (status == 'dikonfirmasi')
            _buildActionBtn(
              label: hasActiveQr ? 'Lihat QR & Bayar' : 'Bayar Sekarang',
              icon : Icons.qr_code_2_outlined,
              color: _primary,
              onTap: () => _openPayment(reservationId),
            ),

          if (canCancel) ...[
            const SizedBox(height: 10),
            _buildActionBtn(
              label   : 'Batalkan Reservasi',
              icon    : Icons.close,
              color   : _danger,
              outlined: true,
              onTap   : () => _cancelReservation(r),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String   label,
    required String   value,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: _textGrey),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textGrey)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }

  Widget _buildActionBtn({
    required String       label,
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon : Icon(icon, size: 16, color: color),
              label: Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              style: OutlinedButton.styleFrom(
                side : BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              icon : Icon(icon, size: 16),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation      : 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_today_outlined,
            size: 72, color: _textGrey.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('Belum ada reservasi',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: _textGrey)),
        const SizedBox(height: 6),
        const Text('Buat reservasi pertamamu di tab Reservasi',
            style: TextStyle(fontSize: 13, color: _textGrey)),
      ]),
    );
  }
}