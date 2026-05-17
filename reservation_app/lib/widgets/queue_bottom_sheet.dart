import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/reservation_service.dart';
import '../services/websocket_service.dart';
import '../utils/storage.dart';

class QueueBottomSheet extends StatefulWidget {
  final int tableId;
  final String tableName;

  const QueueBottomSheet({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  static Future<void> show(
    BuildContext context, {
    required int tableId,
    required String tableName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QueueBottomSheet(tableId: tableId, tableName: tableName),
    );
  }

  @override
  State<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<QueueBottomSheet> {
  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _danger      = Color(0xFFDC2626);
  static const Color _warning     = Color(0xFFEA580C);

  List<dynamic> _queue = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final userJson = await Storage.getUser();
      if (userJson != null) {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUserId = int.tryParse(user['id']?.toString() ?? '');
      }
    } catch (_) {}

    await _loadQueue();

    _wsSub = WebSocketService.onReservationEvent.listen((event) {
      if (!mounted) return;
      _loadQueue(silent: true);
    });
  }

  Future<void> _loadQueue({bool silent = false}) async {
    if (!silent && mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final result = await ReservationService.fetchTableQueue(widget.tableId);
      if (!mounted) return;

      final raw = result['data'];
      final List<dynamic> queue = raw is List ? raw : [];
      if (raw is! List) debugPrint('⚠️ queue data bukan List: ${raw.runtimeType}');

      setState(() {
        _queue = queue;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('❌ _loadQueue error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelReservation(int reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Reservasi?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Reservasi yang dibatalkan tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Tidak', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ReservationService.cancelReservation(reservationId);
    if (!mounted) return;

    final ok = (result['status'] as int?) == 200;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reservasi berhasil dibatalkan'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _loadQueue(silent: true);
    } else {
      final msg = (result['data'] as Map?)?['message']?.toString()
          ?? 'Gagal membatalkan reservasi';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $msg'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildSheetHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildSheetHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.format_list_numbered, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antrian ${widget.tableName}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    _isLoading ? 'Memuat...' : '${_queue.length} antrian tersisa',
                    style: const TextStyle(fontSize: 13, color: _textGrey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadQueue,
              icon: const Icon(Icons.refresh, color: _primary),
              tooltip: 'Refresh',
            ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off, size: 48, color: _textGrey),
          const SizedBox(height: 12),
          const Text('Gagal memuat antrian',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(fontSize: 12, color: _textGrey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadQueue,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );
    }

    if (_queue.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_available, size: 72, color: _textGrey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Tidak ada antrian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textGrey)),
          const SizedBox(height: 6),
          const Text('Meja ini belum memiliki reservasi aktif.',
              style: TextStyle(fontSize: 13, color: _textGrey)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _queue.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _buildQueueCard(_queue[i], i),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  QUEUE CARD
  // ════════════════════════════════════════════════════
  Widget _buildQueueCard(dynamic item, int index) {
    final isFirst     = index == 0;
    final isMine      = item['id_users']?.toString() == _currentUserId?.toString();
    final status      = item['reservation_status']?.toString() ?? '';
    final queueNum    = item['queue_number'] ?? (index + 1);
    final name        = item['customer_name']?.toString() ?? '-';
    final date        = _formatDate(item['reservation_date']?.toString() ?? '');
    // 🔥 FIX: null atau '00:00' = data lama tanpa jam
    final rawStart  = item['start_time']?.toString() ?? '';
    final rawEnd    = item['end_time']?.toString()   ?? '';
    final hasTime   = rawStart.isNotEmpty && rawStart != 'null' && !rawStart.startsWith('00:00');
    final startTime = hasTime ? rawStart : null;
    final endTime   = hasTime ? rawEnd   : null;
    final timeLabel = hasTime ? '$startTime – $endTime' : 'Jam belum diatur';
    final packageName = item['package_name']?.toString() ?? 'Tanpa Paket';
    final reservId    = item['id'] as int?;

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final accentColor = isFirst ? _danger : isMine ? _primary : Colors.transparent;

    return Stack(
      children: [
        // ── Card utama ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: nomor + nama + status
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? _danger.withOpacity(0.1)
                            : _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$queueNum',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isFirst ? _danger : _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Kamu',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            packageName,
                            style: const TextStyle(fontSize: 12, color: _textGrey),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(statusLabel, statusColor),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Row 2: tanggal & jam
                Row(
                  children: [
                    _buildInfoItem(Icons.calendar_today_outlined, date, _primary),
                    const SizedBox(width: 12),
                    _buildInfoItem(
                      Icons.access_time_outlined,
                      timeLabel,
                      hasTime ? _warning : _textGrey,
                    ),
                  ],
                ),

                // Antrian hanya berisi reservasi yang sudah lunas (berhasil + settlement)
                // sehingga tombol batalkan tidak ditampilkan di sini


                // Label "Giliran Berikutnya"
                if (isFirst) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_outline, size: 14, color: _danger),
                        SizedBox(width: 6),
                        Text(
                          'Giliran Berikutnya',
                          style: TextStyle(
                            color: _danger,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Accent bar kiri ──
        if (accentColor != Colors.transparent)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════
  Widget _buildStatusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );

  Widget _buildInfoItem(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      );

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'berhasil': return _success;
      default:         return _textGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'berhasil': return 'Lunas';
      default:         return status;
    }
  }
}