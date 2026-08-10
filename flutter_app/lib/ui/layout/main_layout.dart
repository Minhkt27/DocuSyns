import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../pages/dashboard_page.dart';
import '../pages/settings_page.dart';
import '../pages/login_page.dart';
import '../../services/api_service.dart';
import '../widgets/sync_console.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<String> _logs = [];
  int _selectedIndex = 0;

  final String _currentRole = ApiService.currentRole ?? 'USER';
  final String _currentUserName = ApiService.currentUserName ?? 'User';

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(
          key: const ValueKey('myDocs'),
          onActivity: _addActivityLog,
          isMyDocuments: true,
          userRole: _currentRole,
        );
      case 1:
        return DashboardPage(
          key: const ValueKey('allDocs'),
          onActivity: _addActivityLog,
          isMyDocuments: false,
          userRole: _currentRole,
        );
      case 2:
        return SettingsPage(
          currentRole: _currentRole,
          currentUserName: _currentUserName,
        );
      case 3:
        return DashboardPage(
          key: const ValueKey('trash'),
          onActivity: _addActivityLog,
          isTrashMode: true,
          userRole: _currentRole,
        );
      default:
        return DashboardPage(
          onActivity: _addActivityLog,
          isMyDocuments: true,
          userRole: _currentRole,
        );
    }
  }

  void _addActivityLog(String msg) {
    setState(() {
      final timeString = DateTime.now().toLocal().toString().substring(11, 19);
      _logs.insert(0, '[$timeString] [$_currentUserName] $msg');
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'DocuSync',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                    color: _currentRole == 'ADMIN'
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : _currentRole == 'PROJECT_MANAGER'
                            ? Colors.orangeAccent.withValues(alpha: 0.15)
                            : Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _currentRole == 'ADMIN'
                            ? Icons.admin_panel_settings
                            : _currentRole == 'PROJECT_MANAGER'
                                ? Icons.manage_accounts
                                : Icons.person,
                        size: 16,
                        color: _currentRole == 'ADMIN'
                            ? Colors.redAccent
                            : _currentRole == 'PROJECT_MANAGER'
                                ? Colors.orangeAccent
                                : Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentRole,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
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
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _currentRole == 'ADMIN' ? Colors.redAccent : Colors.blueAccent,
                        child: Text(
                          _currentUserName.substring(0, 2).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentUserName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          Text(_currentRole, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        tooltip: 'Logout',
                        onPressed: () async {
                          final api = ApiService();
                          await api.logout();
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
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.white54),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _getSelectedPage(),
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
        color: isActive ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: isActive ? Colors.blueAccent : Colors.white54, size: 22),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : Colors.white54,
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
