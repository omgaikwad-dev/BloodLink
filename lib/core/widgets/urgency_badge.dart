/// Urgency badge widget - visual indicator for request urgency
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UrgencyBadge extends StatelessWidget {
  final String urgency;
  final double fontSize;
  final bool showIcon;

  const UrgencyBadge({
    super.key,
    required this.urgency,
    this.fontSize = 11,
    this.showIcon = true,
  });

  Color get _color {
    switch (urgency) {
      case 'SOS':
        return AppColors.urgencySOS;
      case 'Critical':
        return AppColors.urgencyCritical;
      case 'Urgent':
        return AppColors.urgencyUrgent;
      default:
        return AppColors.urgencyNormal;
    }
  }

  IconData get _icon {
    switch (urgency) {
      case 'SOS':
        return Icons.warning_rounded;
      case 'Critical':
        return Icons.priority_high_rounded;
      case 'Urgent':
        return Icons.access_time_filled_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_icon, size: fontSize + 2, color: _color),
            const SizedBox(width: 4),
          ],
          Text(
            urgency,
            style: TextStyle(
              color: _color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
