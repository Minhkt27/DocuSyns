import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import '../theme/app_colors.dart';

/// Checks the server-configured latest client version against the running
/// app and, if newer, prompts the user to download and install it. Pulled
/// out of DashboardPage since app-update checking isn't a dashboard concern.
class UpdateChecker {
  static Future<void> checkAndPromptForUpdate(BuildContext context, ApiService apiService) async {
    try {
      final settings = await apiService.getSettings();
      final latestVersion = settings['clientAppVersion']?.toString() ?? '';
      final downloadUrl = settings['clientAppUrl']?.toString() ?? '';

      if (latestVersion.isEmpty || downloadUrl.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (isVersionGreater(latestVersion, currentVersion) && context.mounted) {
        _showUpdateDialog(context, latestVersion, downloadUrl);
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
  }

  static bool isVersionGreater(String latest, String current) {
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

  static void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDownloading = false;
        double progress = 0;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Update Available', style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A new version ($version) of DocuSync is available and required to continue.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                if (isDownloading) ...[
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('Downloading: ${(progress * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    setState(() => isDownloading = true);
                    await _downloadAndInstallUpdate(context, url, (p) {
                      setState(() => progress = p);
                    });
                  },
                  child: Text('Update Now', style: GoogleFonts.inter(color: Colors.white)),
                )
            ],
          );
        });
      },
    );
  }

  static Future<void> _downloadAndInstallUpdate(BuildContext context, String url, void Function(double) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}\\DocuSync_Update_${DateTime.now().millisecondsSinceEpoch}.exe';

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

      await Process.start(savePath, []);
      exit(0);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
