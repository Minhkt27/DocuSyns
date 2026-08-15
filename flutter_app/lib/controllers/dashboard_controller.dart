import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';

class BreadcrumbItem {
  final int id;
  final String name;
  BreadcrumbItem({required this.id, required this.name});
}

/// Holds the state and business logic for one dashboard view (My Documents /
/// All Documents / Trash each get their own instance). Methods here perform
/// API calls and mutate state; anything that needs a BuildContext (dialogs,
/// SnackBars, file pickers) stays in dashboard_page.dart and calls into this
/// controller for the data part.
class DashboardController extends ChangeNotifier {
  DashboardController({
    required AuthSession session,
    required this.isMyDocuments,
    required this.isTrashMode,
    this.onActivity,
    this.onError,
  }) : _apiService = ApiService(session);

  final ApiService _apiService;
  final bool isMyDocuments;
  final bool isTrashMode;
  final void Function(String)? onActivity;

  /// Called when [loadContent] fails. loadContent is often invoked without
  /// being awaited (initState, folder navigation, the Reload button) so it
  /// must never let an exception escape unhandled - it reports failures
  /// here instead of rethrowing, since the controller has no BuildContext
  /// to show a SnackBar itself.
  final void Function(String)? onError;

  List<FolderModel> folders = [];
  List<DocumentModel> documents = [];
  bool isLoading = true;
  bool isFetchingMore = false;

  final List<BreadcrumbItem> breadcrumbs = [];
  int? currentFolderId;
  String searchQuery = '';

  int currentPage = 0;
  bool hasMoreDocuments = true;

  int? get currentUserId => _apiService.session.userId;
  String? get currentUserName => _apiService.session.userName;

  bool canCreateFolder(String userRole) {
    if (currentFolderId == null) {
      return userRole == 'ADMIN';
    }
    return userRole == 'ADMIN' || userRole == 'PROJECT_MANAGER';
  }

