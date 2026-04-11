import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    
    // Reverse geocoding for city isn't stored as a string directly usually, 
    // but let's assume we want a formatted location or just leave it blank for now 
    // unless they have a 'city' property (which UserModel might not have natively).
    _cityController = TextEditingController(text: (user?.latitude != 0.0) ? 'Location Set' : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final user = auth.userModel;
      
      if (user != null) {
        // If we want to save changes to Firestore, we can do it here.
        // As a basic version, we will update the UserModel and push to FirestoreService
        final updatedUser = user.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        
        await FirestoreService().saveUser(updatedUser);
        // Refresh auth state to reflect changes locally if needed
        // but listening to Firestore doc stream usually handles this natively.
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Account Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          Text('Personal Information', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 16),
          _buildTextField('Full Name', _nameController, icon: Icons.person_rounded),
          const SizedBox(height: 16),
          // Email is usually read-only unless we handle Firebase Auth email update
          _buildTextField('Email Address', _emailController, readOnly: true, icon: Icons.email_rounded),
          const SizedBox(height: 16),
          _buildTextField('Phone Number', _phoneController, icon: Icons.phone_rounded),
          const SizedBox(height: 32),
          Text('Location Preferences', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.info)),
          const SizedBox(height: 16),
          _buildTextField('Primary Location', _cityController, readOnly: true, icon: Icons.location_on_rounded),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false, IconData? icon}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: GoogleFonts.inter(color: readOnly ? Colors.white60 : Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
        filled: true,
        fillColor: readOnly ? AppColors.bgDark : AppColors.bgCardLight,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
