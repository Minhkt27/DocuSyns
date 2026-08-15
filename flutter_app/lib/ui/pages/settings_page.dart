import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/sidecar_service.dart';
import '../widgets/server_folder_picker_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoadingSettings = false;

  final _maxVersionsController = TextEditingController();
  final _trashRetentionController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _appUrlController = TextEditingController();

  String? _syncFolderPath;
  bool _isUpdatingSync = false;

  final _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    if (session.role == 'ADMIN') {
      _loadSettings();
    }
    _loadSyncFolder();
    _serverUrlController.text = session.baseUrl;
  }

  Future<void> _saveServerUrl() async {
    final session = context.read<AuthSession>();
    await session.setBaseUrl(_serverUrlController.text);
    _serverUrlController.text = session.baseUrl;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server address saved. Log out and back in for it to take full effect.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadSyncFolder() async {
    final path = await SidecarService.instance.getSyncFolderPath();
    if (mounted) setState(() => _syncFolderPath = path);
  }

  Future<void> _pickSyncFolder() async {
    final session = context.read<AuthSession>();
    final selected = await FilePicker.platform.getDirectoryPath();
    if (selected == null) return;
    if (!mounted) return;

    final apiService = ApiService(session);
    final serverFolder = await showDialog<FolderModel>(
      context: context,
      builder: (_) => ServerFolderPickerDialog(apiService: apiService),
    );
    if (serverFolder == null) return;

    setState(() => _isUpdatingSync = true);
    try {
      await SidecarService.instance.setSyncFolder(selected, serverFolder.id);
      await SidecarService.instance.start(selected, serverFolder.id, session);
      if (mounted) {
        setState(() => _syncFolderPath = selected);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Syncing "${serverFolder.name}" - downloading existing files...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start sync: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingSync = false);
    }
  }

  Future<void> _stopSync() async {
    setState(() => _isUpdatingSync = true);
    try {
      await SidecarService.instance.stop();
      await SidecarService.instance.setSyncFolder(null, null);
      if (mounted) setState(() => _syncFolderPath = null);
    } finally {
      if (mounted) setState(() => _isUpdatingSync = false);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final apiService = ApiService(context.read<AuthSession>());
      final settings = await apiService.getSettings();
      _maxVersionsController.text = settings['maxVersionsPerFile']?.toString() ?? '5';
      _trashRetentionController.text = settings['trashRetentionDays']?.toString() ?? '30';
      _appVersionController.text = settings['clientAppVersion']?.toString() ?? '';
      _appUrlController.text = settings['clientAppUrl']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final apiService = ApiService(context.read<AuthSession>());
      await apiService.updateSettings(
        int.parse(_maxVersionsController.text),
        int.parse(_trashRetentionController.text),
        clientAppVersion: _appVersionController.text.trim(),
        clientAppUrl: _appUrlController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _maxVersionsController.dispose();
    _trashRetentionController.dispose();
    _appVersionController.dispose();
    _appUrlController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = context.watch<AuthSession>().role ?? 'USER';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage system configurations and permissions.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
            ),

            const SizedBox(height: 40),
            Text(
              'SERVER CONNECTION',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: _buildTextSetting(
                label: 'Server Address',
                description: 'Base URL of the DocuSync backend, e.g. http://192.168.1.7:8080/api/v1. Changing this requires logging in again.',
                controller: _serverUrlController,
                icon: Icons.dns,
                width: 320,
                onSubmitted: (_) => _saveServerUrl(),
                trailing: IconButton(
                  icon: const Icon(Icons.save, color: Colors.blueAccent),
                  tooltip: 'Save',
                  onPressed: _saveServerUrl,
                ),
              ),
            ),

            const SizedBox(height: 40),
            Text(
              'LOCAL FOLDER SYNC',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open, color: Colors.purpleAccent, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync a local folder',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _syncFolderPath == null
                              ? 'Not configured. Files added or changed in a chosen folder are uploaded automatically.'
                              : 'Watching: $_syncFolderPath',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_isUpdatingSync)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_syncFolderPath == null)
                    ElevatedButton.icon(
                      onPressed: _pickSyncFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text('Choose Folder', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _stopSync,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: Text('Stop Syncing', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                    ),
                ],
              ),
            ),

            if (currentRole == 'ADMIN') ...[
              const SizedBox(height: 40),
              Text(
                'DATA RETENTION LIFECYCLE',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: _isLoadingSettings
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNumberSetting(
                            label: 'Max Versions Per File',
                            description: 'Old versions exceeding this limit will be automatically moved to Trash.',
                            controller: _maxVersionsController,
                            icon: Icons.layers,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          _buildNumberSetting(
                            label: 'Trash Retention (Days)',
                            description: 'Files in Trash older than this many days will be permanently deleted.',
                            controller: _trashRetentionController,
                            icon: Icons.delete_sweep,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          Text(
                            'AUTO UPDATER CONFIGURATION',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextSetting(
                            label: 'Latest Client App Version',
                            description: 'Version string (e.g., 1.0.1) that triggers auto-update on clients.',
                            controller: _appVersionController,
                            icon: Icons.new_releases,
                            width: 150,
                          ),
                          const SizedBox(height: 16),
                          _buildTextSetting(
                            label: 'Client App Download URL',
                            description: 'Direct link to the Setup.exe file for downloading the update.',
                            controller: _appUrlController,
                            icon: Icons.link,
                            width: 300,
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _saveSettings,
                              icon: const Icon(Icons.save, size: 18),
                              label: Text('Save Configurations', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildTextSetting({
    required String label,
    required String description,
    required TextEditingController controller,
    required IconData icon,
    double width = 200,
    ValueChanged<String>? onSubmitted,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.greenAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            onSubmitted: onSubmitted,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _buildNumberSetting({
    required String label,
    required String description,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
