import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

import 'package:app_settings/app_settings.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricEnabled = false;

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Change Password', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Current Password', labelStyle: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 10),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'New Password', labelStyle: const TextStyle(color: AppColors.textSecondary))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: AppColors.success));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManageDevices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCardLight,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Sessions', style: GoogleFonts.outfit(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.smartphone_rounded, color: AppColors.success),
              title: Text('Current Device', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Android - Active Now', style: GoogleFonts.inter(color: AppColors.success)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.laptop_mac_rounded, color: AppColors.textMuted),
              title: Text('Chrome Desktop', style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text('Logged in 2 days ago', style: GoogleFonts.inter(color: AppColors.textMuted)),
              trailing: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Revoke', style: TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Account?', style: GoogleFonts.outfit(color: AppColors.error)),
        content: Text('This action is completely irreversible. All your medical data and associations will be wiped.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion requested. Support will contact you.'), backgroundColor: AppColors.warning));
            },
            child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Privacy & Security', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildActionItem(Icons.lock_rounded, 'Change Password', 'Update your login credentials', _showChangePasswordDialog),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.success),
              title: Text('Biometric Login', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('Enable Face ID or Fingerprint', style: GoogleFonts.inter(color: AppColors.textMuted)),
              value: _biometricEnabled,
              activeThumbColor: AppColors.success,
              onChanged: (val) async {
                setState(() => _biometricEnabled = val);
                if (val) await AppSettings.openAppSettings(type: AppSettingsType.security);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildActionItem(Icons.devices_rounded, 'Manage Devices', 'View active device sessions', _showManageDevices),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _showDeleteAccountConfirm,
            child: Text('Delete Account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
          )
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.success),
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      ),
    );
  }
}
