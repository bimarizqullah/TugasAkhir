import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/websocket_service.dart';
import '../../services/table_service.dart';
import '../../services/reservation_service.dart';
import '../../widgets/queue_bottom_sheet.dart';

/// Versi Web dari HomeScreen.
/// Layout: konten penuh (tanpa BottomNavBar) karena sidebar sudah di MainShell.
/// Grid meja 2–3 kolom, stats card di atas, topbar dengan status koneksi.
class HomeWebScreen extends StatefulWidget {
  const HomeWebScreen({super.key});

  @override
  State<HomeWebScreen> createState() => _HomeWebScreenState();
}

class _HomeWebScreenState extends State<HomeWebScreen> {
  List<dynamic> _tables      = [];
  bool          _isLoading   = true;
  DateTime?     _lastUpdated;
  Timer?        _countdownTimer;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connSubscription;
  StreamSubscription? _reservationSub;
  final Set<int> _autoStoppedTables = {}; // Track tables that have been auto-stopped

  final Map<int, int> _queueCounts = {};

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _danger      = Color(0xFFDC2626);
  static const Color _warning     = Color(0xFFEA580C);
  static const Color _bgColor     = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    // 🔥 FIX: HAPUS _listenToWebsocket() — subscription diurus di _bootstrap()
    _bootstrap();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _wsSubscription?.cancel();
    _connSubscription?.cancel();
    _reservationSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadTablesWithSession();
    await WebSocketService.connect();

