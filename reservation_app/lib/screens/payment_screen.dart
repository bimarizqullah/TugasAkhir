import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/reservation_service.dart';

/// PaymentScreen
///
/// Bisa dibuka dari 2 tempat:
/// 1. Setelah admin approve → via WebSocket event di HistoryScreen
/// 2. Tap tombol "Lihat QR" di card riwayat
///
/// Parameter [reservationId] wajib.
/// Parameter [fromHistory] = true jika dibuka dari riwayat (tidak redirect setelah sukses).
class PaymentScreen extends StatefulWidget {
  final int  reservationId;
  final bool fromHistory;

  const PaymentScreen({
    super.key,
    required this.reservationId,
    this.fromHistory = false,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color _primary  = Color(0xFF2563EB);
  static const Color _success  = Color(0xFF16A34A);
  static const Color _warning  = Color(0xFFEA580C);
  static const Color _danger   = Color(0xFFDC2626);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textGrey = Color(0xFF64748B);
  static const Color _bgColor  = Color(0xFFF8FAFC);

  // State
  bool   _isLoading   = true;
  bool   _isPaid      = false;
  bool   _isExpired   = false;
  bool   _isWaiting   = false; // belum dikonfirmasi admin
  String _errorMsg    = '';

  String? _qrString;
  String? _orderId;
  int?    _amount;
  DateTime? _expiredAt;

  Timer? _pollingTimer;
  Timer? _countdownTimer;
  int    _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Load QR ─────────────────────────────────────────
  Future<void> _loadQr() async {
    setState(() { _isLoading = true; _errorMsg = ''; });
    try {
      final data = await ReservationService.initiatePayment(
          widget.reservationId);

      if (!mounted) return;

      final expiredAt = data['expired_at'] != null
          ? DateTime.parse(data['expired_at']).toLocal()
          : null;

      setState(() {
        _qrString  = data['qr_string']  as String?;
        _orderId   = data['order_id']   as String?;
        _amount    = data['amount']     as int?;
        _expiredAt = expiredAt;
        _isLoading = false;
      });

      if (expiredAt != null) {
        _startCountdown(expiredAt);
      }
      _startPolling();
    } on ReservationNotApprovedYet {
      setState(() {
        _isLoading = false;
        _isWaiting = true;
      });
    } on ReservationAlreadyPaid {
      setState(() { _isLoading = false; _isPaid = true; });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg  = e.toString();
      });
    }
  }

