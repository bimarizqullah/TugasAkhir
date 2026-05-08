import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/reservation_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/storage.dart';
import 'payment_screen.dart';

class HistoryScreen extends StatefulWidget {
  final Widget? bottomNavbar;
  const HistoryScreen({super.key, this.bottomNavbar});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _reservations = [];
  bool _isLoading    = true;
  int? _currentUserId;
  StreamSubscription? _wsSub;

  static const Color _primary  = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _bgColor  = Color(0xFFF8FAFC);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _success  = Color(0xFF16A34A);
  static const Color _warning  = Color(0xFFEA580C);
  static const Color _info     = Color(0xFF0284C7);

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

  // ── WebSocket listener ──────────────────────────────
  void _listenWebSocket() {
    _wsSub = WebSocketService.onReservationEvent.listen((data) {
      if (!mounted) return;

      final eventUserId = data['id_users'];
      if (_currentUserId != null &&
          eventUserId != null &&
          eventUserId.toString() != _currentUserId.toString()) return;

      final newStatus = data['reservation_status']?.toString() ?? '';

      // Notif ke user saat admin approve
      if (newStatus == 'dikonfirmasi') {
        _showApprovalNotif(data);
      }

      setState(() {
        _reservations.removeWhere(
            (r) => r['id']?.toString() == data['id']?.toString());
        _reservations.insert(0, data);
      });
    });
  }

