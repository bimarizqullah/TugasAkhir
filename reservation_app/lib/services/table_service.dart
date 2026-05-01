import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/storage.dart';
import '../config/app_config.dart'; // 🔥 IMPORT

class TableService {
  // 🔥 HAPUS const baseUrl - pakai AppConfig!

  static Future<List<dynamic>> getTables() async {
    final token = await Storage.getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/tables'), // 🔥 AUTO
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Gagal load tables: ${response.statusCode}');
  }

  static Future<List<dynamic>> getTablesWithSession() async {
    final token = await Storage.getToken();
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/tables?include_session=true'), // 🔥 AUTO
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] ?? jsonDecode(response.body);
        print('✅ FULL TABLES: ${data.length}');
        return data;
      }
    } catch (e) {
      print('❌ Session endpoint failed: $e');
    }

    // Fallback
    return (await getTables()).map((table) {
      (table as Map)['session'] ??= {};
      return table;
    }).toList();
  }

  static Future<Map<String, dynamic>> startSession(Map<String, dynamic> data) async {
    final token = await Storage.getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/start-session'), // 🔥 AUTO
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }
}