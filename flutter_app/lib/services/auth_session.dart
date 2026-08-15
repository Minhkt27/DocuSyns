import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Owns the app's session state (auth token, current user, server address)
/// and the auth HTTP calls (login/refresh/logout) that produce it. Replaces
/// the static mutable fields that used to live on ApiService so widgets can
/// reactively rebuild via Provider instead of reading global statics.
///
/// "Remember me" no longer stores the user's password: on login the backend
/// also issues a long-lived refresh token, which - if the user opted in via
/// [setRememberMe] - is persisted and silently exchanged for a fresh access
/// token at app startup (see [init]), without ever touching the password.
class AuthSession extends ChangeNotifier {
  static const String _defaultBaseUrl = 'http://192.168.1.7:8080/api/v1';
  static const _storage = FlutterSecureStorage();

  String baseUrl = _defaultBaseUrl;
  String? token;
  String? role;
  String? userName;
  int? userId;
  String? _refreshToken;

  Future<void> init() async {
    token = await _storage.read(key: 'jwt_token');
    role = await _storage.read(key: 'user_role');
    userName = await _storage.read(key: 'user_name');
    final idStr = await _storage.read(key: 'user_id');
    if (idStr != null) userId = int.tryParse(idStr);

    final savedUrl = await _storage.read(key: 'server_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) baseUrl = savedUrl;

    _refreshToken = await _storage.read(key: 'refresh_token');
    if (_refreshToken != null) {
      final refreshed = await trySilentRefresh();
      if (!refreshed) {
        await _storage.delete(key: 'refresh_token');
        _refreshToken = null;
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode != 200) return false;

      _applyAuthResponse(jsonDecode(response.body));
      await _persistSession();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Exchanges the stored refresh token for a fresh access token. Returns
  /// false (without throwing) if there's no refresh token or it's no longer
  /// valid - the caller should fall back to the normal login screen.
  Future<bool> trySilentRefresh() async {
    final currentRefreshToken = _refreshToken;
    if (currentRefreshToken == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': currentRefreshToken}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;

      _applyAuthResponse(jsonDecode(response.body));
      await _persistSession();
      // Rotation means the server issued a new refresh token - persist it
      // under the same key so the next startup uses the current one.
      await _storage.write(key: 'refresh_token', value: _refreshToken);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Call right after a successful [login] once the user has chosen whether
  /// to stay signed in. Persists (or discards) the refresh token accordingly.
  Future<void> setRememberMe(bool remember) async {
    if (remember && _refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: _refreshToken);
    } else {
      await _storage.delete(key: 'refresh_token');
    }
  }

  Future<void> logout() async {
    final currentRefreshToken = _refreshToken;
    if (currentRefreshToken != null) {
      try {
        await http
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': currentRefreshToken}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Best-effort server-side revocation; local session is cleared regardless.
      }
    }

    token = null;
    role = null;
    userName = null;
    userId = null;
    _refreshToken = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'refresh_token');
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    baseUrl = trimmed.isEmpty ? _defaultBaseUrl : trimmed;
    await _storage.write(key: 'server_base_url', value: baseUrl);
    notifyListeners();
  }

  static Future<void> saveLastEmail(String email) async {
    await _storage.write(key: 'last_logged_in_email', value: email);
  }

  static Future<String?> readLastEmail() async {
    return _storage.read(key: 'last_logged_in_email');
  }

  void _applyAuthResponse(Map<String, dynamic> data) {
    token = data['token'];
    _refreshToken = data['refreshToken'];
    role = data['role'];
    userName = data['fullName'];
    userId = data['userId'];
  }

  Future<void> _persistSession() async {
    await _storage.write(key: 'jwt_token', value: token);
    await _storage.write(key: 'user_role', value: role);
    await _storage.write(key: 'user_name', value: userName);
    if (userId != null) {
      await _storage.write(key: 'user_id', value: userId.toString());
    }
  }
}