  /// Tampilkan banner notifikasi + tombol bayar sekarang
  void _showApprovalNotif(Map<String, dynamic> data) {
    final reservationId = data['id'] as int?;
    if (reservationId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Reservasi dikonfirmasi! QR pembayaran sudah siap.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: _success,
        behavior       : SnackBarBehavior.floating,
        duration       : const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label    : 'Bayar',
          textColor: Colors.white,
          onPressed: () => _openPayment(reservationId),
        ),
      ),
    );
  }

  // ── Load reservasi ──────────────────────────────────
  Future<void> _loadReservations() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final userStr = await Storage.getUser();
      if (userStr != null) {
        final user = jsonDecode(userStr);
        _currentUserId =
            (user['id'] ?? user['id_users']) as int?;
      }

      final data = await ReservationService.getReservations();
      if (!mounted) return;

      data.sort((a, b) {
        final aDate = DateTime.tryParse(
                a['created_at']?.toString() ?? '') ??
            DateTime(0);
        final bDate = DateTime.tryParse(
                b['created_at']?.toString() ?? '') ??
            DateTime(0);
        return bDate.compareTo(aDate);
      });

      setState(() => _reservations = data);
    } catch (e) {
      debugPrint('❌ Load reservations error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Buka PaymentScreen ──────────────────────────────
  Future<void> _openPayment(int reservationId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          reservationId: reservationId,
          fromHistory  : true,
        ),
      ),
    );
    // Refresh list jika kembali dari payment (misal sudah berhasil)
    if (result == true && mounted) {
      await _loadReservations();
    }
  }

  // ── Cancel ───────────────────────────────────────────
  Future<void> _cancelReservation(dynamic r) async {
    final id   = r['id'] as int;
    final name = r['customer_name']?.toString() ?? 'reservasi ini';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Reservasi',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Yakin ingin membatalkan reservasi atas nama "$name"?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak',
                style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation      : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
          }
        });
        _showSnackBar('Reservasi berhasil dibatalkan', isError: false);
      } else {
        _showSnackBar(
            result['data']['message'] ?? 'Gagal membatalkan');
      }
    } catch (_) {
      _showSnackBar('Gagal terhubung ke server');
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
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
      backgroundColor    : _bgColor,
      bottomNavigationBar: widget.bottomNavbar,
      appBar: AppBar(
        backgroundColor          : Colors.transparent,
        elevation                : 0,
        automaticallyImplyLeading: false,
        title: const Text('Riwayat Reservasi',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon     : const Icon(Icons.refresh_outlined, color: _textDark),
            onPressed: _loadReservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : _reservations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReservations,
                  color    : _primary,
                  child    : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount  : _reservations.length,
                    itemBuilder: (ctx, i) =>
                        _buildCard(_reservations[i]),
                  ),
                ),
    );
  }

  // ── Card ─────────────────────────────────────────────
  Widget _buildCard(dynamic r) {
    final status = r['reservation_status']?.toString() ?? 'menunggu_konfirmasi';
    final hasActiveQr = r['has_active_qr'] == true;
    final paymentStatus = r['payment_status']?.toString();

    final statusColor = switch (status) {
      'berhasil'            => _success,
      'dikonfirmasi'        => _info,
      'menunggu_konfirmasi' => _warning,
      'pending'             => _warning,
      'gagal'               => _danger,
      _                     => _textGrey,
    };

    final statusLabel = switch (status) {
      'berhasil'            => 'Berhasil',
      'dikonfirmasi'        => 'Dikonfirmasi',
      'menunggu_konfirmasi' => 'Menunggu Konfirmasi',
      'pending'             => 'Menunggu',
      'gagal'               => 'Gagal / Ditolak',
      _                     => status,
    };

    final statusIcon = switch (status) {
      'berhasil'            => Icons.check_circle_outline,
      'dikonfirmasi'        => Icons.thumb_up_outlined,
      'menunggu_konfirmasi' => Icons.access_time_outlined,
      'gagal'               => Icons.cancel_outlined,
      _                     => Icons.help_outline,
    };

    // Format tanggal
    String formattedDate = '-';
    try {
      final raw = r['reservation_date']?.toString() ?? '';
      if (raw.isNotEmpty) {
        final dt = DateTime.parse(raw);
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei',
          'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        formattedDate = '${dt.day.toString().padLeft(2, '0')} '
            '${months[dt.month]} ${dt.year}';
      }
    } catch (_) {}

    final billiardName =
        r['billiard_name']?.toString().isNotEmpty == true
            ? r['billiard_name'].toString()
            : r['billiard']?['name']?.toString() ?? '-';

    final packageName =
        r['package_name']?.toString().isNotEmpty == true
            ? r['package_name'].toString()
            : r['package']?['package_name']?.toString() ?? '-';

    final startTime = r['start_time']?.toString();
    final endTime   = r['end_time']?.toString();

    final canCancel = status == 'menunggu_konfirmasi' ||
        status == 'dikonfirmasi' ||
        status == 'pending';

    final reservationId = r['id'] as int;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin  : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color       : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color     : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset    : const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(children: [
              Expanded(
                child: Text(
                  r['customer_name']?.toString() ?? '-',
                  style: const TextStyle(
                      fontSize  : 15,
                      fontWeight: FontWeight.bold,
                      color     : _textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color       : statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize  : 11,
                          fontWeight: FontWeight.w600,
                          color     : statusColor)),
                ]),
              ),
            ]),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // ── Info grid ──
            Row(children: [
              Expanded(child: _buildInfoItem(
                icon : Icons.table_bar_outlined,
                label: 'Meja',
                value: billiardName,
              )),
              Expanded(child: _buildInfoItem(
                icon : Icons.inventory_2_outlined,
                label: 'Paket',
                value: packageName,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildInfoItem(
                icon : Icons.calendar_today_outlined,
                label: 'Tanggal',
                value: formattedDate,
              )),
              Expanded(child: _buildInfoItem(
                icon : Icons.access_time_outlined,
                label: 'Jam',
                value: (startTime != null && endTime != null)
                    ? '$startTime – $endTime'
                    : '-',
              )),
            ]),

            // ── Status banner ──
            if (status == 'menunggu_konfirmasi') ...[
              const SizedBox(height: 12),
              _buildStatusBanner(
                color  : _warning,
                icon   : Icons.hourglass_top_outlined,
                message: 'Menunggu konfirmasi dari admin.',
              ),
            ],
            if (status == 'dikonfirmasi') ...[
              const SizedBox(height: 12),
              _buildStatusBanner(
                color  : _info,
                icon   : Icons.qr_code_2_outlined,
                message: hasActiveQr
                    ? 'Reservasi dikonfirmasi. QR pembayaran tersedia!'
                    : 'Reservasi dikonfirmasi. Tap "Bayar Sekarang" untuk lanjut.',
              ),
            ],
            if (status == 'berhasil') ...[
              const SizedBox(height: 12),
              _buildStatusBanner(
                color  : _success,
                icon   : Icons.check_circle_outline,
                message: 'Reservasi & pembayaran berhasil!',
              ),
            ],
            if (status == 'gagal') ...[
              const SizedBox(height: 12),
              _buildStatusBanner(
                color  : _danger,
                icon   : Icons.cancel_outlined,
                message: 'Reservasi dibatalkan atau ditolak.',
              ),
            ],

            // ── Payment status jika ada ──
            if (paymentStatus != null &&
                paymentStatus.isNotEmpty &&
                status != 'berhasil') ...[
              const SizedBox(height: 6),
              Text(
                'Status pembayaran: $paymentStatus',
                style: TextStyle(fontSize: 11, color: _textGrey),
              ),
            ],

            // ── Tombol ──
            if (status == 'dikonfirmasi') ...[
              const SizedBox(height: 12),
              SizedBox(
                width : double.infinity,
                height: 42,
                child : ElevatedButton.icon(
                  onPressed: () => _openPayment(reservationId),
                  icon : const Icon(Icons.qr_code_2, size: 18),
                  label: Text(
                    hasActiveQr ? 'Lihat QR & Bayar' : 'Bayar Sekarang',
                    style: const TextStyle(
                        fontSize  : 13,
                        fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation      : 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],

            if (canCancel) ...[
              const SizedBox(height: 8),
              SizedBox(
                width : double.infinity,
                height: 38,
                child : OutlinedButton.icon(
                  onPressed: () => _cancelReservation(r),
                  icon : const Icon(Icons.close, size: 15, color: _danger),
                  label: const Text('Batalkan Reservasi',
                      style: TextStyle(
                          fontSize  : 12,
                          fontWeight: FontWeight.w600,
                          color     : _danger)),
                  style: OutlinedButton.styleFrom(
                    side : BorderSide(
                        color: _danger.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ──────────────────────────────────
  Widget _buildStatusBanner({
    required Color    color,
    required IconData icon,
    required String   message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color       : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border      : Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  fontSize: 11, color: color, height: 1.3)),
        ),
      ]),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String   label,
    required String   value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: _textGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _textGrey)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                    fontSize  : 12,
                    fontWeight: FontWeight.w600,
                    color     : _textDark,
                  ),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_today_outlined,
            size : 72,
            color: _textGrey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('Belum ada reservasi',
            style: TextStyle(
                fontSize  : 17,
                fontWeight: FontWeight.w600,
                color     : _textGrey)),
        const SizedBox(height: 6),
        const Text('Buat reservasi pertamamu\ndi tab Reservasi',
            textAlign: TextAlign.center,
            style    : TextStyle(fontSize: 13, color: _textGrey)),
      ]),
    );
  }
}