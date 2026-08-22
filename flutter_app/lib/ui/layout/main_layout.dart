import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../pages/dashboard_page.dart';
import '../pages/settings_page.dart';
import '../pages/login_page.dart';
import '../../services/auth_session.dart';
import '../../services/sidecar_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/sync_console.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<String> _logs = [];
  int _selectedIndex = 0;

  Widget _getSelectedPage(String currentRole) {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(
          key: const ValueKey('myDocs'),
          onActivity: _addActivityLog,
          isMyDocuments: true,
          userRole: currentRole,
        );
      case 1:
        return DashboardPage(
          key: const ValueKey('allDocs'),
          onActivity: _addActivityLog,
          isMyDocuments: false,
          userRole: currentRole,
        );
      case 2:
        return const SettingsPage();
      case 3:
        return DashboardPage(
          key: const ValueKey('trash'),
          onActivity: _addActivityLog,
          isTrashMode: true,
          userRole: currentRole,
        );
      default:
        return DashboardPage(
          onActivity: _addActivityLog,
          isMyDocuments: true,
          userRole: currentRole,
        );
    }
  }

  void _addActivityLog(String msg) {
    setState(() {
      final timeString = DateTime.now().toLocal().toString().substring(11, 19);
      final userName = context.read<AuthSession>().userName ?? 'User';
      _logs.insert(0, '[$timeString] [$userName] $msg');
    });
  }

  @override
  void initState() {
    super.initState();
    // Resumes local-folder sync (if configured) for a fresh login or an
    // app restart with a persisted session - both land here.
    SidecarService.instance.startIfConfigured(context.read<AuthSession>()).catchError((e) {
      debugPrint('SidecarService: failed to start: $e');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final currentRole = session.role ?? 'USER';
    final currentUserName = session.userName ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_sync, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'DocuSync',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _buildNavItem(Icons.folder_special, 'My Documents', 0),
                _buildNavItem(Icons.folder_copy, 'All Documents', 1),
                _buildNavItem(Icons.delete_outline, 'Trash', 3),
                _buildNavItem(Icons.settings, 'Settings', 2),
                const Spacer(),
                // Role indicator
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentRole == 'ADMIN'
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : currentRole == 'PROJECT_MANAGER'
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentRole == 'ADMIN'
                            ? Icons.admin_panel_settings
                            : currentRole == 'PROJECT_MANAGER'
                                ? Icons.manage_accounts
                                : Icons.person,
                        size: 16,
                        color: currentRole == 'ADMIN'
                            ? AppColors.danger
                            : currentRole == 'PROJECT_MANAGER'
                                ? AppColors.warning
                                : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentRole,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // User Profile
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: currentRole == 'ADMIN' ? AppColors.danger : AppColors.primary,
                        child: Text(
                          currentUserName.substring(0, 2).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentUserName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          Text(currentRole, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                        tooltip: 'Logout',
                        onPressed: () async {
                          await SidecarService.instance.stop();
                          await session.logout();
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _getSelectedPage(currentRole),
                ),
              ],
            ),
          ),

          // Activity Log Panel
          Container(
            width: 320,
            margin: const EdgeInsets.all(16),
            child: SyncConsole(fallbackLogs: _logs),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    bool isActive = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: isActive ? AppColors.primary : AppColors.textSecondary, size: 22),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
