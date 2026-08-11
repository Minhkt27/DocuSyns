import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FolderModel {
  final int id;
  final String name;
  final int? parentId;
  final int? createdBy;
  final String? createdAt;

  FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.createdBy,
    this.createdAt,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId'],
      createdBy: json['createdBy'],
      createdAt: json['createdAt'],
    );
  }
}

class DocumentVersionModel {
  final int id;
  final int documentId;
  final int versionNumber;
  final String storageFileId;
  final String fileName;
  final int fileSize;
  final int? uploadedBy;
  final String? uploadedAt;
  final String? note;

  DocumentVersionModel({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.storageFileId,
    required this.fileName,
    required this.fileSize,
    this.uploadedBy,
    this.uploadedAt,
    this.note,
  });

  factory DocumentVersionModel.fromJson(Map<String, dynamic> json) {
    return DocumentVersionModel(
      id: json['id'],
      documentId: json['documentId'],
      versionNumber: json['versionNumber'],
      storageFileId: json['storageFileId'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      uploadedBy: json['uploadedBy'],
      uploadedAt: json['uploadedAt'],
      note: json['note'],
    );
  }
}

class DocumentModel {
  final int id;
  final String documentCode;
  final String title;
  final int? currentVersionId;
  final int? createdBy;
  final int? folderId;
  final int? lockedBy;
  final String? lockedByName;

  DocumentModel({
    required this.id,
    required this.documentCode,
    required this.title,
    this.currentVersionId,
    this.createdBy,
    this.folderId,
    this.lockedBy,
    this.lockedByName,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      documentCode: json['documentCode'],
      title: json['title'],
      currentVersionId: json['currentVersionId'],
      createdBy: json['createdBy'],
      folderId: json['folderId'],
      lockedBy: json['lockedBy'],
      lockedByName: json['lockedByName'],
    );
  }

  DocumentModel copyWith({
    int? id,
    String? documentCode,
    String? title,
    int? currentVersionId,
    int? createdBy,
    int? folderId,
    int? lockedBy,
    String? lockedByName,
    bool clearLockedBy = false,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      documentCode: documentCode ?? this.documentCode,
      title: title ?? this.title,
      currentVersionId: currentVersionId ?? this.currentVersionId,
      createdBy: createdBy ?? this.createdBy,
      folderId: folderId ?? this.folderId,
      lockedBy: clearLockedBy ? null : (lockedBy ?? this.lockedBy),
      lockedByName: clearLockedBy ? null : (lockedByName ?? this.lockedByName),
    );
  }
}

class PagedResponse<T> {
  final List<T> content;
  final int currentPage;
  final int totalPages;
  final int totalElements;
  final bool hasNext;

  PagedResponse({
    required this.content,
    required this.currentPage,
    required this.totalPages,
    required this.totalElements,
    required this.hasNext,
  });

  factory PagedResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return PagedResponse(
      content: (json['content'] as List).map((i) => fromJsonT(i)).toList(),
      currentPage: json['currentPage'],
      totalPages: json['totalPages'],
      totalElements: json['totalElements'],
      hasNext: json['hasNext'],
    );
  }
}

