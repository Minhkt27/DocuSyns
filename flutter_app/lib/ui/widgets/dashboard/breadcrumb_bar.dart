import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/dashboard_controller.dart';
import '../../../theme/app_colors.dart';

class BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbItem> breadcrumbs;
  final void Function(int index) onNavigate;

  const BreadcrumbBar({
    super.key,
    required this.breadcrumbs,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => onNavigate(-1),
            child: Text(
              'Root',
              style: GoogleFonts.inter(
                color: breadcrumbs.isEmpty ? AppColors.textPrimary : AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ...breadcrumbs.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == breadcrumbs.length - 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                ),
                InkWell(
                  onTap: isLast ? null : () => onNavigate(index),
                  child: Text(
                    item.name,
                    style: GoogleFonts.inter(
                      color: isLast ? AppColors.textPrimary : AppColors.primary,
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
    );
  }
}
