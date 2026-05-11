import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/storage.dart';
import '../config/app_config.dart'; // 🔥 IMPORT
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    scopes: ['email', 'profile'],
  );

  // ─── REGISTER ──────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/register'), // 🔥 AUTO
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await Storage.saveToken(data['token']);
      await Storage.saveUser(jsonEncode(data['user']));
    }
    return {'status': response.statusCode, 'data': data};
  }

  // ─── LOGIN ─────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/login'), // 🔥 AUTO
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await Storage.saveToken(data['token']);
      await Storage.saveUser(jsonEncode(data['user']));
    }
    return {'status': response.statusCode, 'data': data};
  }

  // ─── GOOGLE LOGIN ──────────────────────────────────
  static Future<Map<String, dynamic>?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/auth/google'), // 🔥 AUTO
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'google_id': googleUser.id,
          'name': googleUser.displayName,
          'email': googleUser.email,
          'photo_path': googleUser.photoUrl,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await Storage.saveToken(data['token']);
        await Storage.saveUser(jsonEncode(data['user']));
      }
      return {'status': response.statusCode, 'data': data};
    } catch (e) {
      return {'status': 500, 'data': {'message': 'Google Sign-In gagal: $e'}};
    }
  }

  // ─── LOGOUT ────────────────────────────────────────
  // auth_service.dart
  static Future<void> logout() async {
    final token = await Storage.getToken();
    if (token != null) {
      await http.post(
        Uri.parse('${AppConfig.apiUrl}/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    }

    // 🔥 Skip Google signOut — hanya panggil jika pakai Google login
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('⚠️ Google signOut skip: $e');
    }

    await Storage.clear();
  }

    // Ambil profile dari API
  static Future<Map<String, dynamic>?> getProfile() async {
    final token = await Storage.getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Simpan user terbaru ke storage
      await Storage.saveUser(jsonEncode(data['user']));
      return data['user'];
    }
    return null;
  }
}