    // 🔥 FIX: Satu subscription saja — tidak ada duplikat
    _wsSubscription = WebSocketService.onTableEvent.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event.type) {
          case 'updated': _handleTableUpdate(event.data); break;
          case 'created': _handleTableAdd(event.data);    break;
          case 'deleted': _handleTableDelete(event.data); break;
        }
        _lastUpdated = DateTime.now();
      });
    });

    _connSubscription = WebSocketService.onConnectionChange.listen((connected) {
      if (connected && mounted) {
        _loadTablesWithSession(silent: true);
        _refreshAllQueueCounts();
      }
    });

    _reservationSub = WebSocketService.onReservationEvent.listen((_) {
      if (!mounted) return;
      _refreshAllQueueCounts();
    });
  }

  // 🔥 FIX: _listenToWebsocket() DIHAPUS — sudah digabung ke _bootstrap() di atas

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadTablesWithSession({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final data = await TableService.getTablesWithSession();
      if (!mounted) return;
      setState(() {
        _tables = data.map((table) {
          final t = Map<String, dynamic>.from(table as Map);
          t['session'] ??= {
            'customer_name': t['customer_name'] ?? '-',
            'session_mode' : t['session_mode']  ?? 'NORMAL',
            'start_time'   : t['start_time'],
            'end_time'     : t['end_time'],
          };
          return t;
        }).toList();
        _lastUpdated = DateTime.now();
      });
      await _refreshAllQueueCounts();
    } catch (e) {
      debugPrint('❌ Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAllQueueCounts() async {
    for (final table in _tables) {
      final id = table['id'];
      if (id == null) continue;
      _fetchQueueCount(int.tryParse(id.toString()) ?? 0);
    }
  }

  Future<void> _fetchQueueCount(int tableId) async {
    if (tableId == 0) return;
    try {
      final result = await ReservationService.fetchTableQueue(tableId);
      final count  = (result['total'] as int?) ?? 0;
      if (!mounted) return;
      setState(() => _queueCounts[tableId] = count);
    } catch (_) {}
  }

  void _handleTableUpdate(Map<String, dynamic> newTable) {
    final idx = _tables.indexWhere(
        (t) => t['id']?.toString() == newTable['id']?.toString());
    if (idx != -1) {
      final old = WebSocketService.safeCastMap(_tables[idx]);
      final newSession = Map<String, dynamic>.from(newTable['session'] ?? {});

      // 🔥 FIX: Jika session_status berubah (aktif ↔ tersedia), GANTI session sepenuhnya.
      // Jangan merge dengan session lama agar start_time/end_time yang obsolete tidak bertahan.
      final oldSessionStatus = old['session_status']?.toString() ?? '';
      final newSessionStatus = newTable['session_status']?.toString() ?? '';
      final sessionChanged   = oldSessionStatus != newSessionStatus;

      _tables[idx] = {
        ...old,
        ...newTable,
        'session': sessionChanged
            ? newSession  // Ganti total jika status berubah
            : {
                ...Map<String, dynamic>.from(old['session'] ?? {}),
                ...newSession,  // Merge jika status sama
              },
      };
    } else {
      _handleTableAdd(newTable);
    }
  }

  void _handleTableAdd(Map<String, dynamic> t) {
    t['session'] ??= {};
    final exists = _tables.any((x) => x['id']?.toString() == t['id']?.toString());
    if (!exists) _tables.insert(0, t);
  }

  void _handleTableDelete(Map<String, dynamic> data) {
    _tables.removeWhere((t) => t['id']?.toString() == data['id']?.toString());
  }

  int get _activeTables    => _tables.where((t) => t['session_status']?.toString() == 'aktif').length;
  int get _availableTables => _tables.length - _activeTables;

  String get _lastUpdatedText {
    if (_lastUpdated == null) return 'Connecting...';
    final diff = DateTime.now().difference(_lastUpdated!).inSeconds;
    if (diff < 3)  return '🔥 Live';
    if (diff < 60) return '${diff}s ago';
    return '${(diff / 60).floor()}m ago';
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
                : RefreshIndicator(
                    onRefresh: () => _loadTablesWithSession(),
                    color: _primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildStatsRow()),
                        SliverToBoxAdapter(child: _buildSectionHeader()),
                        _tables.isEmpty
                            ? SliverFillRemaining(child: _buildEmptyState())
                            : _buildTableGrid(),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────
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
              Text(
                'Informasi Meja',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              Text(
                'Monitor status meja secara real-time',
                style: TextStyle(fontSize: 13, color: _textGrey),
              ),
            ],
          ),
          const Spacer(),
          _buildConnectionStatus(),
          const SizedBox(width: 16),
          // Refresh button
          OutlinedButton.icon(
            onPressed: () => _loadTablesWithSession(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connection Status ────────────────────────────────
  Widget _buildConnectionStatus() {
    return StreamBuilder<bool>(
      stream: WebSocketService.onConnectionChange,
      initialData: WebSocketService.isConnected,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;
        final color     = connected ? _success : _danger;
        final label     = connected ? _lastUpdatedText : 'Disconnected';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(color: color),
            const SizedBox(width: 8),
            Icon(connected ? Icons.wifi : Icons.wifi_off,
                size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }

  // ── Stats Row ────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(
            label: 'Sedang Dipakai',
            value: '$_activeTables',
            icon : Icons.table_bar,
            color: _danger,
          )),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard(
            label: 'Tersedia',
            value: '$_availableTables',
            icon : Icons.event_available,
            color: _success,
          )),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard(
            label: 'Total Meja',
            value: '${_tables.length}',
            icon : Icons.grid_view_rounded,
            color: _primary,
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: _textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Header ───────────────────────────────────
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Row(
        children: [
          const Text(
            'Daftar Meja',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textDark),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_tables.length} meja',
              style: const TextStyle(
                  fontSize: 12,
                  color: _primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Table Grid ───────────────────────────────────────
  Widget _buildTableGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _buildTableCard(_tables[i]),
          childCount: _tables.length,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          // Tinggi tile: aktif lebih tinggi
          mainAxisExtent: 180,
        ),
      ),
    );
  }

  // ── Table Card (Web) ─────────────────────────────────
  Widget _buildTableCard(dynamic table) {
    final isActive    = (table['session_status']?.toString() ?? '') == 'aktif';
    final tableStatus = table['table_status']?.toString() ?? 'aktif';
    final isNonaktif  = tableStatus == 'nonaktif';
    final session     = WebSocketService.safeCastMap(table['session'] ?? {});
    final endTimeRaw  = session['end_time']?.toString()   ?? '';
    final startTimeRaw= session['start_time']?.toString() ?? '';
    final sessionMode = (session['session_mode']?.toString() ?? 'NORMAL').toLowerCase();
    final tableId     = int.tryParse(table['id']?.toString() ?? '0') ?? 0;
    final queueCount  = _queueCounts[tableId] ?? 0;

    return MouseRegion(
      cursor: isNonaktif
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isNonaktif
            ? null
            : () => QueueBottomSheet.show(
                  context,
                  tableId: tableId,
                  tableName: table['name']?.toString() ?? 'Meja',
                ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isNonaktif ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNonaktif
                  ? Colors.grey.shade200
                  : isActive
                      ? _danger.withOpacity(0.25)
                      : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isNonaktif ? 0.02 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Icon + Name + Badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNonaktif
                          ? Colors.grey.withOpacity(0.1)
                          : isActive
                              ? _danger.withOpacity(0.1)
                              : _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.table_bar,
                        size: 20,
                        color: isNonaktif
                            ? Colors.grey
                            : isActive ? _danger : _primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      table['name']?.toString() ?? 'Meja',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNonaktif ? Colors.grey : _textDark),
                    ),
                  ),
                  isNonaktif ? _buildNonaktifBadge() : _buildStatusBadge(isActive),
                ]),

                const SizedBox(height: 8),

                // Size + Queue badge
                Row(children: [
                  Icon(Icons.straighten, size: 13, color: _textGrey),
                  const SizedBox(width: 4),
                  Text('${table['size']?.toString() ?? '0'} ft',
                      style: TextStyle(
                          fontSize: 12,
                          color: isNonaktif
                              ? Colors.grey.shade400
                              : _textGrey)),
                  if (!isNonaktif && queueCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 11, color: _warning),
                          const SizedBox(width: 3),
                          Text('$queueCount antrian',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _warning,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ]),

                const Spacer(),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Session detail / nonaktif info
                if (isNonaktif)
                  Row(children: [
                    Icon(Icons.block, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Tidak tersedia / Dalam perbaikan',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ])
                else if (isActive)
                  Row(children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon : Icons.person_outline,
                        label: session['customer_name']?.toString() ?? '-',
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    sessionMode == 'manual'
                        ? _buildTimerUp(
                            startTimeRaw.isNotEmpty
                                ? DateTime.parse(startTimeRaw)
                                : DateTime.now())
                        : endTimeRaw.isNotEmpty
                            ? _buildTimerDown(DateTime.parse(endTimeRaw))
                            : _buildInfoChip(
                                icon : Icons.timer_off_outlined,
                                label: '-',
                                color: _textGrey),
                  ])
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 13, color: _textGrey.withOpacity(0.5)),
                      const SizedBox(width: 5),
                      Text(
                        'Klik untuk lihat antrian',
                        style: TextStyle(
                            fontSize: 11,
                            color: _textGrey.withOpacity(0.5)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerUp(DateTime startTime) {
    final elapsed = DateTime.now().difference(startTime);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    final display = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return _buildInfoChip(
        icon: Icons.timer_outlined, label: display, color: _primary);
  }

  Widget _buildTimerDown(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) {
      return _buildInfoChip(
          icon: Icons.check_circle_outline, label: 'Selesai', color: _success);
    }
    final m = remaining.inMinutes;
    final s = remaining.inSeconds.remainder(60);
    Color color = _success;
    if (m < 5) color = _warning;
    if (m < 2) color = _danger;

    return _buildInfoChip(
        icon: Icons.timer_outlined,
        label:
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        color: color);
  }

  Widget _buildStatusBadge(bool isActive) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? _danger.withOpacity(0.1)
              : _success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: isActive ? _danger : _success,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(isActive ? 'Dipakai' : 'Kosong',
              style: TextStyle(
                  color: isActive ? _danger : _success,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ]),
      );

  Widget _buildNonaktifBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block, size: 10, color: Colors.grey),
          SizedBox(width: 5),
          Text('Nonaktif',
              style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ]),
      );

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _buildEmptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_bar_outlined,
              size: 80, color: _textGrey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Belum ada meja',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textGrey)),
          const SizedBox(height: 8),
          Text(
            WebSocketService.isConnected
                ? '🔥 Menunggu update real-time...'
                : 'Klik Refresh untuk memuat ulang',
            style: const TextStyle(fontSize: 13, color: _textGrey),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════
//  Pulse dot widget (sama dengan mobile)
// ════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}