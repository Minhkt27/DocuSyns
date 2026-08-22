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
  static const String _defaultBaseUrl = 'http://192.168.1.10:8080/api/v1';
  static const _storage = FlutterSecureStorage();

  String baseUrl = _defaultBaseUrl;
  String? token;
  String? role;
  String? userName;
  int? userId;
  String? _refreshToken;

  /// Set whenever "remember me" silently fails to restore a session at
  /// startup (storage error or a rejected refresh token), so LoginPage can
  /// surface *why* instead of the failure looking like the feature just
  /// doing nothing.
  String? lastAuthError;

  Future<void> init() async {
    try {
      token = await _storage.read(key: 'jwt_token');
      role = await _storage.read(key: 'user_role');
      userName = await _storage.read(key: 'user_name');
      final idStr = await _storage.read(key: 'user_id');
      if (idStr != null) userId = int.tryParse(idStr);

      final savedUrl = await _storage.read(key: 'server_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) baseUrl = savedUrl;

      _refreshToken = await _storage.read(key: 'refresh_token');

      // One-time cleanup: older builds stored raw passwords under this key
      // before "remember me" was switched to refresh tokens. Purge it from
      // any machine that still has it left over from before the upgrade.
      await _storage.delete(key: 'saved_credentials_map');
    } catch (e) {
      lastAuthError = 'Could not read saved session: $e';
      debugPrint('AuthSession.init: secure storage read failed: $e');
    }

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
      if (response.statusCode != 200) {
        lastAuthError = 'Login rejected (HTTP ${response.statusCode}): ${response.body}';
        return false;
      }

      _applyAuthResponse(jsonDecode(response.body));
      await _persistSession();
      lastAuthError = null;
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = 'Login failed: $e';
      debugPrint('AuthSession.login error: $e');
      return false;
    }
  }

  /// Exchanges the stored refresh token for a fresh access token. Returns
  /// false (without throwing) if there's no refresh token or it's no longer
  /// valid - the caller should fall back to the normal login screen. Sets
  /// [lastAuthError] with the concrete reason on failure, since a silently
  /// swallowed error here is exactly what makes "remember me" look broken
  /// with no way to tell why.
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
      if (response.statusCode != 200) {
        lastAuthError = 'Saved session expired (HTTP ${response.statusCode}): ${response.body}';
        debugPrint('AuthSession.trySilentRefresh: $lastAuthError');
        return false;
      }

      _applyAuthResponse(jsonDecode(response.body));
      await _persistSession();
      // Rotation means the server issued a new refresh token - persist it
      // under the same key so the next startup uses the current one.
      await _storage.write(key: 'refresh_token', value: _refreshToken);
      lastAuthError = null;
      notifyListeners();
      return true;
    } catch (e) {
      lastAuthError = 'Could not restore saved session: $e';
      debugPrint('AuthSession.trySilentRefresh error: $e');
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