  Future<void> loadContent() async {
    isLoading = true;
    currentPage = 0;
    hasMoreDocuments = true;
    documents = [];
    folders = [];
    notifyListeners();

    try {
      if (isTrashMode) {
        final trash = await _apiService.getTrashItems();
        folders = (trash['folders'] as List).cast<FolderModel>();
        documents = (trash['documents'] as List).cast<DocumentModel>();
      } else if (searchQuery.isNotEmpty) {
        final searchResults = await _apiService.globalSearch(searchQuery, myOnly: isMyDocuments);
        folders = (searchResults['folders'] as List).cast<FolderModel>();
        documents = (searchResults['documents'] as List).cast<DocumentModel>();
      } else {
        final loadedFolders = await _apiService.getFolders(parentId: currentFolderId);
        final pagedDocs = await _apiService.getDocuments(
          folderId: currentFolderId,
          myOnly: isMyDocuments,
          page: 0,
        );
        folders = loadedFolders;
        documents = pagedDocs.content;
        hasMoreDocuments = pagedDocs.hasNext;
      }
    } catch (e) {
      onError?.call('Error loading content: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreDocuments() async {
    if (isFetchingMore || !hasMoreDocuments || isLoading || isTrashMode || searchQuery.isNotEmpty) return;

    isFetchingMore = true;
    notifyListeners();
    try {
      final pagedDocs = await _apiService.getDocuments(
        folderId: currentFolderId,
        myOnly: isMyDocuments,
        page: currentPage + 1,
      );
      currentPage++;
      documents = [...documents, ...pagedDocs.content];
      hasMoreDocuments = pagedDocs.hasNext;
    } catch (_) {
      // Ignored - this is background pagination, a failed page fetch just
      // means the user can retry by scrolling again.
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  void navigateToFolder(FolderModel folder) {
    breadcrumbs.add(BreadcrumbItem(id: folder.id, name: folder.name));
    currentFolderId = folder.id;
    searchQuery = '';
    loadContent();
  }

  void navigateToBreadcrumb(int index) {
    if (index < 0) {
      breadcrumbs.clear();
      currentFolderId = null;
    } else {
      final item = breadcrumbs[index];
      breadcrumbs.removeRange(index + 1, breadcrumbs.length);
      currentFolderId = item.id;
    }
    searchQuery = '';
    loadContent();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    loadContent();
  }

  Future<void> createFolder(String name) async {
    await _apiService.createFolder(name, parentId: currentFolderId);
    onActivity?.call('Created folder: $name');
    await loadContent();
  }

  Future<void> uploadDocument(String fileName, Uint8List bytes) async {
    isLoading = true;
    notifyListeners();
    try {
      await _apiService.uploadNewDocument(fileName, bytes, folderId: currentFolderId);
      onActivity?.call('Uploaded: $fileName');
      await loadContent();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDocumentVersion(int documentId, String fileName, Uint8List bytes, {String? note}) async {
    isLoading = true;
    notifyListeners();
    try {
      await _apiService.updateDocumentVersion(documentId, fileName, bytes, note: note);
      onActivity?.call('Updated version: $fileName');
      await loadContent();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLock(DocumentModel doc) async {
    if (doc.lockedBy != null) {
      final unlocked = await _apiService.unlockDocument(doc.id);
      if (!unlocked) throw Exception('Failed to unlock document. Check permissions.');
      _replaceDocument(doc.copyWith(clearLockedBy: true));
      onActivity?.call('Unlocked: ${doc.title}');
    } else {
      final locked = await _apiService.lockDocument(doc.id);
      if (!locked) throw Exception('Failed to lock document. It might be locked by another user.');
      _replaceDocument(doc.copyWith(lockedBy: currentUserId, lockedByName: currentUserName));
      onActivity?.call('Locked: ${doc.title}');
    }
  }

  void _replaceDocument(DocumentModel updated) {
    final idx = documents.indexWhere((d) => d.id == updated.id);
    if (idx != -1) {
      documents[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteFolder(FolderModel folder) async {
    await _apiService.moveFolderToTrash(folder.id);
    onActivity?.call('Moved folder "${folder.name}" to trash.');
    await loadContent();
  }

  Future<void> restoreFolder(FolderModel folder) async {
    await _apiService.restoreFolderFromTrash(folder.id);
    onActivity?.call('Restored folder "${folder.name}".');
    await loadContent();
  }

  Future<void> deleteDocument(DocumentModel doc) async {
    await _apiService.moveDocumentToTrash(doc.id);
    onActivity?.call('Moved document "${doc.title}" to trash.');
    await loadContent();
  }

  Future<void> restoreDocument(DocumentModel doc) async {
    await _apiService.restoreDocumentFromTrash(doc.id);
    onActivity?.call('Restored document "${doc.title}".');
    await loadContent();
  }

  Future<void> rollbackVersion(DocumentModel doc, DocumentVersionModel version) async {
    isLoading = true;
    notifyListeners();
    try {
      await _apiService.lockDocument(doc.id);
      await _apiService.rollbackToVersion(doc.id, version.id);
      onActivity?.call('Rolled back ${doc.title} to v${version.versionNumber}');
      await loadContent();
    } catch (e) {
      await _apiService.unlockDocument(doc.id);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<DocumentVersionModel>> getVersionHistory(int documentId) {
    return _apiService.getVersionHistory(documentId);
  }

  Future<Uint8List> downloadDocument(int documentId) {
    return _apiService.downloadDocument(documentId);
  }

  Future<Uint8List> downloadSpecificVersion(int documentId, int versionId) {
    return _apiService.downloadSpecificVersion(documentId, versionId);
  }

  Future<void> pinVersion(int documentId, int versionId) {
    return _apiService.pinVersion(documentId, versionId);
  }

  Future<void> unpinVersion(int documentId, int versionId) {
    return _apiService.unpinVersion(documentId, versionId);
  }
}