class ActivityLogModel {
  final int id;
  final int userId;
  final String action;
  final int targetId;
  final String targetType;
  final String createdAt;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'],
      userId: json['userId'],
      action: json['action'],
      targetId: json['targetId'],
      targetType: json['targetType'],
      createdAt: json['createdAt'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'http://192.168.1.7:8080/api/v1';
  static String? token;
  static String? currentRole;
  static String? currentUserName;
  static int? currentUserId;
  static void Function()? onUnauthorized;
  
  static const _storage = FlutterSecureStorage();

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      logout();
      onUnauthorized?.call();
      throw Exception('Session expired. Please login again.');
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static Future<void> init() async {
    token = await _storage.read(key: 'jwt_token');
    currentRole = await _storage.read(key: 'user_role');
    currentUserName = await _storage.read(key: 'user_name');
    final idStr = await _storage.read(key: 'user_id');
    if (idStr != null) {
      currentUserId = int.tryParse(idStr);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        currentRole = data['role'];
        currentUserName = data['fullName'];
        currentUserId = data['userId'];

        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_role', value: currentRole);
        await _storage.write(key: 'user_name', value: currentUserName);
        if (currentUserId != null) {
          await _storage.write(key: 'user_id', value: currentUserId.toString());
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    token = null;
    currentRole = null;
    currentUserName = null;
    currentUserId = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    await _storage.delete(key: 'user_id');
  }

  static Future<void> saveCredentials(String email, String password) async {
    final savedJson = await _storage.read(key: 'saved_credentials_map');
    Map<String, dynamic> map = {};
    if (savedJson != null) {
      map = jsonDecode(savedJson);
    }
    map[email] = password;
    await _storage.write(key: 'saved_credentials_map', value: jsonEncode(map));
  }

  static Future<void> clearCredentials(String email) async {
    final savedJson = await _storage.read(key: 'saved_credentials_map');
    if (savedJson != null) {
      Map<String, dynamic> map = jsonDecode(savedJson);
      map.remove(email);
      await _storage.write(key: 'saved_credentials_map', value: jsonEncode(map));
    }
  }

  static Future<Map<String, String>> readSavedCredentials() async {
    final savedJson = await _storage.read(key: 'saved_credentials_map');
    if (savedJson != null) {
      Map<String, dynamic> map = jsonDecode(savedJson);
      return map.map((key, value) => MapEntry(key, value.toString()));
    }
    return {};
  }

  static Future<void> saveLastEmail(String email) async {
    await _storage.write(key: 'last_logged_in_email', value: email);
  }

  static Future<String?> readLastEmail() async {
    return await _storage.read(key: 'last_logged_in_email');
  }

  // Folder APIs
  Future<List<FolderModel>> getFolders({int? parentId}) async {
    String url = '$baseUrl/folders';
    if (parentId != null) {
      url += '?parentId=$parentId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => FolderModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load folders');
    }
  }

  Future<PagedResponse<DocumentModel>> getDocuments({int? folderId, String? searchQuery, bool myOnly = false, int page = 0, int size = 20}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (folderId != null) queryParams['folderId'] = folderId.toString();
    if (searchQuery != null) queryParams['searchQuery'] = searchQuery;
    if (myOnly) queryParams['myOnly'] = 'true';

    final uri = Uri.parse('$baseUrl/documents').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    _checkUnauthorized(response);
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return PagedResponse<DocumentModel>.fromJson(
        jsonResponse,
        (json) => DocumentModel.fromJson(json),
      );
    } else {
      throw Exception('Failed to load documents');
    }
  }

  Future<FolderModel> createFolder(String name, {int? parentId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/folders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'parentId': parentId,
      }),
    );
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      return FolderModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create folder: ${response.body}');
    }
  }


  Future<DocumentModel> uploadNewDocument(String fileName, Uint8List fileBytes, {int? folderId}) async {
    String url = '$baseUrl/documents';
    if (folderId != null) url += '?folderId=$folderId';

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType('application', 'octet-stream'),
    ));

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return DocumentModel.fromJson(jsonDecode(respStr));
    } else {
      throw Exception('Failed to upload document');
    }
  }

  Future<bool> lockDocument(int documentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/documents/$documentId/lock'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      debugPrint('Lock Document failed with status: ${response.statusCode}, body: ${response.body}');
      return false;
    }
    return true;
  }

  Future<bool> unlockDocument(int documentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/documents/$documentId/unlock'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);
    return response.statusCode == 200;
  }

  Future<Uint8List> downloadDocument(int documentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/documents/$documentId/download'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download document from server');
    }
  }

  Future<void> updateDocumentVersion(int documentId, String fileName, Uint8List fileBytes, {String? note}) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents/$documentId/upload'));
    request.headers['Authorization'] = 'Bearer $token';

    if (note != null && note.isNotEmpty) {
      request.fields['note'] = note;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType('application', 'octet-stream'),
    ));

    var response = await request.send();
    if (response.statusCode != 200) {
      String responseBody = await response.stream.bytesToString();
      throw Exception(responseBody.isNotEmpty ? responseBody : 'Failed to upload new version');
    }
  }

  Future<List<DocumentVersionModel>> getVersionHistory(int documentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/documents/$documentId/versions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => DocumentVersionModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load version history');
    }
  }

  Future<Uint8List> downloadSpecificVersion(int documentId, int versionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/documents/$documentId/versions/$versionId/download'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download specific version');
    }
  }

  Future<void> rollbackToVersion(int documentId, int versionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/documents/$documentId/rollback?versionId=$versionId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkUnauthorized(response);
    if (response.statusCode != 200) {
      debugPrint('Rollback failed with status: ${response.statusCode}, body: ${response.body}');
      throw Exception('Failed to rollback to version. Backend says: ${response.body}');
    }
  }

  // TRASH API
  Future<void> moveFolderToTrash(int folderId) async {
    final response = await http.put(Uri.parse('$baseUrl/folders/$folderId/trash'), headers: {'Authorization': 'Bearer $token'});
    _checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to move folder to trash');
  }

  Future<void> restoreFolderFromTrash(int folderId) async {
    final response = await http.put(Uri.parse('$baseUrl/folders/$folderId/restore'), headers: {'Authorization': 'Bearer $token'});
    _checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to restore folder');
  }

  Future<void> moveDocumentToTrash(int documentId) async {
    final response = await http.put(Uri.parse('$baseUrl/documents/$documentId/trash'), headers: {'Authorization': 'Bearer $token'});
    _checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to move document to trash');
  }

  Future<void> restoreDocumentFromTrash(int documentId) async {
    final response = await http.put(Uri.parse('$baseUrl/documents/$documentId/restore'), headers: {'Authorization': 'Bearer $token'});
    _checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to restore document');
  }

  Future<Map<String, List<dynamic>>> getTrashItems() async {
    final response = await http.get(Uri.parse('$baseUrl/trash'), headers: {'Authorization': 'Bearer $token'});
    _checkUnauthorized(response);
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return {
        'folders': (jsonResponse['folders'] as List).map((i) => FolderModel.fromJson(i)).toList(),
        'documents': (jsonResponse['documents'] as List).map((i) => DocumentModel.fromJson(i)).toList(),
      };
    }
    throw Exception('Failed to load trash');
  }

  // ACTIVITY LOG API
  Future<List<ActivityLogModel>> getRecentActivities() async {
    final response = await http.get(Uri.parse('$baseUrl/activities'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => ActivityLogModel.fromJson(item)).toList();
    }
    throw Exception('Failed to load activities');
  }

  // SEARCH API
  Future<Map<String, List<dynamic>>> globalSearch(String query, {bool myOnly = false}) async {
    final url = '$baseUrl/search?q=$query' + (myOnly ? '&myOnly=true' : '');
    final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return {
        'folders': (jsonResponse['folders'] as List).map((i) => FolderModel.fromJson(i)).toList(),
        'documents': (jsonResponse['documents'] as List).map((i) => DocumentModel.fromJson(i)).toList(),
      };
    }
    throw Exception('Failed to search');
  }

  // System Settings APIs
  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch settings');
  }

  Future<void> updateSettings(int maxVersions, int trashRetention) async {
    final response = await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'maxVersionsPerFile': maxVersions,
        'trashRetentionDays': trashRetention,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settings');
    }
  }
}
