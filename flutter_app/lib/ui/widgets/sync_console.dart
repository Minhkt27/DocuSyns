import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class SyncConsole extends StatefulWidget {
  final List<String> fallbackLogs;

  const SyncConsole({super.key, this.fallbackLogs = const []});

  @override
  State<SyncConsole> createState() => _SyncConsoleState();
}

class _SyncConsoleState extends State<SyncConsole> {
  final ApiService _apiService = ApiService();
  List<ActivityLogModel> _logs = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLogs();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVITY LOG',
                  style: TextStyle(
                    color: Colors.white70,
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
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty && widget.fallbackLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No recent activities.',
                          style: TextStyle(color: Colors.white30, fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.isNotEmpty ? _logs.length : widget.fallbackLogs.length,
                        itemBuilder: (context, index) {
                          if (_logs.isNotEmpty) {
                            final log = _logs[index];
                            final time = DateTime.tryParse(log.createdAt)?.toLocal();
                            final timeStr = time != null ? DateFormat('HH:mm:ss').format(time) : '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '[$timeStr] User ${log.userId} ${log.action} ${log.targetType} ${log.targetId}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                widget.fallbackLogs[index],
                                style: const TextStyle(
                                  color: Colors.blueAccent,
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
