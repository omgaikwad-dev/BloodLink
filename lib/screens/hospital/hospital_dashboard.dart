/// Hospital Dashboard - manage requests, view donors, SOS emergency
/// Includes dedicated Ambulance Command Center with real-time tracking
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/urgency_badge.dart';
import '../../core/widgets/blood_group_selector.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/location_utils.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../models/ambulance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/demand_prediction_screen.dart';
import '../ai/emergency_classifier_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late TabController _tabController;
  Position? _hospitalPosition;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initHospitalLocation();
  }

  Future<void> _initHospitalLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() => _hospitalPosition = pos);
        // Also update hospital location in Firestore
        if (context.mounted) {
          context.read<AuthProvider>().updateLocation(pos.latitude, pos.longitude);
        }
      }
      _positionStream = Geolocator.getPositionStream().listen((Position pos) {
        if (mounted) setState(() => _hospitalPosition = pos);
      });
    } catch (e) {
      debugPrint('Hospital location error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        toolbarHeight: 60,
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? 'Hospital',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  Text('Hospital Dashboard',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // SOS icon
          GestureDetector(
            onTap: () => _showSOSDialog(context),
            child: Container(
              width: 42, height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.sosGradient),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'Ambulance'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Network'),
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAmbulanceTab(),
          _buildDonorsTab(),
          _buildRequestsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRequestDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text('Blood Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  // ===================== OVERVIEW TAB =====================
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildQuickStats().animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        _buildDonorDistribution().animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),

        // AI Quick Actions
        const Text('🧠 AI Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
            .animate().fade(delay: 320.ms).slideX(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _aiQuickAction(
            icon: Icons.smart_toy_rounded,
            label: 'AI Chat',
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
          )),
          const SizedBox(width: 10),
          Expanded(child: _aiQuickAction(
            icon: Icons.analytics_rounded,
            label: 'Demand AI',
            color: const Color(0xFF0EA5E9),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DemandPredictionScreen())),
          )),
          const SizedBox(width: 10),
          Expanded(child: _aiQuickAction(
            icon: Icons.emergency_rounded,
            label: 'Priority AI',
            color: const Color(0xFFEF4444),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyClassifierScreen())),
          )),
        ]).animate().fade(delay: 340.ms),
        const SizedBox(height: 16),

        const Text('Recent Requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
            .animate().fade(delay: 350.ms).slideX(),
        const SizedBox(height: 10),
        _buildRecentRequests().animate().fade(delay: 400.ms),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _aiQuickAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildQuickStats() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamHospitalRequests(uid),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final pending = requests.where((r) => r.status == 'pending').length;
        final active = requests.where((r) => r.isActive).length;
        final completed = requests.where((r) => r.status == 'completed').length;

        return Row(children: [
          Expanded(child: _miniStat('Pending', '$pending', Icons.schedule_rounded, AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _miniStat('Active', '$active', Icons.local_fire_department_rounded, AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: _miniStat('Done', '$completed', Icons.verified_rounded, AppColors.success)),
        ]);
      },
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildDonorDistribution() {
    return StreamBuilder<List<UserModel>>(
      stream: _fs.streamAllDonors(),
      builder: (context, snap) {
        final donors = snap.data ?? [];
        final available = donors.where((d) => d.isAvailable).length;
        final Map<String, int> groups = {};
        for (final d in donors) {
          groups[d.bloodGroup] = (groups[d.bloodGroup] ?? 0) + 1;
        }

        return GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_alt_rounded, color: AppColors.success, size: 20)),
              const SizedBox(width: 12),
              Text('${donors.length} Donors', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$available online', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: AppConstants.bloodGroups.map((bg) {
              final count = groups[bg] ?? 0;
              return Container(
                width: 68, padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: count > 0 ? AppColors.primary.withValues(alpha: 0.08) : AppColors.bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: count > 0 ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border.withValues(alpha: 0.3))),
                child: Column(children: [
                  Text(bg, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: count > 0 ? AppColors.primary : AppColors.textMuted)),
                  Text('$count', style: TextStyle(fontSize: 12, color: count > 0 ? AppColors.textPrimary : AppColors.textMuted)),
                ]),
              );
            }).toList()),
          ]),
        );
      },
    );
  }

  Widget _buildRecentRequests() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamHospitalRequests(uid),
      builder: (context, snap) {
        final reqs = (snap.data ?? []).where((r) => r.isActive).take(5).toList();
        if (reqs.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(28),
            child: Center(child: Column(children: [
              Icon(Icons.assignment_late_outlined, color: AppColors.textMuted, size: 40),
              const SizedBox(height: 10),
              Text('No active requests', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
              Text('Tap the button below to create a blood request',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
          );
        }
        return Column(children: reqs.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _compactRequestCard(r),
        )).toList());
      },
    );
  }

  Widget _compactRequestCard(BloodRequestModel req) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: req.isSOS ? AppColors.error.withValues(alpha: 0.4) : null,
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: req.isSOS
                ? [AppColors.error.withValues(alpha: 0.8), AppColors.error]
                : [AppColors.primary.withValues(alpha: 0.8), AppColors.primary]),
            borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(req.bloodGroup,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(req.hospitalName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Text('${req.units} unit(s) • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _getStatusColor(req.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(req.status.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _getStatusColor(req.status))),
            ),
            if (req.assignedDonorName != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.person_rounded, size: 12, color: AppColors.success),
              const SizedBox(width: 2),
              Expanded(child: Text(req.assignedDonorName!,
                  style: TextStyle(fontSize: 10, color: AppColors.success), overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ])),
        UrgencyBadge(urgency: req.urgency, fontSize: 10),
      ]),
    );
  }

  // ===================== AMBULANCE TAB =====================
  Widget _buildAmbulanceTab() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ambulance Command Center Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  const Color(0xFF7C3AED).withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: AppColors.info, size: 30)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ambulance Command', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Real-time dispatch & tracking center', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success))
                          .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
                      const SizedBox(width: 5),
                      Text('LIVE', style: GoogleFonts.inter(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.1, end: 0),
          const SizedBox(height: 16),

          // Ambulance Fleet Status
          _buildAmbulanceFleetStatus().animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 20),

          // Active Dispatches (requests with ambulance assigned)
          Text('🚑 Active Dispatches', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
              .animate().fade(delay: 200.ms).slideX(),
          const SizedBox(height: 12),
          _buildActiveDispatches(uid).animate().fade(delay: 250.ms),
          const SizedBox(height: 20),

          // Accepted Requests Waiting for Ambulance
          Text('🩸 Donor Accepted — Ready for Dispatch', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))
              .animate().fade(delay: 300.ms).slideX(),
          const SizedBox(height: 12),
          _buildAcceptedRequests(uid).animate().fade(delay: 350.ms),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAmbulanceFleetStatus() {
    return StreamBuilder<List<AmbulanceModel>>(
      stream: _fs.streamAvailableAmbulances(),
      builder: (context, snap) {
        final available = snap.data?.length ?? 0;
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.success.withValues(alpha: 0.12), AppColors.success.withValues(alpha: 0.04)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: AppColors.success, size: 28),
                    const SizedBox(height: 8),
                    Text('$available', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.success)),
                    Text('Available', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<BloodRequestModel>>(
                stream: _fs.streamHospitalRequests(context.read<AuthProvider>().firebaseUser?.uid ?? ''),
                builder: (context, reqSnap) {
                  final dispatched = (reqSnap.data ?? []).where((r) => r.assignedAmbulanceId != null && r.isActive).length;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.warning.withValues(alpha: 0.12), AppColors.warning.withValues(alpha: 0.04)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.speed_rounded, color: AppColors.warning, size: 28),
                        const SizedBox(height: 8),
                        Text('$dispatched', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.warning)),
                        Text('Dispatched', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<BloodRequestModel>>(
                stream: _fs.streamHospitalRequests(context.read<AuthProvider>().firebaseUser?.uid ?? ''),
                builder: (context, reqSnap) {
                  final accepted = (reqSnap.data ?? []).where((r) => r.status == 'accepted' && r.assignedDonorId != null).length;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.info.withValues(alpha: 0.12), AppColors.info.withValues(alpha: 0.04)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person_pin_circle_rounded, color: AppColors.info, size: 28),
                        const SizedBox(height: 8),
                        Text('$accepted', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.info)),
                        Text('Donors Ready', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveDispatches(String hospitalId) {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamHospitalRequests(hospitalId),
      builder: (context, snap) {
        final dispatched = (snap.data ?? []).where((r) => r.assignedAmbulanceId != null && r.isActive).toList();

        if (dispatched.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(children: [
                Icon(Icons.local_shipping_outlined, color: AppColors.textMuted, size: 40),
                const SizedBox(height: 10),
                Text('No active ambulance dispatches', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 6),
                Text('Ambulances will appear here when a donor accepts', style: TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        }

        return Column(
          children: dispatched.map((req) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ambulanceDispatchCard(req),
          )).toList(),
        );
      },
    );
  }

  Widget _ambulanceDispatchCard(BloodRequestModel req) {
    return GlassCard(
      isHighlighted: req.isSOS,
      borderColor: AppColors.info.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(req.bloodGroup, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(req.hospitalName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.info),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 600.ms),
                        const SizedBox(width: 6),
                        Text('IN TRANSIT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
                        const SizedBox(width: 8),
                        Text('${req.units} unit(s)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              UrgencyBadge(urgency: req.urgency, fontSize: 10),
            ],
          ),

          // Donor info with LIVE distance tracking
          if (req.assignedDonorId != null && req.assignedDonorName != null) ...[
            const SizedBox(height: 12),
            StreamBuilder<UserModel?>(
              stream: _fs.streamUser(req.assignedDonorId!),
              builder: (context, donorSnap) {
                final donor = donorSnap.data;
                final hospitalLat = _hospitalPosition?.latitude ?? req.latitude;
                final hospitalLng = _hospitalPosition?.longitude ?? req.longitude;
                final donorLat = donor?.latitude ?? 0;
                final donorLng = donor?.longitude ?? 0;
                final liveDistance = (donorLat != 0 && donorLng != 0)
                    ? LocationUtils.calculateDistance(hospitalLat, hospitalLng, donorLat, donorLng)
                    : null;

                return Column(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Donor: ${req.assignedDonorName}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('CONFIRMED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
                        ),
                      ],
                    ),
                  ),
                  if (liveDistance != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.info.withValues(alpha: 0.1), AppColors.info.withValues(alpha: 0.03)]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.my_location_rounded, color: AppColors.info, size: 18)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Live Distance', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(LocationUtils.formatDistance(liveDistance),
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.info)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('ETA', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(_estimateETA(liveDistance),
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ]),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.info))
                                .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                            const SizedBox(width: 4),
                            Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.info)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ]);
              },
            ),
          ],

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCompleted),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Complete', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCancelled),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedRequests(String hospitalId) {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamHospitalRequests(hospitalId),
      builder: (context, snap) {
        final accepted = (snap.data ?? []).where((r) =>
            r.status == 'accepted' && r.assignedDonorId != null && r.assignedAmbulanceId == null).toList();

        if (accepted.isEmpty) {
          return GlassCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('No accepted requests awaiting dispatch', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
          );
        }

        return Column(
          children: accepted.map((req) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                borderColor: AppColors.success.withValues(alpha: 0.3),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(req.bloodGroup, style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w800))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.hospitalName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                            Text('Donor: ${req.assignedDonorName ?? "Unknown"}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                          ],
                        )),
                        UrgencyBadge(urgency: req.urgency, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Donor accepted. Waiting for ambulance auto-dispatch...', style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ===================== NETWORK TAB =====================
  Widget _buildDonorsTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _fs.streamNetworkUsers(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final users = snap.data!;
        if (users.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_outline_rounded, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 14),
            Text('No network users found', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Donors and blood banks will appear here',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]));
        }

        final donors = users.where((u) => u.role == 'donor').toList();
        final banks = users.where((u) => u.role == 'blood_bank').toList();

        return ListView(padding: const EdgeInsets.all(16), children: [
          // Summary
          Row(children: [
            _countChip('Donors', donors.length, AppColors.success),
            const SizedBox(width: 8),
            _countChip('Banks', banks.length, AppColors.error),
            const SizedBox(width: 8),
            _countChip('Total', users.length, AppColors.info),
          ]).animate().fade(duration: 300.ms),
          const SizedBox(height: 18),

          if (banks.isNotEmpty) ...[
            _sectionHeader('Blood Banks', AppColors.error),
            const SizedBox(height: 10),
            ...banks.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _userCard(e.value).animate().fade(delay: (50 + e.key * 40).ms).slideX(begin: 0.03),
            )),
            const SizedBox(height: 16),
          ],

          if (donors.isNotEmpty) ...[
            _sectionHeader('Donors', AppColors.success),
            const SizedBox(height: 10),
            ...donors.where((d) => d.isAvailable).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _userCard(d).animate().fade(delay: 200.ms),
            )),
            ...donors.where((d) => !d.isAvailable).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _userCard(d).animate().fade(delay: 300.ms),
            )),
          ],
          const SizedBox(height: 80),
        ]);
      },
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _userCard(UserModel user) {
    final available = user.isAvailable;
    final isBank = user.role == 'blood_bank';
    
    // Generates a stable mocked heart rate for this donor based on their name length
    final mockBpm = isBank ? 0 : (70 + (user.name.length % 12)); 
    final isHealthy = mockBpm <= 80;

    return GestureDetector(
      onTap: () => _showUserDetails(context, user, isBank, mockBpm, isHealthy),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isBank 
                ? [AppColors.error, const Color(0xFFFF5252)]
                : available
                  ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                  : [AppColors.textMuted, AppColors.textMuted.withValues(alpha: 0.7)]),
            shape: BoxShape.circle,
            boxShadow: [
               BoxShadow(
                  color: (isBank ? AppColors.error : AppColors.success).withValues(alpha: 0.3),
                  blurRadius: 8
               )
            ]),
          child: Center(
            child: isBank 
              ? const Icon(Icons.maps_home_work_rounded, color: Colors.white, size: 24)
              : Text(user.bloodGroup.isNotEmpty ? user.bloodGroup : '?',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(child: Text(user.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
              if (isBank) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: AppColors.info, size: 16),
              ] else ...[
                 // AI HEALTH STATUS PILL
                 Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: isHealthy ? AppColors.info.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isHealthy ? AppColors.info.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3))
                    ),
                    child: Row(
                       children: [
                          Icon(Icons.monitor_heart_rounded, size: 10, color: isHealthy ? AppColors.info : AppColors.warning)
                            .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms, begin: const Offset(1,1), end: const Offset(1.2,1.2)),
                          const SizedBox(width: 4),
                          Text('$mockBpm BPM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isHealthy ? AppColors.info : AppColors.warning)),
                       ],
                    )
                 )
              ]
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(isBank ? Icons.store_rounded : Icons.bloodtype_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(isBank ? 'Blood Bank' : user.bloodGroup, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Icon(Icons.phone_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Expanded(child: Text(user.phone.isNotEmpty ? user.phone : 'N/A',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isBank || available ? AppColors.success.withValues(alpha: 0.1) : AppColors.bgCardLight,
            borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
                shape: BoxShape.circle, color: isBank || available ? AppColors.success : AppColors.textMuted)),
            const SizedBox(width: 4),
            Text(isBank || available ? 'Active' : 'Busy', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600,
                color: isBank || available ? AppColors.success : AppColors.textMuted)),
          ]),
        ),
      ]),
    ));
  }

  void _showUserDetails(BuildContext context, UserModel user, bool isBank, int bpm, bool isHealthy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: (isBank ? AppColors.error : AppColors.success).withValues(alpha: 0.3))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: isBank ? [AppColors.error, const Color(0xFFFF5252)] : [const Color(0xFF43A047), const Color(0xFF66BB6A)]),
                boxShadow: [BoxShadow(color: (isBank ? AppColors.error : AppColors.success).withValues(alpha: 0.4), blurRadius: 16)],
              ),
              child: Center(
                child: isBank 
                  ? const Icon(Icons.maps_home_work_rounded, color: Colors.white, size: 36)
                  : Text(user.bloodGroup.isNotEmpty ? user.bloodGroup : '?', style: GoogleFonts.outfit(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(isBank ? 'Blood Bank Facility' : 'Active Donor Participant', style: GoogleFonts.inter(fontSize: 14, color: isBank ? AppColors.error : AppColors.success, fontWeight: FontWeight.w600)),
            const SizedBox(height: 30),
            
            _userCardDetailRow(Icons.email_rounded, 'Email', user.email.isNotEmpty ? user.email : 'Not Provided'),
            const SizedBox(height: 16),
            _userCardDetailRow(Icons.phone_rounded, 'Phone', user.phone.isNotEmpty ? user.phone : 'Not Provided'),
            if (user.role == 'donor') ...[
              const SizedBox(height: 16),
              _userCardDetailRow(Icons.bloodtype_rounded, 'Blood Group', user.bloodGroup),
              const SizedBox(height: 16),
              _userCardDetailRow(Icons.monitor_heart_rounded, 'Live Vitals (Hb/SpO2/BPM)', '13.2 g/dL | 98% | $bpm BPM', valueColor: isHealthy ? AppColors.info : AppColors.warning),
              const SizedBox(height: 16),
              _userCardDetailRow(Icons.history_rounded, 'Last Donation', user.lastDonationDate ?? 'No Records'),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Contact Directly', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _userCardDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 14, color: valueColor ?? AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  // ===================== REQUESTS TAB =====================
  Widget _buildRequestsTab() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamHospitalRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.assignment_outlined, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 14),
            Text('No requests yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Create your first blood request', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateRequestDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Request'),
            ),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: requests.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _fullRequestCard(requests[i]).animate().fade(delay: (i * 60).ms).slideY(begin: 0.05),
          ),
        );
      },
    );
  }

  Widget _fullRequestCard(BloodRequestModel req) {
    return GlassCard(
      isHighlighted: req.isSOS,
      borderColor: req.isSOS ? AppColors.error.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: req.isSOS
                  ? [AppColors.error, const Color(0xFFFF5252)]
                  : [AppColors.primary, const Color(0xFFFF5252)]),
              borderRadius: BorderRadius.circular(13)),
            child: Center(child: Text(req.bloodGroup,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.hospitalName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text('${req.units} unit(s)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getStatusColor(req.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(req.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _getStatusColor(req.status))),
              ),
            ]),
          ])),
          UrgencyBadge(urgency: req.urgency, fontSize: 10),
        ]),
        if (req.notes != null && req.notes!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.bgDark.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.notes_rounded, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(req.notes!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic))),
            ]),
          ),
        ],

        // ─── SMART ROUTING: Targeting a donor (pending state) ───
        if (req.status == 'pending' && req.currentTargetDonorId != null) ...[
          const SizedBox(height: 12),
          StreamBuilder<UserModel?>(
            stream: _fs.streamUser(req.currentTargetDonorId!),
            builder: (context, donorSnap) {
              final donor = donorSnap.data;
              final hospitalLat = _hospitalPosition?.latitude ?? req.latitude;
              final hospitalLng = _hospitalPosition?.longitude ?? req.longitude;
              final donorLat = donor?.latitude ?? 0;
              final donorLng = donor?.longitude ?? 0;
              final liveDistance = (donorLat != 0 && donorLng != 0)
                  ? LocationUtils.calculateDistance(hospitalLat, hospitalLng, donorLat, donorLng)
                  : req.currentTargetDistanceKm;
              final donorName = donor?.name ?? req.currentTargetDonorName ?? 'Donor';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.12), const Color(0xFF7C3AED).withValues(alpha: 0.06)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.gps_fixed_rounded, color: AppColors.info, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AI Targeting: $donorName',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Waiting for donor response...', style: GoogleFonts.inter(fontSize: 11, color: AppColors.info)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.warning))
                            .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 600.ms),
                        const SizedBox(width: 4),
                        Text('5 MIN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.warning)),
                      ]),
                    ),
                  ]),
                  if (liveDistance != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.my_location_rounded, color: AppColors.info, size: 20)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Live Distance', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(LocationUtils.formatDistance(liveDistance),
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.info)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('ETA', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
                          Text(_estimateETA(liveDistance),
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ]),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDonorDistanceMap(context, req),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.map_rounded, color: AppColors.info, size: 18),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
            },
          ),
        ],

        // Show scanning animation when pending with no target
        if (req.status == 'pending' && req.currentTargetDonorId == null && req.assignedDonorName == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: Text('AI is analyzing and finding the nearest compatible donor...',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500))),
            ]),
          ),
        ],

        // Assigned donor info with LIVE distance
        if (req.assignedDonorId != null && req.assignedDonorName != null) ...[
          const SizedBox(height: 10),
          StreamBuilder<UserModel?>(
            stream: _fs.streamUser(req.assignedDonorId!),
            builder: (context, donorSnap) {
              final donor = donorSnap.data;
              final hospitalLat = _hospitalPosition?.latitude ?? req.latitude;
              final hospitalLng = _hospitalPosition?.longitude ?? req.longitude;
              final donorLat = donor?.latitude ?? 0;
              final donorLng = donor?.longitude ?? 0;
              final liveDistance = (donorLat != 0 && donorLng != 0)
                  ? LocationUtils.calculateDistance(hospitalLat, hospitalLng, donorLat, donorLng)
                  : null;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.person_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Donor: ${req.assignedDonorName}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600))),
                    if (liveDistance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.my_location_rounded, size: 11, color: AppColors.info),
                          const SizedBox(width: 3),
                          Text(LocationUtils.formatDistance(liveDistance), style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.info))
                              .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                        ]),
                      ),
                    if (req.assignedAmbulanceId != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.local_shipping_rounded, size: 12, color: AppColors.info),
                          SizedBox(width: 4),
                          Text('Dispatched', style: TextStyle(fontSize: 9, color: AppColors.info, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                  if (liveDistance != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('ETA: ${_estimateETA(liveDistance)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text('Distance: ${LocationUtils.formatDistance(liveDistance)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ]),
              );
            },
          ),
        ],
        if (req.isActive) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (req.status == 'accepted' || req.status == 'in_transit')
              Expanded(child: ElevatedButton.icon(
                onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCompleted),
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text('Complete', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 8)),
              )),
            if (req.status == 'accepted' || req.status == 'in_transit') const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCancelled),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancel', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
          ]),
        ],
      ]),
    );
  }

  // ===================== HELPERS =====================
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'matched': return AppColors.info;
      case 'accepted': return AppColors.success;
      case 'in_transit': return AppColors.info;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.textMuted;
      default: return AppColors.textSecondary;
    }
  }

  void _showSOSDialog(BuildContext context) {
    String bg = 'O-';
    int units = 1;
    final auth = context.read<AuthProvider>();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.emergency_rounded, color: AppColors.primary, size: 22)),
          const SizedBox(width: 10),
          const Text('SOS EMERGENCY', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Broadcast to ALL nearby donors.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          BloodGroupSelector(selectedGroup: bg, onSelected: (g) => ss(() => bg = g)),
          const SizedBox(height: 14),
          Row(children: [
            const Text('Units:', style: TextStyle(color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(onPressed: () { if (units > 1) ss(() => units--); }, icon: const Icon(Icons.remove_circle_outline_rounded), color: AppColors.textSecondary, iconSize: 20),
            Text('$units', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            IconButton(onPressed: () => ss(() => units++), icon: const Icon(Icons.add_circle_outline_rounded), color: AppColors.primary, iconSize: 20),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            await context.read<RequestProvider>().createRequest(
              hospitalId: auth.firebaseUser!.uid, hospitalName: auth.userModel!.name,
              bloodGroup: bg, units: units, urgency: 'SOS',
              latitude: auth.userModel!.latitude, longitude: auth.userModel!.longitude,
              notes: 'SOS EMERGENCY - Immediate response required');
          }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('🆘 SEND SOS')),
        ],
      ),
    ));
  }

  void _showCreateRequestDialog(BuildContext context) {
    String bg = 'O+';
    int units = 1;
    String urgency = 'Normal';
    final notes = TextEditingController();
    final auth = context.read<AuthProvider>();

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Container(
        decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Create Blood Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          const Text('Blood Group', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          BloodGroupSelector(selectedGroup: bg, onSelected: (g) => ss(() => bg = g)),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Units:', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const Spacer(),
            IconButton(onPressed: () { if (units > 1) ss(() => units--); }, icon: const Icon(Icons.remove_circle_rounded), color: AppColors.textSecondary),
            Container(width: 50, padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: AppColors.bgCardLight, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('$units', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)))),
            IconButton(onPressed: () => ss(() => units++), icon: const Icon(Icons.add_circle_rounded), color: AppColors.primary),
          ]),
          const SizedBox(height: 16),
          const Text('Urgency', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: AppConstants.urgencyLevels.map((l) {
            final sel = urgency == l;
            final c = _getUrgencyColor(l);
            return ChoiceChip(label: Text(l), selected: sel, onSelected: (_) => ss(() => urgency = l),
              selectedColor: c.withValues(alpha: 0.2), labelStyle: TextStyle(color: sel ? c : AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
              side: BorderSide(color: sel ? c : AppColors.border));
          }).toList()),
          const SizedBox(height: 16),
          TextFormField(controller: notes, maxLines: 2, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Patient condition...')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            await context.read<RequestProvider>().createRequest(
              hospitalId: auth.firebaseUser!.uid, hospitalName: auth.userModel!.name,
              bloodGroup: bg, units: units, urgency: urgency,
              latitude: auth.userModel!.latitude, longitude: auth.userModel!.longitude, notes: notes.text);
          }, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Submit Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ])),
      )),
    );
  }

  Color _getUrgencyColor(String u) {
    switch (u) { case 'SOS': return AppColors.urgencySOS; case 'Critical': return AppColors.urgencyCritical;
      case 'Urgent': return AppColors.urgencyUrgent; default: return AppColors.urgencyNormal; }
  }

  String _estimateETA(double distanceKm) {
    const double avgSpeedKmh = 30.0;
    final double timeHours = distanceKm / avgSpeedKmh;
    final int timeMinutes = (timeHours * 60).ceil();
    if (timeMinutes < 1) return '< 1 min';
    if (timeMinutes < 60) return '$timeMinutes min';
    final int hours = timeMinutes ~/ 60;
    final int mins = timeMinutes % 60;
    return '${hours}h ${mins}m';
  }

  void _showDonorDistanceMap(BuildContext context, BloodRequestModel req) {
    final donorId = req.currentTargetDonorId ?? req.assignedDonorId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.info.withValues(alpha: 0.3))),
        ),
        child: donorId == null
            ? const Center(child: Text('No donor assigned', style: TextStyle(color: AppColors.textSecondary)))
            : StreamBuilder<UserModel?>(
                stream: _fs.streamUser(donorId),
                builder: (context, donorSnap) {
                  final donor = donorSnap.data;
                  final hospitalLat = _hospitalPosition?.latitude ?? req.latitude;
                  final hospitalLng = _hospitalPosition?.longitude ?? req.longitude;
                  final donorLat = donor?.latitude ?? 0;
                  final donorLng = donor?.longitude ?? 0;
                  final distance = (donorLat != 0 && donorLng != 0)
                      ? LocationUtils.calculateDistance(hospitalLat, hospitalLng, donorLat, donorLng)
                      : req.currentTargetDistanceKm ?? 0.0;
                  final donorName = donor?.name ?? req.currentTargetDonorName ?? req.assignedDonorName ?? 'Donor';

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Hospital ↔ Donor ', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.info))
                                .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                            const SizedBox(width: 4),
                            Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.info)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('Real-time location tracking', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 30),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.info.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.04)],
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Column(children: [
                                      Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF5252)]),
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12)],
                                        ),
                                        child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Hospital', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                    ]),
                                    Expanded(child: Column(children: [
                                      Stack(alignment: Alignment.center, children: [
                                        Container(
                                          height: 3, margin: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [AppColors.primary, AppColors.info, AppColors.success]),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgCard, borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppColors.info),
                                            boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.2), blurRadius: 8)],
                                          ),
                                          child: Text(LocationUtils.formatDistance(distance),
                                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.info)),
                                        ),
                                      ]),
                                      const SizedBox(height: 6),
                                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(Icons.directions_car_rounded, size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text('ETA: ${_estimateETA(distance)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                                      ]),
                                    ])),
                                    Column(children: [
                                      Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 12)],
                                        ),
                                        child: Center(child: Text(req.bloodGroup,
                                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Donor', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                    ]),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(children: [
                                Expanded(child: _mapInfoCard('Donor', donorName, Icons.person_rounded, AppColors.success)),
                                const SizedBox(width: 10),
                                Expanded(child: _mapInfoCard('Blood Type', req.bloodGroup, Icons.bloodtype_rounded, AppColors.primary)),
                                const SizedBox(width: 10),
                                Expanded(child: _mapInfoCard('Units', '${req.units}', Icons.water_drop_rounded, AppColors.warning)),
                              ]),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(child: _mapInfoCard('Distance', LocationUtils.formatDistance(distance), Icons.my_location_rounded, AppColors.info)),
                                const SizedBox(width: 10),
                                Expanded(child: _mapInfoCard('ETA', _estimateETA(distance), Icons.schedule_rounded, AppColors.warning)),
                                const SizedBox(width: 10),
                                Expanded(child: _mapInfoCard('Urgency', req.urgency, Icons.priority_high_rounded, _getUrgencyColor(req.urgency))),
                              ]),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: (req.status == 'pending' ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: (req.status == 'pending' ? AppColors.warning : AppColors.success).withValues(alpha: 0.3)),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(req.status == 'pending' ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                                      color: req.status == 'pending' ? AppColors.warning : AppColors.success, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(
                                    req.status == 'pending'
                                        ? 'Waiting for $donorName to accept (5 min timeout)'
                                        : '$donorName accepted! ${req.assignedAmbulanceId != null ? "Ambulance dispatched" : "Preparing dispatch"}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: req.status == 'pending' ? AppColors.warning : AppColors.success),
                                  )),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _mapInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
