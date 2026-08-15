import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/api_service.dart';

class FolderCard extends StatelessWidget {
  final FolderModel folder;
  final bool isTrashMode;
  final VoidCallback? onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    required this.isTrashMode,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
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
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    folder.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                if (!isTrashMode) const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
