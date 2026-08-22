import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final bool isTrashMode;
  final int? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback onToggleLock;
  final VoidCallback onUploadVersion;
  final VoidCallback onShowHistory;
  final VoidCallback onDownload;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.doc,
    required this.isTrashMode,
    required this.currentUserId,
    required this.onTap,
    required this.onToggleLock,
    required this.onUploadVersion,
    required this.onShowHistory,
    required this.onDownload,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    bool isLocked = doc.lockedBy != null;
    String lockStatusText = 'Available';
    if (isLocked) {
      if (doc.lockedBy == currentUserId) {
        lockStatusText = 'Locked by you';
      } else {
        lockStatusText = 'Locked by ${doc.lockedByName ?? "User ${doc.lockedBy}"}';
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isTrashMode ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description, color: AppColors.primary, size: 22),
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
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildBadge(doc.documentCode, AppColors.surfaceAlt, AppColors.textSecondary),
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
                if (!isTrashMode) ...[
                  ElevatedButton.icon(
                    onPressed: onToggleLock,
                    icon: Icon(isLocked ? Icons.lock_open : Icons.lock, size: 14),
                    label: Text(
                      isLocked ? 'Unlock' : 'Lock',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLocked ? Colors.redAccent : Colors.transparent,
                      foregroundColor: isLocked ? Colors.white : AppColors.textSecondary,
                      side: isLocked ? BorderSide.none : const BorderSide(color: AppColors.border),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.upload_file, color: Colors.orangeAccent, size: 20),
                    tooltip: 'Upload new version',
                    onPressed: onUploadVersion,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.purpleAccent, size: 20),
                    tooltip: 'Version history',
                    onPressed: onShowHistory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: AppColors.primary, size: 20),
                    tooltip: 'Download',
                    onPressed: onDownload,
                  ),
                ],
                if (isTrashMode)
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.greenAccent, size: 20),
                    tooltip: 'Restore',
                    onPressed: onRestore,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Move to Trash',
                    onPressed: onDelete,
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
}
