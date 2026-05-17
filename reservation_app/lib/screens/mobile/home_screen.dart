import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/websocket_service.dart';
import '../../services/table_service.dart';
import '../../services/reservation_service.dart';
import '../../widgets/queue_bottom_sheet.dart'; 
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Widget? bottomNavbar;
  const HomeScreen({super.key, this.bottomNavbar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _tables = [];
  bool _isLoading = true;
  DateTime? _lastUpdated;
  Timer? _countdownTimer;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _connSubscription;
  StreamSubscription? _reservationSub;

  final Map<int, int> _queueCounts = {};

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textGrey    = Color(0xFF64748B);
  static const Color _success     = Color(0xFF16A34A);
  static const Color _danger      = Color(0xFFDC2626);
  static const Color _warning     = Color(0xFFEA580C);
  static const Color _bgColor     = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
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

    _reservationSub = WebSocketService.onReservationEvent.listen((event) {
      if (!mounted) return;
      _refreshAllQueueCounts();
    });
  }

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
            'customer_name' : t['customer_name'] ?? '-',
            'session_mode'  : t['session_mode']  ?? 'NORMAL',
            'start_time'    : t['start_time'],
            'end_time'      : t['end_time'],
          };
          return t;
        }).toList();
        _lastUpdated = DateTime.now();
      });

      await _refreshAllQueueCounts();
    } catch (e) {
      print('❌ Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTables({bool silent = false}) =>
      _loadTablesWithSession(silent: silent);

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
      final count = (result['total'] as int?) ?? 0;
      if (!mounted) return;
      setState(() => _queueCounts[tableId] = count);
    } catch (_) {
    }
  }

  void _handleTableUpdate(Map<String, dynamic> newTable) {
    final idx = _tables.indexWhere(
        (t) => t['id']?.toString() == newTable['id']?.toString());
    if (idx != -1) {
      final old = WebSocketService.safeCastMap(_tables[idx]);
      final newSession = Map<String, dynamic>.from(newTable['session'] ?? {});

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

  void _handleTableAdd(Map<String, dynamic> newTable) {
    newTable['session'] ??= {};
    final exists = _tables.any(
        (t) => t['id']?.toString() == newTable['id']?.toString());
    if (!exists) _tables.insert(0, newTable);
  }

  void _handleTableDelete(Map<String, dynamic> data) {
    _tables.removeWhere(
        (t) => t['id']?.toString() == data['id']?.toString());
  }

  int get _activeTables => _tables
      .where((t) => (t['session_status']?.toString() ?? '') == 'aktif')
      .length;
  int get _availableTables => _tables.length - _activeTables;

  String get _lastUpdatedText {
    if (_lastUpdated == null) return 'Connecting...';
    final diff = DateTime.now().difference(_lastUpdated!).inSeconds;
    if (diff < 3)  return '🔥 Live';
    if (diff < 60) return '${diff}s ago';
    return '${(diff / 60).floor()}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      bottomNavigationBar: widget.bottomNavbar,
      body: RefreshIndicator(
        onRefresh: () => _loadTables(),
        color: _primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  _tables.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 6),
                              child: _buildTableCard(_tables[i]),
                            ),
                            childCount: _tables.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        title: const Text(
          'Informasi Meja',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF1E293B)),
        ),
        elevation: 0,
      );

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(child: _buildConnectionStatus()),
          const SizedBox(height: 20),
          _buildStatsCard(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daftar Meja',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
                GestureDetector(
                  onTap: _loadTables,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 16, color: _primary),
                        SizedBox(width: 4),
                        Text('Refresh',
                            style: TextStyle(
                                color: _primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildConnectionStatus() => StreamBuilder<bool>(
        stream: WebSocketService.onConnectionChange,
        initialData: WebSocketService.isConnected,
        builder: (context, snapshot) {
          final connected = snapshot.data ?? false;
          final color     = connected ? _success : _danger;
          final label     = connected ? _lastUpdatedText : 'Disconnected';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildStatsCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(children: [
              Text('$_activeTables',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _danger)),
              const SizedBox(height: 4),
              const Text('Sedang Dipakai',
                  style: TextStyle(
                      fontSize: 13,
                      color: _textGrey,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
          Expanded(
            child: Column(children: [
              Text('$_availableTables',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _success)),
              const SizedBox(height: 4),
              const Text('Tersedia',
                  style: TextStyle(
                      fontSize: 13,
                      color: _textGrey,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      );

  Widget _buildTableCard(dynamic table) {
    final isActive      = (table['session_status']?.toString() ?? '') == 'aktif';
    final tableStatus   = table['table_status']?.toString() ?? 'aktif';
    final isNonaktif    = tableStatus == 'nonaktif';
    final session       = WebSocketService.safeCastMap(table['session'] ?? {});
    final endTimeRaw    = session['end_time']?.toString() ?? '';
    final startTimeRaw  = session['start_time']?.toString() ?? '';
    final sessionMode   = (session['session_mode']?.toString() ?? 'NORMAL').toLowerCase();
    final tableId       = int.tryParse(table['id']?.toString() ?? '0') ?? 0;
    final queueCount    = _queueCounts[tableId] ?? 0;

    return GestureDetector(
      onTap: isNonaktif
          ? null 
          : () => QueueBottomSheet.show(
                context,
                tableId: tableId,
                tableName: table['name']?.toString() ?? 'Meja',
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isNonaktif ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isNonaktif ? 0.02 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
          border: Border.all(
              color: isNonaktif
                  ? Colors.grey.shade300
                  : isActive
                      ? _danger.withOpacity(0.25)
                      : Colors.grey.shade200,
              width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNonaktif
                      ? Colors.grey.withOpacity(0.1)
                      : isActive
                          ? _danger.withOpacity(0.1)
                          : _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.table_bar,
                  color: isNonaktif
                      ? Colors.grey
                      : isActive ? _danger : _primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table['name']?.toString() ?? 'Meja',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isNonaktif
                              ? Colors.grey
                              : const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(
                        'Ukuran: ${table['size']?.toString() ?? '0'} ft',
                        style: TextStyle(
                            fontSize: 13,
                            color: isNonaktif
                                ? Colors.grey.shade400
                                : _textGrey),
                      ),
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
                              Text(
                                '$queueCount antrian',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _warning,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  isNonaktif
                      ? _buildNonaktifBadge()
                      : _buildStatusBadge(isActive),
                  if (!isNonaktif) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.format_list_numbered,
                          size: 11, color: _textGrey),
                      const SizedBox(width: 3),
                      Text('Lihat antrian',
                          style: TextStyle(
                              fontSize: 10,
                              color: _textGrey.withOpacity(0.7))),
                    ]),
                  ],
                ],
              ),
            ]),
            if (isActive && !isNonaktif) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _buildInfoChip(
                    icon : Icons.person_outline,
                    label: session['customer_name']?.toString() ?? '-',
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    icon : Icons.category_outlined,
                    label: sessionMode == 'manual' ? 'MANUAL' : 'PAKET',
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: sessionMode == 'manual'
                      ? _buildTimerUp(
                          startTimeRaw.isNotEmpty
                              ? DateTime.parse(startTimeRaw)
                              : DateTime.now(),
                        )
                      : endTimeRaw.isNotEmpty
                          ? _buildTimerDown(DateTime.parse(endTimeRaw))
                          : _buildInfoChip(
                              icon : Icons.timer_off_outlined,
                              label: '-',
                              color: _textGrey,
                            ),
                ),
              ]),
            ],

            if (isNonaktif) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'Meja tidak tersedia / Sedang dalam perbaikan',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ]),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, size: 14, color: _primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(display,
              style: const TextStyle(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildTimerDown(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());

    if (remaining.isNegative) {
      return _buildInfoChip(
          icon: Icons.check_circle_outline,
          label: 'Selesai',
          color: _success);
    }

    final m = remaining.inMinutes;
    final s = remaining.inSeconds.remainder(60);
    Color color = _success;
    if (m < 5) color = _warning;
    if (m < 2) color = _danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatusBadge(bool isActive) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          const SizedBox(width: 6),
          Text(isActive ? 'Dipakai' : 'Kosong',
              style: TextStyle(
                  color: isActive ? _danger : _success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
      );

  Widget _buildNonaktifBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Nonaktif',
              style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
      );

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _buildEmptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_bar_outlined,
              size: 80, color: _textGrey.withOpacity(0.35)),
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
                : 'Tarik ke bawah untuk refresh',
            style: const TextStyle(fontSize: 13, color: _textGrey),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}