import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Menggunakan static final karena nilainya diambil saat runtime
  static final String baseUrl = dotenv.get('BASE_URL', fallback: 'http://127.0.0.1:8000');
  static final String apiUrl = '$baseUrl/api';
  
  static final String wsHost = dotenv.get('WS_HOST', fallback: '127.0.0.1');
  static final int wsPort = int.parse(dotenv.get('WS_PORT', fallback: '8080'));
  static final String wsAppKey = dotenv.get('WS_APP_KEY', fallback: '');
}