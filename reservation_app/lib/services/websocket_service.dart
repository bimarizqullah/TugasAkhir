import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';

class TableEvent {
  final String type; // 'updated' | 'created' | 'deleted'
  final Map<String, dynamic> data;
  TableEvent({required this.type, required this.data});
}

class WebSocketService {
  static WebSocketChannel? _channel;
  static Timer? _pingTimer;
  static Timer? _reconnectTimer;
  static bool _intentionalDisconnect = false;
  static int _reconnectAttempts = 0;
  static bool _isConnected = false;

  static final StreamController<Map<String, dynamic>> _reservationController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onReservationEvent =>
      _reservationController.stream;

  static final StreamController<TableEvent> _tableController =
      StreamController<TableEvent>.broadcast();

  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  static Stream<TableEvent> get onTableEvent => _tableController.stream;
  static Stream<bool> get onConnectionChange => _connectionController.stream;
  static bool get isConnected => _isConnected;

  static Future<void> connect({bool isRetry = false}) async {
    if (_isConnected && !isRetry) return;

    _intentionalDisconnect = false;
    
    // PERBAIKAN: Menggunakan host dari AppConfig tanpa port hardcoded :443
    final host = AppConfig.wsHost; 
    final wsUrl = 'wss://$host/app/${AppConfig.wsAppKey}?protocol=7&client=flutter&version=1.0&flash=false';

    print('🔌 Connecting Reverb: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (err) => _onError(err),
        onDone: () => _onDone(),
      );

      // Kirim pesan subscribe awal jika diperlukan
      _subscribeToChannel('tables');
      _subscribeToChannel('reservations');
      
      _setConnected(true);
      _reconnectAttempts = 0;
      _startPing();
    } catch (e) {
      print('❌ Connection error: $e');
      _onError(e);
    }
  }

  static void _handleMessage(dynamic message) {
    final raw = message.toString();
    // 🔥 DEBUG: uncomment baris ini saat troubleshoot untuk lihat event apa yang masuk
    // print('📨 RAW WS: $raw');

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw);
    } catch (e) {
      print('❌ Failed to parse WS message: $e');
      return;
    }

    final event = data['event']?.toString() ?? '';

    // Data bisa berupa String (Pusher protocol) atau Map langsung
    dynamic rawPayload = data['data'];
    Map<String, dynamic> payload = {};
    if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(rawPayload));
      } catch (_) {
        payload = {};
      }
    } else if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    }

    // 🔥 FIX: Reverb/Pusher bisa mengirim event dengan atau tanpa titik di depan.
    // broadcastAs() = 'table.updated' → Reverb kirim sebagai '.table.updated' atau 'table.updated'
    // Normalize: strip leading dot untuk perbandingan
    final normalizedEvent = event.startsWith('.') ? event.substring(1) : event;

    if (event == 'pusher:connection_established') {
      print('✅ WS Connected');
      _setConnected(true);
    } else if (normalizedEvent == 'table.updated') {
      print('📥 Table Update Received — id: ${payload['id']}, status: ${payload['session_status']}');
      _tableController.add(TableEvent(type: 'updated', data: payload));
    } else if (normalizedEvent == 'App\\Events\\ReservationCreated' ||
               normalizedEvent == 'reservation.created') {
      _reservationController.add(payload);
    } else if (normalizedEvent == 'App\\Events\\ReservationUpdated' ||
               normalizedEvent == 'reservation.updated') {
      // 🔥 FIX: teruskan event update reservasi ke HistoryScreen
      _reservationController.add(payload);
    } else if (event == 'pusher:pong') {
      // Ignore pong silently
    } else {
      print('ℹ️ Unhandled WS event: "$event"');
    }
  }

  static void _setConnected(bool status) {
    _isConnected = status;
    _connectionController.add(status);
  }

  static void _subscribeToChannel(String channelName) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    });
    print('📡 Subscribed to: $channelName');
  }

  static void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      print('❌ Send error: $e');
    }
  }

  static void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  static void _onError(dynamic error) {
    print('❌ WS Error: $error');
    _setConnected(false);
    _scheduleReconnect();
  }

  static void _onDone() {
    print('🔌 WS Connection Closed');
    _setConnected(false);
    if (!_intentionalDisconnect) _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 30));
    print('🔄 Reconnecting #$_reconnectAttempts in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => connect(isRetry: true));
  }

  static Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _setConnected(false);
  }

  static Map<String, dynamic> safeCastMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}