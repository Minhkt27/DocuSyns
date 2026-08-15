import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';

/// Lets the user browse the server's folder tree and pick one project
/// folder to sync locally. Returns the selected [FolderModel] via
/// Navigator.pop, or null if the user closed the dialog without choosing.
class ServerFolderPickerDialog extends StatefulWidget {
  final ApiService apiService;

  const ServerFolderPickerDialog({super.key, required this.apiService});

  @override
  State<ServerFolderPickerDialog> createState() => _ServerFolderPickerDialogState();
}

class _ServerFolderPickerDialogState extends State<ServerFolderPickerDialog> {
  final List<FolderModel> _breadcrumbs = [];
  List<FolderModel> _folders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? get _currentParentId => _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final folders = await widget.apiService.getFolders(parentId: _currentParentId);
      if (mounted) setState(() => _folders = folders);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _drillInto(FolderModel folder) {
    setState(() => _breadcrumbs.add(folder));
    _load();
  }

  void _goToBreadcrumb(int index) {
    setState(() {
      if (index < 0) {
        _breadcrumbs.clear();
      } else {
        _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
              child: Row(
                children: [
                  const Icon(Icons.folder_shared, color: Colors.purpleAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose a project folder to sync',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _goToBreadcrumb(-1),
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
                    final isLast = entry.key == _breadcrumbs.length - 1;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.chevron_right, size: 16, color: Colors.white38),
                        ),
                        InkWell(
                          onTap: () => _goToBreadcrumb(entry.key),
                          child: Text(
                            entry.value.name,
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
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
                        )
                      : _folders.isEmpty
                          ? const Center(
                              child: Text('No subfolders here', style: TextStyle(color: Colors.white38)),
                            )
                          : ListView.builder(
                              itemCount: _folders.length,
                              itemBuilder: (context, index) {
                                final folder = _folders[index];
                                return ListTile(
                                  leading: const Icon(Icons.folder, color: Colors.amber),
                                  title: Text(folder.name, style: const TextStyle(color: Colors.white)),
                                  onTap: () => _drillInto(folder),
                                  trailing: TextButton(
                                    onPressed: () => Navigator.pop(context, folder),
                                    child: Text(
                                      'Chọn',
                                      style: GoogleFonts.inter(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
