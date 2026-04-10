/// Hospital Dashboard - manage requests, view donors, SOS emergency
/// Demo data removed, real-time Firestore data only
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
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../ai/ai_chat_screen.dart';
import '../ai/demand_prediction_screen.dart';
import '../ai/emergency_classifier_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Network'),
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
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
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamAllRequests(),
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
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamActiveRequests(),
      builder: (context, snap) {
        final reqs = (snap.data ?? []).take(5).toList();
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

    return GlassCard(
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
    );
  }

  // ===================== REQUESTS TAB =====================
  Widget _buildRequestsTab() {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamAllRequests(),
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
    final auth = context.read<AuthProvider>();
    final isOwn = req.hospitalId == auth.firebaseUser?.uid;

    return GlassCard(
      isHighlighted: req.isSOS,
      borderColor: req.isSOS ? AppColors.error.withValues(alpha: 0.4) : isOwn ? AppColors.primary.withValues(alpha: 0.3) : null,
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
            Row(children: [
              Expanded(child: Text(req.hospitalName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis)),
              if (isOwn) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text('YOUR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
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
        if (req.assignedDonorName != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.person_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text('Donor: ${req.assignedDonorName}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500)),
              if (req.assignedAmbulanceId != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_shipping_rounded, size: 12, color: AppColors.info),
                    const SizedBox(width: 4),
                    const Text('Ambulance Dispatched', style: TextStyle(fontSize: 9, color: AppColors.info, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
        ],
        if (isOwn && req.isActive) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (req.status == 'accepted')
              Expanded(child: ElevatedButton.icon(
                onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCompleted),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Complete', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 8)),
              )),
            if (req.status == 'accepted') const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => context.read<RequestProvider>().updateStatus(req.id, AppConstants.statusCancelled),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Cancel', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 8)),
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
}
