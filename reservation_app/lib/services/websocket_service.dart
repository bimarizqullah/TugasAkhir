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
  static bool _isConnected = false; // 🔥 Track manual

  static final StreamController<Map<String, dynamic>> _reservationController =
    StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onReservationEvent =>
    _reservationController.stream;
  static final StreamController<TableEvent> _tableController =
      StreamController<TableEvent>.broadcast();

  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast(); // 🔥 Stream status koneksi

  static Stream<TableEvent> get onTableEvent => _tableController.stream;
  static Stream<bool> get onConnectionChange => _connectionController.stream;
  static Stream<Map<String, dynamic>> get onTableUpdate =>
      onTableEvent.map((e) => e.data);
  static bool get isConnected => _isConnected;

  static Future<bool> connectFuture() async => _isConnected;

  static Map<String, dynamic> safeCastMap(dynamic data) {
    if (data == null) return {};
    try {
      if (data is Map<String, dynamic>) return data;
      if (data is Map) {
        return Map<String, dynamic>.from(
            data.map((k, v) => MapEntry(k.toString(), v)));
      }
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) return safeCastMap(decoded);
      }
    } catch (e) {
      print('❌ SafeCast error: $e');
    }
    return {};
  }

  static Future<void> connect({bool isRetry = false}) async {
    if (!isRetry) {
      _intentionalDisconnect = false;
      _reconnectAttempts = 0;
    }

    await disconnect(intentional: false);

    final token = await Storage.getToken();
    if (token == null) {
      print('❌ No token, skip WS connect');
      return;
    }

    // 🔥 REVERB URL — bukan socket.io!
    final wsUrl =
        'ws://${AppConfig.wsHost}:${AppConfig.wsPort}/app/${AppConfig.wsAppKey}'
        '?protocol=7&client=flutter&version=1.0&flash=false';

    print('🔌 Connecting Reverb: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _startPing();
    } catch (e) {
      print('❌ Connect failed: $e');
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  static void _setConnected(bool value) {
    _isConnected = value;
    _connectionController.add(value);
    print(value ? '✅ WS Connected' : '❌ WS Disconnected');
  }

  static void _onMessage(dynamic rawData) {
    try {
      print('📨 RAW WS DATA: $rawData'); // sudah ada
      final message = safeCastMap(jsonDecode(rawData));
      final event = message['event']?.toString() ?? '';
      
      // data bisa berupa String JSON atau Map langsung
      final rawEventData = message['data'];
      final data = rawEventData is String 
          ? safeCastMap(jsonDecode(rawEventData)) 
          : safeCastMap(rawEventData);

      print('📨 Reverb [$event] data: ${jsonEncode(data)}');

      switch (event) {
        case 'pusher:connection_established':
          _setConnected(true);
          _subscribeChannel('tables');
          _subscribeChannel('reservations');
          break;

        case 'pusher_internal:subscription_succeeded':
          print('✅ Subscribed: ${message['channel']}');
          break;

        // 🔥 FIX: handle pong dari server
        case 'pusher:pong':
          print('💓 Pong received');
          break;

        // 🔥 FIX: handle ping dari server (server kadang ping duluan)
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          break;

        case 'reservation.updated':
        case 'App\\Events\\ReservationUpdated':
          if (data.isNotEmpty) {
            _reservationController.add(data);
            print('🔔 Reservation updated: ${data['id']} → ${data['reservation_status']}');
          }
          break;

        case 'table.updated':
        case 'App\\Events\\TableStatusUpdated':
          if (data.isNotEmpty) {
            _tableController.add(TableEvent(type: 'updated', data: data));
            print('🔥 Table updated: ${data['id']}');
          }
          break;

        case 'table.created':
        case 'App\\Events\\TableCreated':
          if (data.isNotEmpty) {
            _tableController.add(TableEvent(type: 'created', data: data));
          }
          break;

        case 'table.deleted':
        case 'App\\Events\\TableDeleted':
          _tableController.add(TableEvent(type: 'deleted', data: data));
          break;

        default:
          if (!event.startsWith('pusher')) {
            print('📨 Unknown event: $event | data: ${jsonEncode(data)}');
          }
      }
    } catch (e) {
      print('❌ Parse error: $e | raw: $rawData');
    }
  }

  static Map<String, dynamic> _parseData(dynamic data) {
    if (data is String) {
      try {
        return safeCastMap(jsonDecode(data));
      } catch (_) {}
    }
    return safeCastMap(data);
  }

  static void _subscribeChannel(String channel) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channel},
    });
    print('📡 Subscribe: $channel');
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
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
      print('💓 Ping sent');
    });
  }

  static void _onError(dynamic error) {
    print('❌ WS Error: $error');
    _setConnected(false);
    _scheduleReconnect();
  }

  static void _onDone() {
    print('🔌 WS Done/Closed');
    _setConnected(false);
    if (!_intentionalDisconnect) _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectAttempts++;
    final delay =
        Duration(seconds: (_reconnectAttempts * 2).clamp(2, 30));
    print('🔄 Reconnect #$_reconnectAttempts in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect) connect(isRetry: true);
    });
  }

  static Future<void> disconnect({bool intentional = true}) async {
    if (intentional) _intentionalDisconnect = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setConnected(false);
  }
}