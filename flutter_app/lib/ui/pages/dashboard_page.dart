import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/api_service.dart';
import '../widgets/preview_dialog.dart';

class DashboardPage extends StatefulWidget {
  final void Function(String)? onActivity;
  final bool isMyDocuments;
  final bool isTrashMode;
  final String userRole;

  const DashboardPage({
    super.key,
    this.onActivity,
    this.isMyDocuments = false,
    this.isTrashMode = false,
    this.userRole = 'ADMIN',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  List<FolderModel> _folders = [];
  List<DocumentModel> _documents = [];
  bool _isLoading = true;

  // Navigation stack for breadcrumbs
  final List<_BreadcrumbItem> _breadcrumbs = [];
  int? _currentFolderId;

  // Track locks locally (removed since it is API-driven)
  // Search
  String _searchQuery = '';
  Timer? _debounce;

  // Pagination
  int _currentPage = 0;
  bool _hasMoreDocuments = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreDocuments();
    }
  }

  Future<void> _loadMoreDocuments() async {
    if (_isFetchingMore || !_hasMoreDocuments || _isLoading || widget.isTrashMode || _searchQuery.isNotEmpty) return;
    
    setState(() => _isFetchingMore = true);
    try {
      final pagedDocs = await _apiService.getDocuments(
        folderId: _currentFolderId,
        myOnly: widget.isMyDocuments,
        page: _currentPage + 1,
      );
      setState(() {
        _currentPage++;
        _documents.addAll(pagedDocs.content);
        _hasMoreDocuments = pagedDocs.hasNext;
      });
    } catch (e) {
      // Ignored for scroll
    } finally {
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMyDocuments != widget.isMyDocuments || oldWidget.isTrashMode != widget.isTrashMode) {
      // Reset navigation when switching modes
      _breadcrumbs.clear();
      _currentFolderId = null;
      _searchQuery = '';
      _loadContent();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final settings = await _apiService.getSettings();
      final latestVersion = settings['clientAppVersion']?.toString() ?? '';
      final downloadUrl = settings['clientAppUrl']?.toString() ?? '';
      
      if (latestVersion.isEmpty || downloadUrl.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      if (_isVersionGreater(latestVersion, currentVersion)) {
        _showUpdateDialog(latestVersion, downloadUrl);
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
  }

  bool _isVersionGreater(String latest, String current) {
    try {
      final lParts = latest.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDownloading = false;
        double progress = 0;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text('Update Available', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version ($version) of DocuSync is available and required to continue.',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text('Downloading: ${(progress * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  ]
                ],
              ),
              actions: [
                if (!isDownloading)
                  TextButton(
                    onPressed: () => exit(0),
                    child: Text('Exit App', style: GoogleFonts.inter(color: Colors.redAccent)),
                  ),
                if (!isDownloading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () async {
                      setState(() => isDownloading = true);
                      await _downloadAndInstallUpdate(url, (p) {
                        setState(() => progress = p);
                      });
                    },
                    child: Text('Update Now', style: GoogleFonts.inter(color: Colors.white)),
                  )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _downloadAndInstallUpdate(String url, Function(double) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}\\DocuSync_Update_$DateTime.now().millisecondsSinceEpoch.exe';
      
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Launch the installer
      await Process.start(savePath, []);
      
      // Exit current app so installer can overwrite files
      exit(0);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMoreDocuments = true;
      _documents.clear();
      _folders.clear();
    });
    try {
      if (widget.isTrashMode) {
        final trash = await _apiService.getTrashItems();
        setState(() {
          _folders = (trash['folders'] as List).cast<FolderModel>();
          _documents = (trash['documents'] as List).cast<DocumentModel>();
        });
      } else if (_searchQuery.isNotEmpty) {
        final searchResults = await _apiService.globalSearch(_searchQuery, myOnly: widget.isMyDocuments);
        setState(() {
          _folders = (searchResults['folders'] as List).cast<FolderModel>();
          _documents = (searchResults['documents'] as List).cast<DocumentModel>();
        });
      } else {
        final folders = await _apiService.getFolders(parentId: _currentFolderId);
        final pagedDocs = await _apiService.getDocuments(
          folderId: _currentFolderId,
          myOnly: widget.isMyDocuments,
          page: 0,
        );
        setState(() {
          _folders = folders;
          _documents = pagedDocs.content;
          _hasMoreDocuments = pagedDocs.hasNext;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToFolder(FolderModel folder) {
    _breadcrumbs.add(_BreadcrumbItem(id: folder.id, name: folder.name));
    _currentFolderId = folder.id;
    _searchQuery = '';
    _loadContent();
  }

  void _previewDocument(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (context) {
        return PreviewDialog(
          document: doc,
          apiService: _apiService,
          onDownload: () {
            Navigator.pop(context);
            _downloadDocument(doc);
          },
        );
      },
    );
  }

  void _navigateToBreadcrumb(int index) {
    if (index < 0) {
      // Go to root
      _breadcrumbs.clear();
      _currentFolderId = null;
    } else {
      final item = _breadcrumbs[index];
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      _currentFolderId = item.id;
    }
    _searchQuery = '';
    _loadContent();
  }

  Future<void> _createFolder() async {
    String? folderName;
    await showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            _currentFolderId == null ? 'Create New Project' : 'Create Sub-Folder',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Folder name...',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blueAccent),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                folderName = controller.text.trim();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              child: Text('Create', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (folderName != null && folderName!.isNotEmpty) {
      try {
        await _apiService.createFolder(folderName!, parentId: _currentFolderId);
        widget.onActivity?.call('Created folder: $folderName');
        await _loadContent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder created successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _uploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.bytes == null && file.path != null) {
        file = PlatformFile(
          name: file.name,
          size: file.size,
          bytes: await File(file.path!).readAsBytes(),
        );
      }

      if (file.bytes == null) return;

      setState(() => _isLoading = true);
      try {
        await _apiService.uploadNewDocument(file.name, file.bytes!, folderId: _currentFolderId);
        widget.onActivity?.call('Uploaded: ${file.name}');
        await _loadContent();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final bytes = await _apiService.downloadDocument(doc.id);

      String extension = '';
      if (doc.title.contains('.')) {
        extension = doc.title.split('.').last;
      }

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save document',
        fileName: doc.title,
        type: extension.isNotEmpty ? FileType.custom : FileType.any,
        allowedExtensions: extension.isNotEmpty ? [extension] : null,
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        widget.onActivity?.call('Downloaded: ${doc.title}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to $outputPath'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _toggleLock(DocumentModel doc) async {
    try {
      if (doc.lockedBy != null) {
        bool unlocked = await _apiService.unlockDocument(doc.id);
        if (!unlocked) throw Exception('Failed to unlock document. Check permissions.');
        setState(() {
          int idx = _documents.indexWhere((d) => d.id == doc.id);
          if (idx != -1) _documents[idx] = doc.copyWith(clearLockedBy: true);
        });
        widget.onActivity?.call('Unlocked: ${doc.title}');
      } else {
        bool locked = await _apiService.lockDocument(doc.id);
        if (!locked) throw Exception('Failed to lock document. It might be locked by another user.');
        
        setState(() {
          int idx = _documents.indexWhere((d) => d.id == doc.id);
          if (idx != -1) {
            _documents[idx] = doc.copyWith(
              lockedBy: ApiService.currentUserId,
              lockedByName: ApiService.currentUserName,
            );
          }
        });
        widget.onActivity?.call('Locked: ${doc.title}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateDocument(DocumentModel doc) async {
    int? myUserId = ApiService.currentUserId;
    if (doc.lockedBy != myUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must lock this document before uploading a new version.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      if (file.bytes == null && file.path != null) {
        file = PlatformFile(
          name: file.name,
          size: file.size,
          bytes: await File(file.path!).readAsBytes(),
        );
      }

      if (file.bytes == null) return;

      // Ask for note
      String? updateNote;
      bool proceed = false;
      if (!mounted) return;
      
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (ctx) {
          if (!mounted) return const SizedBox.shrink();
          final controller = TextEditingController();
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text('Upload New Version', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What changed in this version?',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(8)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54))),
              ElevatedButton(
                onPressed: () {
                  updateNote = controller.text.trim();
                  proceed = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                child: Text('Upload', style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          );
        }
      );

      if (!proceed) return;

      setState(() => _isLoading = true);
      try {
        await _apiService.updateDocumentVersion(doc.id, file.name, file.bytes!, note: updateNote);
        widget.onActivity?.call('Updated version: ${file.name}');
        await _loadContent();
        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New version uploaded!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showVersionHistory(DocumentModel doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final history = await _apiService.getVersionHistory(doc.id);
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showHistoryDialog(doc, history);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showHistoryDialog(DocumentModel doc, List<DocumentVersionModel> history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Version History: ${doc.title}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: history.isEmpty 
              ? const Center(child: Text('No version history', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final version = history[index];
                    final isCurrent = index == 0; // Assuming sorted desc
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrent ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: isCurrent ? Colors.blueAccent : Colors.white10),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Version ${version.versionNumber}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('CURRENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(version.fileName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (version.note != null && version.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Note: ${version.note}', style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(version.uploadedAt?.replaceAll('T', ' ').substring(0, 16) ?? 'Unknown time', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _downloadSpecificVersion(doc.id, version.id, version.fileName),
                                icon: const Icon(Icons.download, size: 14),
                                label: const Text('Download', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(foregroundColor: Colors.blueAccent, padding: EdgeInsets.zero, minimumSize: Size.zero),
                              ),
                              if (!isCurrent && (widget.userRole == 'ADMIN' || widget.userRole == 'PROJECT_MANAGER')) ...[
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _rollbackVersion(doc, version);
                                  },
                                  icon: const Icon(Icons.restore, size: 14),
                                  label: const Text('Rollback', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent, padding: EdgeInsets.zero, minimumSize: Size.zero),
                                )
                              ]
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: GoogleFonts.inter(color: Colors.white54))),
        ],
      ),
    );
  }

  Future<void> _downloadSpecificVersion(int docId, int versionId, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading version...')));
      final bytes = await _apiService.downloadSpecificVersion(docId, versionId);
      String extension = '';
      if (fileName.contains('.')) {
        extension = fileName.split('.').last;
      }
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save version',
        fileName: fileName,
        type: extension.isNotEmpty ? FileType.custom : FileType.any,
        allowedExtensions: extension.isNotEmpty ? [extension] : null,
      );
      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $outputPath'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _rollbackVersion(DocumentModel doc, DocumentVersionModel version) async {
    setState(() => _isLoading = true);
    try {
      bool locked = await _apiService.lockDocument(doc.id);
      if (!locked) {
        // If lock failed, it might be locked by another user. Let's try to proceed anyway.
        // If it fails on the backend, rollbackToVersion will throw a specific error.
      }
      
      await _apiService.rollbackToVersion(doc.id, version.id);
      
      widget.onActivity?.call('Rolled back ${doc.title} to v${version.versionNumber}');
      await _loadContent();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rolled back successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      // Always attempt to unlock if something went wrong and we had locked it
      await _apiService.unlockDocument(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rollback failed: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get _canCreateFolder {
    if (_currentFolderId == null) {
      // Root level: only ADMIN
      return widget.userRole == 'ADMIN';
    } else {
      // Sub-folder: ADMIN or PM
      return widget.userRole == 'ADMIN' || widget.userRole == 'PROJECT_MANAGER';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isMyDocuments ? 'My Documents' : 'All Documents',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isMyDocuments
                      ? 'Your uploaded documents, organized by project.'
                      : 'All company documents and project folders.',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        setState(() {
                          _searchQuery = value;
                        });
                        _loadContent();
                      });
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                if (_canCreateFolder)
                  ElevatedButton.icon(
                    onPressed: _createFolder,
                    icon: const Icon(Icons.create_new_folder),
                    label: Text(
                      _currentFolderId == null ? 'New Project' : 'New Folder',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadContent,
                  icon: const Icon(Icons.refresh),
                  label: Text('Reload', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF475569),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.upload_file),
                  label: Text('Upload File', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Breadcrumbs
            _buildBreadcrumbs(),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_folders.isEmpty && _documents.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(
                                _currentFolderId == null
                                    ? 'No projects yet. Create one to get started!'
                                    : 'This folder is empty.',
                                style: GoogleFonts.inter(color: Colors.white54),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadContent,
                          child: ListView(
                            controller: _scrollController,
                            children: [
                              ..._folders.map((folder) => _buildFolderCard(folder)),
                              ..._documents.map((doc) => _buildDocumentCard(doc)),
                              if (_isFetchingMore)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _navigateToBreadcrumb(-1),
            child: Text(
              'Root',
              style: GoogleFonts.inter(
                color: _breadcrumbs.isEmpty ? Colors.white : Colors.blueAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ..._breadcrumbs.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == _breadcrumbs.length - 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 18, color: Colors.white38),
                ),
                InkWell(
                  onTap: isLast ? null : () => _navigateToBreadcrumb(index),
                  child: Text(
                    item.name,
                    style: GoogleFonts.inter(
                      color: isLast ? Colors.white : Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFolderCard(FolderModel folder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.isTrashMode ? null : () => _navigateToFolder(folder),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    folder.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (widget.isTrashMode)
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.greenAccent, size: 20),
                    tooltip: 'Restore',
                    onPressed: () => _restoreFolder(folder),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Move to Trash',
                    onPressed: () => _deleteFolder(folder),
                  ),
                if (!widget.isTrashMode) const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel doc) {
    bool isLocked = doc.lockedBy != null;
    String lockStatusText = 'Available';
    if (isLocked) {
      if (doc.lockedBy == ApiService.currentUserId) {
        lockStatusText = 'Locked by you';
      } else {
        lockStatusText = 'Locked by ${doc.lockedByName ?? "User ${doc.lockedBy}"}';
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.isTrashMode ? null : () => _previewDocument(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildBadge(doc.documentCode, Colors.white10, Colors.white70),
                    _buildBadge(
                      lockStatusText,
                      isLocked ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                      isLocked ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isTrashMode) ...[
            ElevatedButton.icon(
              onPressed: () => _toggleLock(doc),
              icon: Icon(isLocked ? Icons.lock_open : Icons.lock, size: 14),
              label: Text(
                isLocked ? 'Unlock' : 'Lock',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? Colors.redAccent : Colors.transparent,
                foregroundColor: isLocked ? Colors.white : Colors.white70,
                side: isLocked ? BorderSide.none : const BorderSide(color: Colors.white24),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.orangeAccent, size: 20),
              tooltip: 'Upload new version',
              onPressed: () => _updateDocument(doc),
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.purpleAccent, size: 20),
              tooltip: 'Version history',
              onPressed: () => _showVersionHistory(doc),
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.blueAccent, size: 20),
              tooltip: 'Download',
              onPressed: () => _downloadDocument(doc),
            ),
          ],
          if (widget.isTrashMode)
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.greenAccent, size: 20),
              tooltip: 'Restore',
              onPressed: () => _restoreDocument(doc),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Move to Trash',
              onPressed: () => _deleteDocument(doc),
            ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _deleteFolder(FolderModel folder) async {
    try {
      await _apiService.moveFolderToTrash(folder.id);
      widget.onActivity?.call('Moved folder "${folder.name}" to trash.');
      _loadContent();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _restoreFolder(FolderModel folder) async {
    try {
      await _apiService.restoreFolderFromTrash(folder.id);
      widget.onActivity?.call('Restored folder "${folder.name}".');
      _loadContent();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    try {
      await _apiService.moveDocumentToTrash(doc.id);
      widget.onActivity?.call('Moved document "${doc.title}" to trash.');
      _loadContent();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _restoreDocument(DocumentModel doc) async {
    try {
      await _apiService.restoreDocumentFromTrash(doc.id);
      widget.onActivity?.call('Restored document "${doc.title}".');
      _loadContent();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class _BreadcrumbItem {
  final int id;
  final String name;
  _BreadcrumbItem({required this.id, required this.name});
}
