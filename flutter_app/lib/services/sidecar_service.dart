import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'auth_session.dart';

/// Manages the local Go sidecar process: launching it with the folder the
/// user picked to sync, and handing it the current JWT so its upload
/// requests can authenticate as the signed-in user. The sidecar is a
/// separate executable shipped alongside the Flutter app (see setup.iss),
/// not something bundled into this binary.
class SidecarService {
  SidecarService._();
  static final SidecarService instance = SidecarService._();

  static const _storage = FlutterSecureStorage();
  static const _syncFolderKey = 'sync_folder_path';
  static const _syncFolderIdKey = 'sync_folder_id';

  Process? _process;

  bool get isRunning => _process != null;

  Future<String?> getSyncFolderPath() => _storage.read(key: _syncFolderKey);

  Future<int?> getSyncFolderId() async {
    final raw = await _storage.read(key: _syncFolderIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setSyncFolder(String? path, int? folderId) async {
    if (path == null) {
      await _storage.delete(key: _syncFolderKey);
    } else {
      await _storage.write(key: _syncFolderKey, value: path);
    }
    if (folderId == null) {
      await _storage.delete(key: _syncFolderIdKey);
    } else {
      await _storage.write(key: _syncFolderIdKey, value: folderId.toString());
    }
  }

  /// Starts the sidecar if a sync folder has previously been configured.
  /// Safe to call on every app/login start; does nothing if not configured.
  Future<void> startIfConfigured(AuthSession session) async {
    final folder = await getSyncFolderPath();
    if (folder == null || folder.isEmpty) return;
    final folderId = await getSyncFolderId();
    await start(folder, folderId, session);
  }

  /// Launches the sidecar pointed at [folderPath], syncing the server folder
  /// [folderId] (new local files are created as documents in that folder,
  /// and its existing contents are pulled down on first run - see
  /// initialpull.Run in the sidecar). Throws if the sidecar executable can't
  /// be found so the caller can surface a clear error.
  Future<void> start(String folderPath, int? folderId, AuthSession session) async {
    await stop();

    final exePath = _resolveSidecarExePath();
    if (exePath == null) {
      throw Exception('Sidecar executable not found next to the app. Reinstall DocuSync or copy sidecar.exe into a "sidecar" folder beside docusync_client.exe.');
    }

    _process = await Process.start(
      exePath,
      [],
      environment: {
        'API_URL': _apiBaseUrl(session),
        'SYNC_FOLDER': folderPath,
        if (folderId != null) 'SYNC_FOLDER_ID': folderId.toString(),
      },
    );
    _process!.stdout.transform(utf8.decoder).listen((line) => debugPrint('[sidecar] $line'));
    _process!.stderr.transform(utf8.decoder).listen((line) => debugPrint('[sidecar:err] $line'));

    await pushToken(session);
  }

  /// Sends the current JWT to the sidecar's local /auth endpoint. Retries a
  /// few times since the sidecar's HTTP server may still be starting up.
  Future<void> pushToken(AuthSession session) async {
    final token = session.token;
    if (token == null) return;

    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('http://127.0.0.1:8081/auth'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'token': token}),
            )
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) return;
      } catch (_) {
        // Sidecar likely not ready yet - retry.
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    debugPrint('SidecarService: failed to push auth token after retries.');
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
  }

  String? _resolveSidecarExePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidate = '$exeDir${Platform.pathSeparator}sidecar${Platform.pathSeparator}sidecar.exe';
    if (File(candidate).existsSync()) return candidate;
    return null;
  }

  String _apiBaseUrl(AuthSession session) {
    return session.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
  }
}
