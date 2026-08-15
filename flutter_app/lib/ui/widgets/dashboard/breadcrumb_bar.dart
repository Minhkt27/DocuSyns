import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/dashboard_controller.dart';

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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => onNavigate(-1),
            child: Text(
              'Root',
              style: GoogleFonts.inter(
                color: breadcrumbs.isEmpty ? Colors.white : Colors.blueAccent,
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
                  child: Icon(Icons.chevron_right, size: 18, color: Colors.white38),
                ),
                InkWell(
                  onTap: isLast ? null : () => onNavigate(index),
                  child: Text(
                    item.name,
                    style: GoogleFonts.inter(
                      color: isLast ? Colors.white : Colors.blueAccent,
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
