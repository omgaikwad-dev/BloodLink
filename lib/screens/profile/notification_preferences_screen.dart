import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool pushEnabled = true;
  bool smsEnabled = true;
  bool emailEnabled = false;
  bool emergencyAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSwitch('Push Notifications', 'Receive real-time alerts on your device', pushEnabled, (v) => setState(() => pushEnabled = v)),
          const Divider(color: AppColors.border, height: 32),
          _buildSwitch('SMS Alerts', 'Get critical blood requests via SMS', smsEnabled, (v) => setState(() => smsEnabled = v)),
          const Divider(color: AppColors.border, height: 32),
          _buildSwitch('Email Newsletters', 'Weekly reports and health tips', emailEnabled, (v) => setState(() => emailEnabled = v)),
          const Divider(color: AppColors.border, height: 32),
          _buildSwitch('Emergency Overrides', 'Allow critical alerts to bypass Do Not Disturb', emergencyAlerts, (v) => setState(() => emergencyAlerts = v), color: AppColors.error),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, Function(bool) onChanged, {Color? color}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
      value: value,
      activeThumbColor: color ?? AppColors.primary,
      onChanged: onChanged,
    );
  }
}
