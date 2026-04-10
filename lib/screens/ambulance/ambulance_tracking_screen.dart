/// Ambulance Tracking Screen - real-time tracking with AI smart ETA & route optimization
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/ambulance_service.dart';
import '../../core/utils/location_utils.dart';

class AmbulanceTrackingScreen extends StatefulWidget {
  final String requestId;
  final String ambulanceId;
  final double destinationLat;
  final double destinationLng;
  final String hospitalName;

  const AmbulanceTrackingScreen({
    super.key,
    required this.requestId,
    required this.ambulanceId,
    required this.destinationLat,
    required this.destinationLng,
    required this.hospitalName,
  });

  @override
  State<AmbulanceTrackingScreen> createState() => _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState extends State<AmbulanceTrackingScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  StreamSubscription? _ambulanceSub;

  double _distanceKm = 0;
  int _etaMinutes = 0;
  String _driverName = '';
  String _vehicleNumber = '';
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    _setupTracking();
  }

  @override
  void dispose() {
    _ambulanceSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Live Tracking',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Call driver button
          if (_driverPhone != null && _driverPhone!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () async {
                  final uri = Uri.parse('tel:$_driverPhone');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded, color: AppColors.success, size: 18),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.destinationLat, widget.destinationLng),
              initialZoom: 14,
              backgroundColor: const Color(0xFF1A1A2E),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bloodlink.ai',
                maxZoom: 19,
                retinaMode: true,
              ),
              if (_polylines.isNotEmpty)
                PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Info panel at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: AppColors.info, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverName.isNotEmpty ? _driverName : 'Ambulance En Route',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _vehicleNumber.isNotEmpty
                                  ? '$_vehicleNumber • ${widget.hospitalName}'
                                  : 'Heading to ${widget.hospitalName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pulsing live indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ETA and distance row
                  Row(
                    children: [
                      Expanded(
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Icon(Icons.timer_rounded,
                                  color: AppColors.warning, size: 22),
                              const SizedBox(height: 6),
                              Text(
                                _etaMinutes > 0 ? '$_etaMinutes min' : 'Calculating...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _etaMinutes > 0 ? AppColors.warning : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'ETA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Icon(Icons.route_rounded,
                                  color: AppColors.info, size: 22),
                              const SizedBox(height: 6),
                              Text(
                                _distanceKm > 0
                                    ? LocationUtils.formatDistance(_distanceKm)
                                    : '—',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _distanceKm > 0 ? AppColors.info : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Distance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Icon(Icons.speed_rounded,
                                  color: AppColors.success, size: 22),
                              const SizedBox(height: 6),
                              const Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                              Text(
                                'Optimized',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Emergency call buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:108');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call 108', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:102');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: AppColors.info,
                            side: BorderSide(color: AppColors.info.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.local_hospital_rounded, size: 18),
                          label: const Text('Call 102', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Center button
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: () => _mapController.move(
                LatLng(widget.destinationLat, widget.destinationLng), 14,
              ),
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _setupTracking() {
    // Destination marker (hospital)
    _markers.add(Marker(
      key: const ValueKey('destination'),
      point: LatLng(widget.destinationLat, widget.destinationLng),
      width: 80,
      height: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.hospitalName.length > 10
                  ? '${widget.hospitalName.substring(0, 10)}…'
                  : widget.hospitalName,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ));

    // Listen to real-time ambulance location using SmartAmbulanceService stream
    _ambulanceSub = SmartAmbulanceService.streamAmbulance(widget.ambulanceId).listen((amb) {
      if (amb != null && amb.latitude != 0) {
        // Calculate real-time distance & ETA
        final dist = LocationUtils.calculateDistance(
          amb.latitude, amb.longitude,
          widget.destinationLat, widget.destinationLng,
        );
        final eta = SmartAmbulanceService.calculateETA(
          amb.latitude, amb.longitude,
          widget.destinationLat, widget.destinationLng,
          'Urgent', // Default urgency for tracking
        );

        // Update markers
        _markers.removeWhere((m) => m.key == const ValueKey('ambulance'));
        _markers.add(Marker(
          key: const ValueKey('ambulance'),
          point: LatLng(amb.latitude, amb.longitude),
          width: 80,
          height: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  amb.vehicleNumber.isNotEmpty ? 'Amb ${amb.vehicleNumber}' : 'Ambulance',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ));

        // Update route polyline
        _polylines.clear();
        _polylines.add(Polyline(
          points: [
            LatLng(amb.latitude, amb.longitude),
            LatLng(widget.destinationLat, widget.destinationLng),
          ],
          color: Colors.orange.withValues(alpha: 0.7),
          strokeWidth: 3,
        ));

        if (mounted) {
          setState(() {
            _distanceKm = dist;
            _etaMinutes = eta;
            _driverName = amb.driverName;
            _vehicleNumber = amb.vehicleNumber;
            _driverPhone = amb.phone;
          });
        }
      }
    });

    setState(() {});
  }
}
