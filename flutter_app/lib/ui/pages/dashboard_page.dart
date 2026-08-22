import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';

import '../../controllers/dashboard_controller.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/update_checker.dart';
import '../../theme/app_colors.dart';
import '../widgets/preview_dialog.dart';
import '../widgets/dashboard/breadcrumb_bar.dart';
import '../widgets/dashboard/folder_card.dart';
import '../widgets/dashboard/document_card.dart';

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
  late final DashboardController _controller;
  late final ApiService _apiService;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    _apiService = ApiService(session);
    _controller = DashboardController(
      session: session,
      isMyDocuments: widget.isMyDocuments,
      isTrashMode: widget.isTrashMode,
      onActivity: widget.onActivity,
      onError: (message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
          );
        }
      },
    );
    _scrollController.addListener(_scrollListener);
    _controller.loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkAndPromptForUpdate(context, _apiService);
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMoreDocuments();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
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

  Future<void> _createFolder() async {
    String? folderName;
    await showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            _controller.currentFolderId == null ? 'Create New Project' : 'Create Sub-Folder',
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Folder name...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                folderName = controller.text.trim();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Create', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (folderName != null && folderName!.isNotEmpty) {
      try {
        await _controller.createFolder(folderName!);
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

      try {
        await _controller.uploadDocument(file.name, file.bytes!);
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
      }
    }
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final bytes = await _controller.downloadDocument(doc.id);

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
      await _controller.toggleLock(doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateDocument(DocumentModel doc) async {
    if (doc.lockedBy != _controller.currentUserId) {
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

      String? updateNote;
      bool proceed = false;
      if (!mounted) return;

      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Upload New Version', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'What changed in this version?',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
              ElevatedButton(
                onPressed: () {
                  updateNote = controller.text.trim();
                  proceed = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text('Upload', style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          );
        },
      );

      if (!proceed) return;

      try {
        await _controller.updateDocumentVersion(doc.id, file.name, file.bytes!, note: updateNote);
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
      final history = await _controller.getVersionHistory(doc.id);
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
        backgroundColor: AppColors.surface,
        title: Text('Version History: ${doc.title}', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: history.isEmpty
              ? const Center(child: Text('No version history', style: TextStyle(color: AppColors.textSecondary)))
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
                        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Version ${version.versionNumber}', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                  if (version.pinned) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.push_pin, size: 14, color: Colors.amberAccent),
                                  ],
                                ],
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('CURRENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(version.fileName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          if (version.note != null && version.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Note: ${version.note}', style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(version.uploadedAt?.replaceAll('T', ' ').substring(0, 16) ?? 'Unknown time', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _downloadSpecificVersion(doc.id, version.id, version.fileName),
                                icon: const Icon(Icons.download, size: 14),
                                label: const Text('Download', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero),
                              ),
                              const SizedBox(width: 12),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _toggleVersionPin(doc, version);
                                },
                                icon: Icon(version.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 14),
                                label: Text(version.pinned ? 'Unpin' : 'Pin', style: const TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent, padding: EdgeInsets.zero, minimumSize: Size.zero),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: GoogleFonts.inter(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Future<void> _downloadSpecificVersion(int docId, int versionId, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading version...')));
      final bytes = await _controller.downloadSpecificVersion(docId, versionId);
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

  Future<void> _toggleVersionPin(DocumentModel doc, DocumentVersionModel version) async {
    try {
      if (version.pinned) {
        await _controller.unpinVersion(doc.id, version.id);
      } else {
        await _controller.pinVersion(doc.id, version.id);
      }
      if (mounted) {
        // ignore: use_build_context_synchronously
        await _showVersionHistory(doc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _rollbackVersion(DocumentModel doc, DocumentVersionModel version) async {
    try {
      await _controller.rollbackVersion(doc, version);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rolled back successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rollback failed: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _deleteFolder(FolderModel folder) async {
    try {
      await _controller.deleteFolder(folder);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _restoreFolder(FolderModel folder) async {
    try {
      await _controller.restoreFolder(folder);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    try {
      await _controller.deleteDocument(doc);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _restoreDocument(DocumentModel doc) async {
    try {
      await _controller.restoreDocument(doc);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  List<Widget> _buildGroupedDocuments(DashboardController controller) {
    final documentCards = <Widget>[];

    if (widget.isTrashMode) {
      // Trash is about finding something to restore, not browsing by upload
      // date - keep it as a flat list.
      for (final doc in controller.documents) {
        documentCards.add(_buildDocumentCard(controller, doc));
      }
      return documentCards;
    }

    String? lastLabel;
    for (final doc in controller.documents) {
      final label = _dateGroupLabel(doc.createdAt);
      if (label != lastLabel) {
        documentCards.add(_buildDateHeader(label));
        lastLabel = label;
      }
      documentCards.add(_buildDocumentCard(controller, doc));
    }
    return documentCards;
  }

  Widget _buildDocumentCard(DashboardController controller, DocumentModel doc) {
    return DocumentCard(
      doc: doc,
      isTrashMode: widget.isTrashMode,
      currentUserId: controller.currentUserId,
      onTap: () => _previewDocument(doc),
      onToggleLock: () => _toggleLock(doc),
      onUploadVersion: () => _updateDocument(doc),
      onShowHistory: () => _showVersionHistory(doc),
      onDownload: () => _downloadDocument(doc),
      onRestore: () => _restoreDocument(doc),
      onDelete: () => _deleteDocument(doc),
    );
  }

  String _dateGroupLabel(String? isoDate) {
    final date = isoDate != null ? DateTime.tryParse(isoDate) : null;
    if (date == null) return 'Không rõ ngày';

    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardController>.value(
      value: _controller,
      child: Consumer<DashboardController>(
        builder: (context, controller, _) {
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isMyDocuments
                            ? 'Your uploaded documents, organized by project.'
                            : 'All company documents and project folders.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
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
                              controller.setSearchQuery(value);
                            });
                          },
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search files...',
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                            filled: true,
                            fillColor: AppColors.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      if (controller.canCreateFolder(widget.userRole))
                        ElevatedButton.icon(
                          onPressed: _createFolder,
                          icon: const Icon(Icons.create_new_folder),
                          label: Text(
                            controller.currentFolderId == null ? 'New Project' : 'New Folder',
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
                        onPressed: controller.loadContent,
                        icon: const Icon(Icons.refresh),
                        label: Text('Reload', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textSecondary,
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Breadcrumbs
                  BreadcrumbBar(breadcrumbs: controller.breadcrumbs, onNavigate: controller.navigateToBreadcrumb),
                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: controller.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (controller.folders.isEmpty && controller.documents.isEmpty)
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_open, size: 64, color: AppColors.border),
                                    const SizedBox(height: 16),
                                    Text(
                                      controller.currentFolderId == null
                                          ? 'No projects yet. Create one to get started!'
                                          : 'This folder is empty.',
                                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: controller.loadContent,
                                child: ListView(
                                  controller: _scrollController,
                                  children: [
                                    ...controller.folders.map((folder) => FolderCard(
                                          folder: folder,
                                          isTrashMode: widget.isTrashMode,
                                          onTap: () => controller.navigateToFolder(folder),
                                          onRestore: () => _restoreFolder(folder),
                                          onDelete: () => _deleteFolder(folder),
                                        )),
                                    ..._buildGroupedDocuments(controller),
                                    if (controller.isFetchingMore)
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
        },
      ),
    );
  }
}
