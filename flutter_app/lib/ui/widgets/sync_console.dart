import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/websocket_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class SyncConsole extends StatefulWidget {
  final List<String> fallbackLogs;

  const SyncConsole({super.key, this.fallbackLogs = const []});

  @override
  State<SyncConsole> createState() => _SyncConsoleState();
}

class _SyncConsoleState extends State<SyncConsole> {
  late final ApiService _apiService;
  final WebSocketService _wsService = WebSocketService();
  List<ActivityLogModel> _logs = [];
  final List<String> _liveSyncMessages = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context.read<AuthSession>());
    _fetchLogs();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLogs();
    });
    _wsService.connect((message) {
      if (!mounted) return;
      setState(() {
        _liveSyncMessages.insert(0, message);
        if (_liveSyncMessages.length > 20) {
          _liveSyncMessages.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      final logs = await _apiService.getRecentActivities();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVITY LOG',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _logs.isEmpty && _liveSyncMessages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty && widget.fallbackLogs.isEmpty && _liveSyncMessages.isEmpty
                    ? const Center(
                        child: Text(
                          'No recent activities.',
                          style: TextStyle(color: AppColors.textMuted, fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _liveSyncMessages.length +
                            (_logs.isNotEmpty ? _logs.length : widget.fallbackLogs.length),
                        itemBuilder: (context, index) {
                          if (index < _liveSyncMessages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '⇪ ${_liveSyncMessages[index]}',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                          final i = index - _liveSyncMessages.length;
                          if (_logs.isNotEmpty) {
                            final log = _logs[i];
                            final time = DateTime.tryParse(log.createdAt)?.toLocal();
                            final timeStr = time != null ? DateFormat('HH:mm:ss').format(time) : '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '[$timeStr] ${log.userName} ${log.action} "${log.targetName ?? '${log.targetType} #${log.targetId}'}"',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                widget.fallbackLogs[i],
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
