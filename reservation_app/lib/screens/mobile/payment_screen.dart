import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Import kondisional: Hanya gunakan webview_flutter jika dijalankan di Mobile (Android/iOS)
// Untuk platform Web, kita akan menggunakan penampil berbasis elemen HTML atau deskripsi instruksi.
import 'package:webview_flutter/webview_flutter.dart' as mobile_wv;

import '../../services/reservation_service.dart';

class PaymentScreen extends StatefulWidget {
  final int reservationId;
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

  // State Kontrol
  bool _isLoading = true;
  bool _isPaid = false;
  bool _isExpired = false;
  bool _isWaiting = false;
  String _errorMsg = '';

  // Data Pembayaran dari Server
  String? _redirectUrl; 
  String? _backendRedirectUrl;
  String? _backendFallbackUrl;
  String? _backendToken;
  int _amount = 0;
  String _orderId = '';

  // Controller dan Timer
  Timer? _statusTimer;
  dynamic _webViewController; // Menggunakan dynamic agar aman dari cross-platform type checking

  @override
  void initState() {
    super.initState();
    _loadPaymentUrl();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaymentUrl() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _isWaiting = false;
      _isPaid = false;
      _isExpired = false;
    });

    try {
      final res = await ReservationService.initiatePayment(widget.reservationId);

      _backendRedirectUrl = res['redirect_url'] as String?;
      _backendFallbackUrl = res['payment_qr_url'] as String?;
      _backendToken = res['token']?.toString();
      _redirectUrl = _backendRedirectUrl ?? _backendFallbackUrl;
      final isSandbox = res['is_sandbox'] == true || res['is_sandbox']?.toString() == 'true';

      if ((_redirectUrl == null || _redirectUrl!.isEmpty) && _backendToken != null && _backendToken!.isNotEmpty) {
        _redirectUrl = isSandbox
            ? 'https://app.sandbox.midtrans.com/snap/v2/vtweb/${_backendToken!}'
            : 'https://app.midtrans.com/snap/v2/vtweb/${_backendToken!}';
      }

      _amount = res['amount'] ?? 0;
      _orderId = res['order_id'] ?? '';

      if (_redirectUrl == null || _redirectUrl!.isEmpty) {
        throw Exception(
          'Gagal mendapatkan URL pembayaran dari server. ' 
          'backend returned redirect_url=${_backendRedirectUrl ?? '<null>'}, ' 
          'payment_qr_url=${_backendFallbackUrl ?? '<null>'}, ' 
          'token=${_backendToken ?? '<null>'}'
        );
      }

      // Inisialisasi WebViewController hanya jika berjalan di Mobile asli (bukan di platform Web)
      if (!kIsWeb) {
        _webViewController = mobile_wv.WebViewController()
          ..setJavaScriptMode(mobile_wv.JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            mobile_wv.NavigationDelegate(
              onWebResourceError: (mobile_wv.WebResourceError error) {
                debugPrint("WebView Error: ${error.description}");
              },
            ),
          )
          ..loadRequest(Uri.parse(_redirectUrl!));
      }

      _startStatusPolling();
    } on ReservationNotApprovedYet {
      _isWaiting = true;
    } on ReservationAlreadyPaid {
      _isPaid = true;
    } catch (e) {
      _errorMsg = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final statusRes = await ReservationService.checkPaymentStatus(widget.reservationId);
        final status = statusRes['payment_status'] ?? 'pending';

        if (status == 'berhasil' || status == 'settlement') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isPaid = true;
            });
          }
        } else if (status == 'gagal' || status == 'expire') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isExpired = true;
            });
          }
        }
      } catch (e) {
        debugPrint('Gagal sinkronisasi pooling status: $e');
      }
    });
  }

  Future<void> _openPaymentInBrowser() async {
    if (_redirectUrl == null || _redirectUrl!.isEmpty) return;
    final uri = Uri.parse(_redirectUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Pembayaran Transaksi', 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
        ),
        centerTitle: true,
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primary)),
      );
    }
    
    if (_isWaiting) {
      return _buildStateView(
        Icons.hourglass_empty, 
        _warning, 
        'Menunggu Persetujuan', 
        'Pemesanan Anda belum disetujui oleh admin. Silakan cek riwayat Anda secara berkala.'
      );
    }
    
    if (_isPaid) {
      return _buildStateView(
        Icons.check_circle_outline, 
        _success, 
        'Pembayaran Berhasil', 
        'Terima kasih, pembayaran terverifikasi. Silakan menuju meja billiard sesuai pesanan Anda.', 
        sukses: true
      );
    }
    
    if (_isExpired) {
      return _buildStateView(
        Icons.cancel_outlined, 
        _danger, 
        'Batas Waktu Habis', 
        'Waktu transaksi pembayaran ini telah kedaluwarsa.'
      );
    }
    
    if (_errorMsg.isNotEmpty) {
      return _buildErrorView();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ID: $_orderId', style: const TextStyle(fontSize: 11, color: _textGrey)),
                  const SizedBox(height: 2),
                  const Text('Total Tagihan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark)),
                ],
              ),
              Text(
                'Rp ${_amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _warning),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: kIsWeb
              ? _buildWebPaymentPlaceholder()
              : (_webViewController != null
                  ? mobile_wv.WebViewWidget(controller: _webViewController as mobile_wv.WebViewController)
                  : _buildOpenExternalButton()),
        ),
      ],
    );
  }

  Widget _buildOpenExternalButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 48, color: _primary),
            const SizedBox(height: 16),
            const Text(
              'Buka Pembayaran Midtrans',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jika WebView tidak tersedia, Anda dapat membuka halaman pembayaran di browser eksternal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _openPaymentInBrowser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Buka di Browser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tampilan penampung khusus saat sistem di-build di platform Web (Menghindari error plugin)
  Widget _buildWebPaymentPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new, size: 48, color: _primary),
                const SizedBox(height: 16),
                const Text(
                  'Selesaikan Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sistem Midtrans Snap eksternal mendeteksi Anda membuka aplikasi melalui browser web.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _openPaymentInBrowser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Buka di Tab Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateView(IconData icon, Color color, String title, String desc, {bool sukses = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 8),
            Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _textGrey, height: 1.4)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.fromHistory || sukses) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Kembali ke Riwayat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            const Icon(Icons.error_outline, size: 64, color: _danger),
            const SizedBox(height: 12),
            const Text('Gagal Memuat Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 6),
            Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _textGrey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPaymentUrl,
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
              child: const Text('Ulangi Proses'),
            ),
          ],
        ),
      ),
    );
  }
}