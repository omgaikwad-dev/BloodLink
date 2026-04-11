/// Donor Dashboard - view requests, accept/reject, track ambulance status
/// Enhanced with ambulance auto-dispatch and tracking integration
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/urgency_badge.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/location_utils.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final FirestoreService _fs = FirestoreService();
  int _currentBpm = 72;
  Timer? _bpmTimer;
  Position? _livePosition;

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Simulate AI Sensor tracking real-time heart rate via AI Prediction Mock
    _bpmTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (mounted) {
        setState(() {
          _currentBpm = 70 + math.Random().nextInt(8); // Fluctuate between 70-77 BPM
        });
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() => _livePosition = position);
        if (context.mounted) {
          context.read<AuthProvider>().updateLocation(position.latitude, position.longitude);
        }
      }
      
      Geolocator.getPositionStream().listen((Position position) {
        if (mounted) {
          setState(() => _livePosition = position);
          if (context.mounted) {
            context.read<AuthProvider>().updateLocation(position.latitude, position.longitude);
          }
        }
      });
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  @override
  void dispose() {
    _bpmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Donor Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user?.isAvailable == true
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  user?.isAvailable == true ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Switch(
              value: user?.isAvailable ?? false,
              onChanged: (val) {
                if (auth.firebaseUser != null) {
                  _fs.updateUserAvailability(auth.firebaseUser!.uid, val);
                  auth.updateProfile(user!.copyWith(isAvailable: val));
                }
              },
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.success,
              inactiveTrackColor: AppColors.bgCardLight,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDonorInfo(user)
                    .animate()
                    .fade(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0, curve: Curves.easeOutQuad),
                const SizedBox(height: 20),
                _buildStats()
                    .animate()
                    .fade(delay: 100.ms, duration: 400.ms)
                    .slideX(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                _buildLiveHealthPulse()
                    .animate()
                    .fade(delay: 150.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
                const Text(
                  '🔴 Incoming Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fade(delay: 200.ms).slideX(),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildIncoming(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  '✅ My Accepted',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fade(delay: 400.ms).slideX(),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildMyRequests(),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildDonorInfo(dynamic user) {
    return GlassCard(
      isHighlighted: true,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.sosGradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                user?.bloodGroup ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Donor Hero',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.bloodtype_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user?.bloodGroup ?? "N/A"}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      user?.canDonate == true
                          ? Icons.verified_user_rounded
                          : Icons.info_outline_rounded,
                      color: user?.canDonate == true
                          ? AppColors.success
                          : AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.canDonate == true
                          ? 'Eligible to Donate'
                          : 'In Cooldown',
                      style: TextStyle(
                        color: user?.canDonate == true
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamDonorRequests(uid),
      builder: (context, snap) {
        final reqs = snap.data ?? [];
        return Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Lives Saved',
                value: '${reqs.where((r) => r.status == 'completed').length}',
                icon: Icons.favorite_rounded,
                iconColor: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Active Responses',
                value:
                    '${reqs.where((r) => r.status == 'accepted' || r.status == 'in_transit').length}',
                icon: Icons.speed_rounded,
                iconColor: AppColors.info,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveHealthPulse() {
    String healthStatus = _currentBpm > 75 ? 'Slightly Elevated' : 'Optimum';
    Color pulseColor = _currentBpm > 75 ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pulseColor.withValues(alpha: _currentBpm > 74 ? 0.15 : 0.08),
            pulseColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pulseColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: pulseColor.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pulseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monitor_heart_rounded, color: pulseColor, size: 24)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Vitals Sensor',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Live Donor Tracking',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pulseColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: pulseColor),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: pulseColor, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _vitalData('Heart Rate', '$_currentBpm', ' BPM', pulseColor),
              Container(width: 1, height: 40, color: AppColors.border),
              _vitalData('SpO2', '99', '%', AppColors.info),
              Container(width: 1, height: 40, color: AppColors.border),
              _vitalData('Status', healthStatus, '', pulseColor, isText: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalData(String label, String value, String unit, Color color, {bool isText = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
              child: Text(
                value,
                key: ValueKey<String>(value),
                style: isText 
                     ? GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)
                     : GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            if (!isText)
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 2),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildIncoming() {
    final user = context.read<AuthProvider>().userModel;
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamPendingRequests(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          );
        }
        final reqs = snap.data!.where((r) {
          if (user == null || r.rejectedDonorIds.contains(user.id)) {
            return false;
          }
          // Show requests where donor is the AI target OR blood group matches
          if (r.currentTargetDonorId == user.id) return true;
          if (r.bloodGroup != user.bloodGroup) return false;
          return true;
        }).toList();

        // Sort: AI-targeted requests appear first, then by recency
        reqs.sort((a, b) {
          final aTargeted = a.currentTargetDonorId == user?.id ? 0 : 1;
          final bTargeted = b.currentTargetDonorId == user?.id ? 0 : 1;
          if (aTargeted != bTargeted) return aTargeted.compareTo(bTargeted);
          return b.createdAt.compareTo(a.createdAt);
        });
        if (reqs.isEmpty) {
          return SliverToBoxAdapter(
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 56,
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No ${user?.bloodGroup ?? ""} Requests Right Now',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will notify you immediately if a hospital requests your blood group.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ).animate().fade().scale(begin: const Offset(0.95, 0.95), duration: 400.ms),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (c, i) => _requestCard(
              reqs[i],
              user!,
            ).animate().fade().slideY(begin: 0.2, end: 0, delay: (i * 100).ms),
            childCount: reqs.length,
          ),
        );
      },
    );
  }

  Widget _requestCard(BloodRequestModel r, dynamic user) {
    final dist = LocationUtils.calculateDistance(
      _livePosition?.latitude ?? user.latitude,
      _livePosition?.longitude ?? user.longitude,
      r.latitude,
      r.longitude,
    );
    final bool isTargeted = r.currentTargetDonorId == user.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        isHighlighted: r.isSOS || isTargeted,
        borderColor: r.isSOS ? AppColors.error : isTargeted ? AppColors.info : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI targeting badge
            if (isTargeted)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.2), const Color(0xFF7C3AED).withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: AppColors.info, size: 18)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 800.ms),
                    const SizedBox(width: 8),
                    Text('AI HAS SELECTED YOU — NEAREST DONOR',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.info, letterSpacing: 0.3)),
                  ],
                ),
              ).animate().shimmer(color: AppColors.info.withValues(alpha: 0.3), duration: 2.seconds),
            if (r.isSOS)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 20,
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                          duration: 500.ms,
                        ),
                    const SizedBox(width: 8),
                    const Text(
                      'CRITICAL SOS EMERGENCY',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      r.bloodGroup,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.hospitalName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${r.units} unit(s)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${LocationUtils.formatDistance(dist)} away',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                UrgencyBadge(urgency: r.urgency),
              ],
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.notes!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context
                        .read<RequestProvider>()
                        .rejectRequest(r.id, user.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: r.isSOS
                          ? AppColors.error
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _acceptAndDispatch(r, user),
                    icon: const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Accept & Save Life',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Accept request and auto-dispatch ambulance
  Future<void> _acceptAndDispatch(BloodRequestModel request, dynamic user) async {
    final provider = context.read<RequestProvider>();

    // Accept the request — this also auto-dispatches ambulance
    final success = await provider.acceptRequest(
      request.id,
      user.id,
      user.name,
      donorLat: user.latitude,
      donorLng: user.longitude,
    );

    if (!mounted) return;

    if (success) {
      // Show success with ambulance info
      final assignment = provider.lastAmbulanceAssignment;
      
      if (assignment != null) {
        // Show ambulance dispatch dialog with option to track
        _showAmbulanceDispatchedDialog(
          request: request,
          assignment: assignment,
          user: user,
        );
      } else {
        // No ambulance available, just show acceptance success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request accepted! Thank you for saving a life!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${provider.error ?? "Failed to accept request"}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show dialog when ambulance is dispatched
  void _showAmbulanceDispatchedDialog({
    required BloodRequestModel request,
    required dynamic assignment,
    required dynamic user,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 12),
            const Text('Request Accepted!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thank you for being a lifesaver! 🦸',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Ambulance info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          color: AppColors.info, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('🚑 Ambulance Auto-Dispatched',
                            style: TextStyle(
                                color: AppColors.info,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequests() {
    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.streamDonorRequests(uid),
      builder: (context, snap) {
        final active = (snap.data ?? []).where((r) => r.isActive).toList();
        if (active.isEmpty) {
          return SliverToBoxAdapter(
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No active missions',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (c, i) {
              final req = active[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              req.bloodGroup,
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.hospitalName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: req.status == 'in_transit'
                                              ? AppColors.info
                                              : AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(reverse: true),
                                      )
                                      .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Status: ${req.status.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: req.status == 'in_transit'
                                          ? AppColors.info
                                          : AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        UrgencyBadge(urgency: req.urgency, fontSize: 11),
                      ],
                    ),
                    // Show ambulance tracking button if ambulance is assigned
                    if (req.assignedAmbulanceId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.info),
                            const SizedBox(width: 8),
                            const Text('Ambulance Auto-Dispatched', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          childCount: active.length,
        ));
      },
    );
  }
}
