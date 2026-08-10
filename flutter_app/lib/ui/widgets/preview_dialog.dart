import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class PreviewDialog extends StatefulWidget {
  final DocumentModel document;
  final ApiService apiService;
  final VoidCallback onDownload;

  const PreviewDialog({
    Key? key,
    required this.document,
    required this.apiService,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog> {
  bool _isLoading = true;
  Uint8List? _fileBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      if (!_isSupported(widget.document.title)) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final bytes = await widget.apiService.downloadDocument(widget.document.id);
      setState(() {
        _fileBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isSupported(String fileName) {
    final ext = _getExtension(fileName);
    return ['png', 'jpg', 'jpeg', 'gif', 'webp', 'txt', 'csv', 'md', 'json'].contains(ext);
  }

  String _getExtension(String fileName) {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Text('Error loading preview: $_error', style: const TextStyle(color: Colors.redAccent)),
      );
    }
    
    final ext = _getExtension(widget.document.title);
    
    // Image Preview
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext) && _fileBytes != null) {
      return InteractiveViewer(
        minScale: 0.1,
        maxScale: 5.0,
        child: Image.memory(
          _fileBytes!,
          fit: BoxFit.contain,
        ),
      );
    }
    
    // Text Preview
    if (['txt', 'csv', 'md', 'json'].contains(ext) && _fileBytes != null) {
      String textContent = '';
      try {
        textContent = utf8.decode(_fileBytes!);
      } catch (e) {
        textContent = 'Error decoding text file: $e';
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF0F172A),
        child: SingleChildScrollView(
          child: Text(
            textContent,
            style: GoogleFonts.firaCode(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    
    // Unsupported / Fallback
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 24),
          Text(
            'Preview not supported',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Cannot preview .${ext.toUpperCase()} files.\nPlease download the file to view its contents.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.onDownload,
            icon: const Icon(Icons.download),
            label: const Text('Download Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.document.title,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.blueAccent),
                    tooltip: 'Download',
                    onPressed: widget.onDownload,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
