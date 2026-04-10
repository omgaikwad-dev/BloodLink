/// Blood group selector chip widget
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class BloodGroupSelector extends StatelessWidget {
  final String? selectedGroup;
  final ValueChanged<String> onSelected;
  final bool showAll;

  const BloodGroupSelector({
    super.key,
    this.selectedGroup,
    required this.onSelected,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final groups = showAll
        ? ['All', ...AppConstants.bloodGroups]
        : AppConstants.bloodGroups;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: groups.map((group) {
        final isSelected = selectedGroup == group;
        return GestureDetector(
          onTap: () => onSelected(group),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              group,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