  // ── Countdown ────────────────────────────────────────
  void _startCountdown(DateTime expiredAt) {
    _countdownTimer?.cancel();
    _remainingSeconds = expiredAt.difference(DateTime.now()).inSeconds;
    if (_remainingSeconds <= 0) {
      setState(() => _isExpired = true);
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        setState(() => _isExpired = true);
        _pollingTimer?.cancel();
      }
    });
  }

  // ── Polling status ───────────────────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final status = await ReservationService.checkPaymentStatus(
            widget.reservationId);
        final reservationStatus = status['reservation_status'] as String?;
        final paymentStatus     = status['payment_status']     as String?;

        if (reservationStatus == 'berhasil' ||
            paymentStatus == 'settlement') {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
          if (mounted) setState(() => _isPaid = true);
        } else if (reservationStatus == 'gagal' ||
            paymentStatus == 'expire' ||
            paymentStatus == 'cancel') {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
          if (mounted) setState(() => _isExpired = true);
        }
      } catch (_) {
        // Abaikan error polling
      }
    });
  }

  String _formatCountdown() {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer('Rp');
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor          : Colors.transparent,
        elevation                : 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon     : const Icon(Icons.arrow_back, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pembayaran QRIS',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _isPaid
              ? _buildSuccessView()
              : _isWaiting
                  ? _buildWaitingView()
                  : _isExpired
                      ? _buildExpiredView()
                      : _errorMsg.isNotEmpty
                          ? _buildErrorView()
                          : _buildQrView(),
    );
  }

  // ── QR View ──────────────────────────────────────────
  Widget _buildQrView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Nominal
        if (_amount != null) ...[
          Container(
            width      : double.infinity,
            padding    : const EdgeInsets.all(16),
            decoration : BoxDecoration(
              color       : _primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Text('Total Pembayaran',
                  style:
                      TextStyle(fontSize: 12, color: _textGrey)),
              const SizedBox(height: 4),
              Text(
                _formatRupiah(_amount!),
                style: const TextStyle(
                    fontSize  : 24,
                    fontWeight: FontWeight.bold,
                    color     : _primary),
              ),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        // QR Code
        if (_qrString != null) ...[
          Container(
            padding   : const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color       : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow   : [
                BoxShadow(
                  color     : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset    : const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data           : _qrString!,
              version        : QrVersions.auto,
              size           : 240,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Countdown
          if (!_isExpired && _remainingSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60
                    ? _danger.withValues(alpha: 0.08)
                    : _warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size : 16,
                      color: _remainingSeconds < 60 ? _danger : _warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kadaluarsa dalam ${_formatCountdown()}',
                      style: TextStyle(
                        fontSize  : 13,
                        fontWeight: FontWeight.w600,
                        color     : _remainingSeconds < 60
                            ? _danger
                            : _warning,
                      ),
                    ),
                  ]),
            ),
        ],

        const SizedBox(height: 20),

        // Instruksi
        _buildInstruction(),

        const SizedBox(height: 16),

        // Order ID
        if (_orderId != null)
          Text(
            'Order ID: $_orderId',
            style: TextStyle(fontSize: 11, color: _textGrey),
          ),
      ]),
    );
  }

  Widget _buildInstruction() {
    return Container(
      padding   : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cara Pembayaran:',
              style: TextStyle(
                  fontSize  : 13,
                  fontWeight: FontWeight.bold,
                  color     : _textDark)),
          const SizedBox(height: 10),
          ...[
            'Buka aplikasi m-banking atau e-wallet kamu',
            'Pilih menu Scan QR / QRIS',
            'Scan kode QR di atas',
            'Konfirmasi pembayaran',
            'Halaman ini akan otomatis terupdate',
          ].asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width : 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color : _primary,
                        shape : BoxShape.circle,
                      ),
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                            fontSize: 10,
                            color   : Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              fontSize: 12, color: _textDark)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Success View ─────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding   : const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline,
                size: 72, color: _success),
          ),
          const SizedBox(height: 24),
          const Text('Pembayaran Berhasil!',
              style: TextStyle(
                  fontSize  : 22,
                  fontWeight: FontWeight.bold,
                  color     : _textDark)),
          const SizedBox(height: 8),
          Text('Reservasi kamu sudah dikonfirmasi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textGrey)),
          const SizedBox(height: 32),
          SizedBox(
            width : double.infinity,
            height: 50,
            child : ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _success,
                foregroundColor: Colors.white,
                elevation      : 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Selesai',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Waiting View (belum approve) ─────────────────────
  Widget _buildWaitingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding   : const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hourglass_top_outlined,
                size: 72, color: _warning),
          ),
          const SizedBox(height: 24),
          const Text('Menunggu Konfirmasi',
              style: TextStyle(
                  fontSize  : 22,
                  fontWeight: FontWeight.bold,
                  color     : _textDark)),
          const SizedBox(height: 8),
          Text(
            'Reservasimu sedang menunggu persetujuan admin.\n'
            'QR pembayaran akan muncul otomatis setelah dikonfirmasi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textGrey, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width : double.infinity,
            height: 50,
            child : OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side : const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kembali ke Riwayat',
                  style: TextStyle(color: _primary, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Expired View ─────────────────────────────────────
  Widget _buildExpiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding   : const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_off_outlined,
                size: 72, color: _danger),
          ),
          const SizedBox(height: 24),
          const Text('QR Kadaluarsa',
              style: TextStyle(
                  fontSize  : 22,
                  fontWeight: FontWeight.bold,
                  color     : _textDark)),
          const SizedBox(height: 8),
          Text('Waktu pembayaran habis.\nSilakan hubungi admin untuk generate QR baru.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textGrey, height: 1.5)),
          const SizedBox(height: 32),
          SizedBox(
            width : double.infinity,
            height: 50,
            child : OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side : const BorderSide(color: _danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kembali',
                  style: TextStyle(color: _danger, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Error View ───────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 72,
              color: _danger.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          const Text('Terjadi Kesalahan',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
          const SizedBox(height: 8),
          Text(_errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textGrey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadQr,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation      : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Coba Lagi'),
          ),
        ]),
      ),
    );
  }
}