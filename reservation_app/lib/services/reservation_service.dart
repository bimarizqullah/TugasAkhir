import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/storage.dart';
import '../config/app_config.dart';

class ReservationService {
  // ──────────────────────────────────────────────────────────────────────
  //  Helper header
  // ──────────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await Storage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type' : 'application/json',
      'Accept'       : 'application/json',
    };
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Reservasi
  // ──────────────────────────────────────────────────────────────────────

  /// Buat reservasi baru — sekarang wajib menyertakan start_time & end_time
  static Future<Map<String, dynamic>> createReservation({
    required int    idBilliards,
    int?            idPackages,
    required String customerName,
    required String customerPhone,
    required String reservationDate,
    required String startTime,   // format HH:MM
    required String endTime,     // format HH:MM
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/reservations'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'id_billiards'     : idBilliards,
        if (idPackages != null) 'id_packages': idPackages,
        'customer_name'    : customerName,
        'customer_phone'   : customerPhone,
        'reservation_date' : reservationDate,
        'start_time'       : startTime,
        'end_time'         : endTime,
      }),
    ).timeout(const Duration(seconds: 15));

    return {
      'status': response.statusCode,
      'data'  : jsonDecode(response.body),
    };
  }

  /// Ambil slot yang sudah terpesan di meja & tanggal tertentu
  /// untuk ditampilkan sebagai indikator jam tidak tersedia
  static Future<List<dynamic>> getBookedSlots({
    required int    idBilliards,
    required String reservationDate,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiUrl}/reservations/available-slots')
        .replace(queryParameters: {
      'id_billiards'     : idBilliards.toString(),
      'reservation_date' : reservationDate,
    });

    final response = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['booked_slots'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>> cancelReservation(int id) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/reservations/$id/cancel'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    return {
      'status': response.statusCode,
      'data'  : jsonDecode(response.body),
    };
  }

  static Future<List<dynamic>> getReservations() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/reservations'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    throw Exception(
        'Gagal load reservasi [${response.statusCode}]: ${response.body}');
  }

  static Future<List<dynamic>> getPackages() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/packages'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] ?? [];
      }
      debugPrint('⚠️ Packages ${response.statusCode}: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('⚠️ getPackages error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getTables() async {
    final token = await Storage.getToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/tables'),
      headers: headers,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['data'] ?? body ?? [];
    }
    throw Exception(
        'Gagal load meja [${response.statusCode}]: ${response.body}');
  }

  // ──────────────────────────────────────────────────────────────────────
  //  Payment — Midtrans QRIS
  // ──────────────────────────────────────────────────────────────────────

  /// Inisiasi / ambil kembali QRIS untuk reservasi yang sudah dikonfirmasi admin.
  ///
  /// Mengembalikan:
  /// ```json
  /// {
  ///   "order_id"   : "RESERVATION-1-...",
  ///   "qr_string"  : "00020101...",
  ///   "qr_url"     : "https://...",
  ///   "expired_at" : "2026-05-01T12:30:00.000000Z",
  ///   "amount"     : 50000
  /// }
  /// ```
  /// Throws [ReservationNotApprovedYet] jika admin belum approve.
  static Future<Map<String, dynamic>> initiatePayment(int reservationId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/reservations/$reservationId/pay'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final body = jsonDecode(response.body);
    final code = body['code'] ?? '';

    if (code == 'WAITING_APPROVAL') {
      throw ReservationNotApprovedYet();
    }
    if (code == 'ALREADY_PAID') {
      throw ReservationAlreadyPaid();
    }

    throw Exception(body['message'] ?? 'Gagal membuat transaksi QRIS');
  }

  /// Cek status pembayaran (polling di PaymentScreen).
  static Future<Map<String, dynamic>> checkPaymentStatus(int reservationId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/reservations/$reservationId/pay/status'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Gagal cek status [${response.statusCode}]');
  }
}

// ── Custom exceptions ────────────────────────────────────────────────────

class ReservationNotApprovedYet implements Exception {
  @override
  String toString() => 'Reservasi belum dikonfirmasi admin.';
}

class ReservationAlreadyPaid implements Exception {
  @override
  String toString() => 'Reservasi sudah berhasil dibayar.';
}