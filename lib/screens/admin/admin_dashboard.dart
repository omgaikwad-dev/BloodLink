/// Admin Dashboard - monitor system, view analytics
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/urgency_badge.dart';
import '../../core/services/firestore_service.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirestoreService _fs = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // System overview
          const Text('System Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildOverviewStats(),
          const SizedBox(height: 24),

          // Donor stats
          const Text('Donors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildDonorStats(),
          const SizedBox(height: 24),

          // Recent requests
          const Text('Recent Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildRecentRequests(),
        ]),
      ),
    );
  }

  Widget _buildOverviewStats() {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamAllRequests(),
      builder: (context, snap) {
        final reqs = snap.data ?? [];
        final active = reqs.where((r) => r.isActive).length;
        final completed = reqs.where((r) => r.status == 'completed').length;
        final sos = reqs.where((r) => r.isSOS && r.isActive).length;
        final rate = reqs.isEmpty ? 0 : ((completed / reqs.length) * 100).round();

        return Column(children: [
          Row(children: [
            Expanded(child: StatCard(title: 'Total Requests', value: '${reqs.length}', icon: Icons.insert_chart_rounded, iconColor: AppColors.info)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Active Now', value: '$active', icon: Icons.pending_actions_rounded, iconColor: AppColors.warning)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatCard(title: 'SOS Active', value: '$sos', icon: Icons.emergency_rounded, iconColor: AppColors.error, valueColor: sos > 0 ? AppColors.error : null)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Success Rate', value: '$rate%', icon: Icons.analytics_rounded, iconColor: AppColors.success)),
          ]),
        ]);
      },
    );
  }

  Widget _buildDonorStats() {
    return StreamBuilder<List<UserModel>>(
      stream: _fs.streamUsersByRole('donor'),
      builder: (context, snap) {
        final donors = snap.data ?? [];
        final available = donors.where((d) => d.isAvailable).length;
        final eligible = donors.where((d) => d.canDonate).length;

        return Row(children: [
          Expanded(child: StatCard(title: 'Total Donors', value: '${donors.length}', icon: Icons.people_rounded, iconColor: AppColors.secondary)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'Available', value: '$available', icon: Icons.person_pin_circle_rounded, iconColor: AppColors.success)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'Eligible', value: '$eligible', icon: Icons.verified_rounded, iconColor: AppColors.info)),
        ]);
      },
    );
  }

  Widget _buildRecentRequests() {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamAllRequests(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final reqs = snap.data!.take(20).toList();
        if (reqs.isEmpty) {
          return GlassCard(padding: const EdgeInsets.all(24),
          child: Center(child: Text('No requests yet', style: TextStyle(color: AppColors.textSecondary))));
        }
        return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: reqs.length, itemBuilder: (c, i) {
            final r = reqs[i];
            return GlassCard(
              isHighlighted: r.isSOS,
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(r.bloodGroup, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.hospitalName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text('${r.units} units • ${r.status}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                UrgencyBadge(urgency: r.urgency, fontSize: 10),
              ]),
            );
          });
      },
    );
  }
}
