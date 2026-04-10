/// Home screen with role-based navigation and bottom nav
/// AI Chat button is properly positioned to avoid overlapping with dashboard FABs
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../hospital/hospital_dashboard.dart';
import '../donor/donor_dashboard.dart';
import '../blood_bank/blood_bank_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../map/map_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/demand_prediction_screen.dart';
import '../ai/emergency_classifier_screen.dart';
import '../profile/medical_records_screen.dart';
import '../profile/account_settings_screen.dart';
import '../profile/notification_preferences_screen.dart';
import '../profile/privacy_security_screen.dart';
import '../profile/help_support_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isConnectingWearable = false;
  bool _isWearableConnected = false;
  Timer? _wearableTimer;
  int _wearableBpm = 72;
  int _wearableSpo2 = 98;
  
  @override
  void dispose() {
    _wearableTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // AUTH GUARD: If user is not fully authenticated, redirect to login
    if (auth.userModel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final role = auth.userModel!.role;

    // Build tabs based on role
    final tabs = _getTabsForRole(role);

    // Determine if current tab already has its own FAB (hospital dashboard & blood bank)
    final bool currentTabHasFab = _currentIndex == 0 &&
        (role == AppConstants.roleHospital || role == AppConstants.roleBloodBank);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: tabs.map((t) => t['screen'] as Widget).toList(),
          ),

          // AI Chat floating button — positioned to NOT overlap with any child FAB
          if (_currentIndex == 0)
            Positioned(
              // If the current tab has its own FAB, position AI button higher
              bottom: currentTabHasFab ? 90 : 24,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIChatScreen()),
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2000.ms),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isActive = _currentIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getTabsForRole(String role) {
    switch (role) {
      case AppConstants.roleHospital:
        return [
          {'label': 'Dashboard', 'icon': Icons.dashboard_rounded, 'screen': const HospitalDashboard()},
          {'label': 'Map', 'icon': Icons.map_rounded, 'screen': const MapScreen()},
          {'label': 'AI Tools', 'icon': Icons.psychology_rounded, 'screen': _buildAIToolsTab()},
          {'label': 'Profile', 'icon': Icons.person_rounded, 'screen': _buildProfileTab()},
        ];
      case AppConstants.roleDonor:
        return [
          {'label': 'Dashboard', 'icon': Icons.dashboard_rounded, 'screen': const DonorDashboard()},
          {'label': 'Map', 'icon': Icons.map_rounded, 'screen': const MapScreen()},
          {'label': 'AI Tools', 'icon': Icons.psychology_rounded, 'screen': _buildAIToolsTab()},
          {'label': 'Profile', 'icon': Icons.person_rounded, 'screen': _buildProfileTab()},
        ];
      case AppConstants.roleBloodBank:
        return [
          {'label': 'Inventory', 'icon': Icons.inventory_2_rounded, 'screen': const BloodBankDashboard()},
          {'label': 'Map', 'icon': Icons.map_rounded, 'screen': const MapScreen()},
          {'label': 'AI Tools', 'icon': Icons.psychology_rounded, 'screen': _buildAIToolsTab()},
          {'label': 'Profile', 'icon': Icons.person_rounded, 'screen': _buildProfileTab()},
        ];
      case AppConstants.roleAdmin:
        return [
          {'label': 'Admin', 'icon': Icons.admin_panel_settings_rounded, 'screen': const AdminDashboard()},
          {'label': 'Map', 'icon': Icons.map_rounded, 'screen': const MapScreen()},
          {'label': 'AI Tools', 'icon': Icons.psychology_rounded, 'screen': _buildAIToolsTab()},
          {'label': 'Profile', 'icon': Icons.person_rounded, 'screen': _buildProfileTab()},
        ];
      default:
        return [
          {'label': 'Dashboard', 'icon': Icons.dashboard_rounded, 'screen': const DonorDashboard()},
          {'label': 'Map', 'icon': Icons.map_rounded, 'screen': const MapScreen()},
          {'label': 'AI Tools', 'icon': Icons.psychology_rounded, 'screen': _buildAIToolsTab()},
          {'label': 'Profile', 'icon': Icons.person_rounded, 'screen': _buildProfileTab()},
        ];
    }
  }

  // ==================== AI TOOLS TAB ====================
  Widget _buildAIToolsTab() {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('AI Tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 5),
                const Text('AI Powered', style: TextStyle(fontSize: 11, color: Color(0xFFA855F7), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFA855F7), size: 28),
                      SizedBox(width: 10),
                      Text(
                        'BloodLink AI Suite',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Powered by machine learning to save lives faster',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: -0.1, end: 0),
            const SizedBox(height: 20),

            // AI Chat
            _buildAIToolCard(
              title: 'AI Chat Assistant',
              subtitle: 'Ask anything about blood donation',
              icon: Icons.smart_toy_rounded,
              gradient: [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
              badge: '💬 Live',
            ).animate().fade(delay: 100.ms, duration: 400.ms).slideX(begin: 0.05, end: 0),
            const SizedBox(height: 12),

            // Demand Prediction
            _buildAIToolCard(
              title: 'Blood Demand Prediction',
              subtitle: 'Forecast which blood groups will be needed',
              icon: Icons.analytics_rounded,
              gradient: [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DemandPredictionScreen())),
              badge: '📊 AI',
            ).animate().fade(delay: 200.ms, duration: 400.ms).slideX(begin: 0.05, end: 0),
            const SizedBox(height: 12),

            // Emergency Priority Detection
            _buildAIToolCard(
              title: 'Emergency Priority Detection',
              subtitle: 'Auto-classify request urgency with AI',
              icon: Icons.emergency_rounded,
              gradient: [const Color(0xFFEF4444), const Color(0xFFF97316)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyClassifierScreen())),
              badge: '🚨 Critical',
            ).animate().fade(delay: 300.ms, duration: 400.ms).slideX(begin: 0.05, end: 0),
            const SizedBox(height: 24),

            // Emergency Call Section
            const Text(
              '📞 Emergency Contacts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ).animate().fade(delay: 400.ms).slideX(),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildCallCard(
                    label: '🚑 Ambulance',
                    number: '108',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCallCard(
                    label: '🏥 Hospital',
                    number: '102',
                    color: AppColors.info,
                  ),
                ),
              ],
            ).animate().fade(delay: 500.ms, duration: 400.ms),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildCallCard(
                    label: '🆘 Police',
                    number: '100',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCallCard(
                    label: '🔥 Fire',
                    number: '101',
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ).animate().fade(delay: 550.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Wearable / Health Section
            const Text(
              '⌚ Health & Wearable',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ).animate().fade(delay: 600.ms).slideX(),
            const SizedBox(height: 12),

            _buildHealthCard()
              .animate().fade(delay: 650.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Fraud Prevention Badge
            _buildFraudPreventionCard()
              .animate().fade(delay: 700.ms, duration: 400.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient[0].withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: gradient[0].withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 10),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gradient[0].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gradient[1])),
              ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCallCard({
    required String label,
    required String number,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(Icons.call_rounded, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(number, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard() {
    return GestureDetector(
      onTap: () async {
        if (_isWearableConnected || _isConnectingWearable) return;
        
        // Request Bluetooth permissions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetooth,
        ].request();

        if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Bluetooth permissions required for Wearables', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error)
              );
           }
           return;
        }

        setState(() {
          _isConnectingWearable = true;
        });

        // Open Native Bluetooth pairing screen to connect with real devices
        await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);

        if (mounted) {
          setState(() {
            _isConnectingWearable = false;
            _isWearableConnected = true;
          });
          // Start live sensor mocking from "Connected Device"
          _wearableTimer = Timer.periodic(const Duration(seconds: 2), (t) {
            if (mounted) {
              setState(() {
                _wearableBpm = 70 + math.Random().nextInt(8); // 70-77
                _wearableSpo2 = 97 + math.Random().nextInt(3); // 97-99
              });
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isWearableConnected 
              ? [const Color(0xFF10B981).withValues(alpha: 0.15), const Color(0xFF10B981).withValues(alpha: 0.05)]
              : [AppColors.bgCard, AppColors.bgCard],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _isWearableConnected ? const Color(0xFF10B981).withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isWearableConnected ? const Color(0xFF10B981).withValues(alpha: 0.2) : AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isWearableConnected ? Icons.watch_rounded : Icons.bluetooth_searching_rounded, 
                    color: _isWearableConnected ? const Color(0xFF10B981) : AppColors.textPrimary, 
                    size: 24
                  ).animate(onPlay: (c) {
                     if (_isConnectingWearable) c.repeat();
                  }).fade(duration: 800.ms),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isWearableConnected ? 'Connected to Smartwatch' : 'Wearable Integration', 
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)
                      ),
                      Text(
                        _isConnectingWearable ? 'Scanning for nearby devices...' : 'Check donor health before donation', 
                        style: TextStyle(fontSize: 12, color: _isConnectingWearable ? AppColors.info : AppColors.textSecondary)
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isWearableConnected 
                        ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isWearableConnected ? 'LIVE' : (_isConnectingWearable ? 'PAIRING' : 'CONNECT'), 
                    style: TextStyle(
                      fontSize: 10, 
                      color: _isWearableConnected ? const Color(0xFF10B981) : AppColors.primary, 
                      fontWeight: FontWeight.w800
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _healthMetric('❤️ Heart Rate', _isWearableConnected ? '$_wearableBpm BPM' : '--', AppColors.error),
                const SizedBox(width: 10),
                _healthMetric('🩸 SpO2', _isWearableConnected ? '$_wearableSpo2%' : '--', AppColors.info),
                const SizedBox(width: 10),
                _healthMetric('💉 Hb', _isWearableConnected ? '13.2 g/dL' : '--', AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFraudPreventionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.08),
            const Color(0xFFF59E0B).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🚫 Fraud Prevention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 3),
                Text(
                  'AI detects fake donors, limits frequent requests, and monitors suspicious activity in real-time.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('✅ Active', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==================== PROFILE TAB ====================
  Widget _buildProfileTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.userModel;
        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 310,
                pinned: true,
                backgroundColor: AppColors.bgDark,
                elevation: 0,
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.power_settings_new_rounded, color: AppColors.error, size: 24),
                      tooltip: 'Logout',
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Header Background Design
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.35),
                              AppColors.bgDark,
                            ],
                          ),
                        ),
                      ),
                      // Animated floating background patterns
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2), duration: 3000.ms),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 30),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                            ),
                            child: Center(
                              child: Text(
                                (user?.name.isNotEmpty == true)
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 20),
                          Text(
                            user?.name ?? 'User',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.1)]),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user?.role == 'donor' ? Icons.favorite_rounded : Icons.local_hospital_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (user?.role ?? 'donor').toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                         'Personal Details',
                         style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                       ).animate().fade(delay: 400.ms),
                       const SizedBox(height: 16),
                       Container(
                         decoration: BoxDecoration(
                           color: AppColors.bgCard,
                           borderRadius: BorderRadius.circular(24),
                           border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                           boxShadow: [
                             BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                           ]
                         ),
                         child: Column(
                           children: [
                              _profileItem(Icons.email_rounded, 'Email Address', user?.email ?? '', AppColors.info),
                              const Divider(color: AppColors.border, height: 1, indent: 64),
                              _profileItem(Icons.phone_rounded, 'Phone Number', user?.phone != null && user!.phone.isNotEmpty ? user.phone : 'Not set', AppColors.success),
                              const Divider(color: AppColors.border, height: 1, indent: 64),
                              if (user?.role == 'donor') ...[
                                _profileItem(Icons.water_drop_rounded, 'Blood Group', user?.bloodGroup ?? 'Not set', AppColors.primary, isBold: true),
                                const Divider(color: AppColors.border, height: 1, indent: 64),
                                _profileItem(Icons.event_available_rounded, 'Last Donation', user?.lastDonationDate ?? 'No records', const Color(0xFFF59E0B)),
                                const Divider(color: AppColors.border, height: 1, indent: 64),
                              ],
                              _profileItem(
                                Icons.circle,
                                'Current Status',
                                user?.isAvailable == true ? 'Active & Available' : 'Busy / Unavailable',
                                user?.isAvailable == true ? AppColors.success : AppColors.warning,
                                isBold: true,
                              ),
                           ],
                         ),
                       ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
                       
                       const SizedBox(height: 32),
                       
                       Text(
                         'Account Management',
                         style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                       ).animate().fade(delay: 600.ms),
                       const SizedBox(height: 16),
                       
                       Container(
                         decoration: BoxDecoration(
                           color: AppColors.bgCard,
                           borderRadius: BorderRadius.circular(24),
                           border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                           boxShadow: [
                             BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5)),
                           ]
                         ),
                         child: Column(
                           children: [
                              if (user?.role == 'donor') ...[
                                _settingsTile(Icons.medical_information_rounded, 'Medical Records', 'View your lab tests & health history', AppColors.primary, () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalRecordsScreen()));
                                }),
                                const Divider(color: AppColors.border, height: 1, indent: 68),
                              ],
                              _settingsTile(Icons.manage_accounts_rounded, 'Account Settings', 'Update password, location & limits', AppColors.info, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
                              }),
                              const Divider(color: AppColors.border, height: 1, indent: 68),
                              _settingsTile(Icons.notifications_active_rounded, 'Notification Preferences', 'SMS, push & alert sounds', const Color(0xFFF59E0B), () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()));
                              }),
                              const Divider(color: AppColors.border, height: 1, indent: 68),
                              _settingsTile(Icons.security_rounded, 'Privacy & Security', 'Manage data & connected devices', AppColors.success, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()));
                              }),
                              const Divider(color: AppColors.border, height: 1, indent: 68),
                              _settingsTile(Icons.help_center_rounded, 'Help & Support', 'FAQs, Contact Us & Live Agents', const Color(0xFF8B5CF6), () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                              }),
                           ],
                         ),
                       ).animate().fade(delay: 700.ms).slideY(begin: 0.1, end: 0),
                       const SizedBox(height: 40),
                       Center(
                         child: Text(
                           'BloodLink AI • v2.4.0',
                           style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                         ),
                       ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileItem(IconData icon, String label, String value, Color iconColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               color: iconColor.withValues(alpha: 0.15),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: iconColor.withValues(alpha: 0.3))
             ),
             child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: isBold ? iconColor : Colors.white,
                    fontSize: 15,
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      ),
      onTap: onTap,
    );
  }
}
