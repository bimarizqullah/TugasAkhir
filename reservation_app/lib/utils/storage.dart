import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _tokenKey = 'auth_token';
  static const _userKey  = 'auth_user';

  // In-memory cache — mencegah async read berulang dan
  // memastikan nilai tersedia sinkron setelah init()
  static String? _cachedToken;
  static String? _cachedUser;

  /// Wajib dipanggil sekali di main() sebelum runApp()
  /// agar cache terisi dari SharedPreferences saat startup/refresh
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedUser  = prefs.getString(_userKey);
  }

  /// Cek apakah ada session aktif — sinkron, aman dipanggil di build()
  static bool hasSession() => _cachedToken != null && _cachedToken!.isNotEmpty;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<void> saveUser(String userJson) async {
    _cachedUser = userJson;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userJson);
  }

  static Future<String?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    _cachedUser = prefs.getString(_userKey);
    return _cachedUser;
  }

  static Future<void> clear() async {
    _cachedToken = null;
    _cachedUser  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}