/// Map Screen - display hospitals, donors, blood banks with OpenStreetMap
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirestoreService _fs = FirestoreService();
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  String _filter = 'All';
  bool _locationLoading = true;
  LatLng? _currentPosition;
  final List<StreamSubscription> _subscriptions = [];

  // Fallback position (Pune) — only used if GPS fails
  static const LatLng _fallbackPos = LatLng(18.4415, 73.8335);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// Get the real device GPS location
  Future<void> _initLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('>>> Location services disabled');
        _useDefaultAndContinue();
        return;
      }

      // Check & request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('>>> Location permission denied');
          _useDefaultAndContinue();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('>>> Location permission denied forever');
        _useDefaultAndContinue();
        return;
      }

      // Try to get last known position for instant map load
      Position? position = await Geolocator.getLastKnownPosition();
      
      // If null, get the actual current position
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final pos = position;
      debugPrint('>>> GPS Location: ${pos.latitude}, ${pos.longitude}');

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _locationLoading = false;
        });

        // Move map to actual GPS location
        _mapController.move(_currentPosition!, 15);

        // Add "You are here" marker
        _addCurrentLocationMarker();

        // Also update the user's location in Firestore
        _updateUserLocation(pos.latitude, pos.longitude);

        _loadMarkers();
      }
    } catch (e) {
      debugPrint('>>> Error getting location: $e');
      _useDefaultAndContinue();
    }
  }

  void _useDefaultAndContinue() {
    if (mounted) {
      // Try to use stored user location, otherwise fall back
      final auth = context.read<AuthProvider>();
      final user = auth.userModel;
      final pos = (user != null && user.latitude != 0 && user.longitude != 0)
          ? LatLng(user.latitude, user.longitude)
          : _fallbackPos;

      setState(() {
        _currentPosition = pos;
        _locationLoading = false;
      });
      _mapController.move(pos, 13);
      _addCurrentLocationMarker();
      _loadMarkers();
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition == null) return;

    // Remove any existing "me" marker
    _markers.removeWhere((m) => m.key == const ValueKey('current_location'));

    _markers.add(Marker(
      key: const ValueKey('current_location'),
      point: _currentPosition!,
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
            ),
          ),
          // Inner dot
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  void _updateUserLocation(double lat, double lng) {
    final auth = context.read<AuthProvider>();
    if (auth.firebaseUser != null && auth.userModel != null) {
      _fs.updateUserLocation(auth.firebaseUser!.uid, lat, lng);
      auth.updateProfile(auth.userModel!.copyWith(latitude: lat, longitude: lng));
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startPos = _currentPosition ?? _fallbackPos;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: startPos,
              initialZoom: 15,
              backgroundColor: const Color(0xFF1A1A2E),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Dark-themed tile layer
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bloodlink.ai',
                maxZoom: 19,
                retinaMode: true,
              ),
              // Markers layer
              MarkerLayer(markers: _markers),
            ],
          ),

          // Loading overlay
          if (_locationLoading)
            Container(
              color: AppColors.bgDark,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Getting your location...', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Please allow location permission', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Top bar with filter chips
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Donors', 'Hospitals', 'Blood Banks'].map((f) {
                    final isActive = _filter == f;
                    final icon = _getFilterIcon(f);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        avatar: Icon(icon, size: 16,
                          color: isActive ? AppColors.primary : AppColors.textMuted),
                        label: Text(f, style: const TextStyle(fontSize: 12)),
                        selected: isActive,
                        onSelected: (_) {
                          setState(() => _filter = f);
                          _loadMarkers();
                        },
                        backgroundColor: Colors.transparent,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isActive ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                        side: BorderSide(
                          color: isActive ? AppColors.primary : Colors.transparent),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: 24, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _legendDot(AppColors.primary, 'You'),
                const SizedBox(width: 14),
                _legendDot(Colors.green, 'Donors'),
                const SizedBox(width: 14),
                _legendDot(Colors.blue, 'Hospitals'),
                const SizedBox(width: 14),
                _legendDot(Colors.red, 'Banks'),
              ]),
            ),
          ),

          // Center on current location button
          Positioned(
            bottom: 24, right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.bgCard,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 15);
                }
              },
              child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Donors': return Icons.volunteer_activism_rounded;
      case 'Hospitals': return Icons.local_hospital_rounded;
      case 'Blood Banks': return Icons.bloodtype_rounded;
      default: return Icons.layers_rounded;
    }
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  /// Build a custom map marker widget
  Widget _buildMarkerWidget(Color color, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _loadMarkers() {
    // Cancel previous subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Keep the current location marker, remove others
    _markers.removeWhere((m) => m.key != const ValueKey('current_location'));

    if (_filter == 'All' || _filter == 'Donors') {
      final sub = _fs.streamUsersByRole('donor').listen((donors) {
        _markers.removeWhere((m) => m.key is ValueKey<String> && (m.key! as ValueKey<String>).value.startsWith('donor_'));
        for (final d in donors) {
          if (d.latitude != 0) {
            _markers.add(Marker(
              key: ValueKey('donor_${d.id}'),
              point: LatLng(d.latitude, d.longitude),
              width: 80,
              height: 50,
              child: Tooltip(
                message: '${d.name}\n${d.bloodGroup} • ${d.isAvailable ? "Available" : "Busy"}',
                child: _buildMarkerWidget(
                  d.isAvailable ? Colors.green : Colors.green.shade800,
                  Icons.volunteer_activism_rounded,
                  d.bloodGroup,
                ),
              ),
            ));
          }
        }
        if (mounted) setState(() {});
      }, onError: (e) {
        debugPrint('>>> Error loading donors: $e');
      });
      _subscriptions.add(sub);
    }

    if (_filter == 'All' || _filter == 'Hospitals') {
      final sub = _fs.streamUsersByRole('hospital').listen((hospitals) {
        _markers.removeWhere((m) => m.key is ValueKey<String> && (m.key! as ValueKey<String>).value.startsWith('hospital_'));
        for (final h in hospitals) {
          if (h.latitude != 0) {
            _markers.add(Marker(
              key: ValueKey('hospital_${h.id}'),
              point: LatLng(h.latitude, h.longitude),
              width: 80,
              height: 50,
              child: Tooltip(
                message: '${h.name}\nHospital',
                child: _buildMarkerWidget(
                  Colors.blue,
                  Icons.local_hospital_rounded,
                  h.name.length > 8 ? '${h.name.substring(0, 8)}…' : h.name,
                ),
              ),
            ));
          }
        }
        if (mounted) setState(() {});
      }, onError: (e) {
        debugPrint('>>> Error loading hospitals: $e');
      });
      _subscriptions.add(sub);
    }

    if (_filter == 'All' || _filter == 'Blood Banks') {
      final sub = _fs.streamUsersByRole('blood_bank').listen((banks) {
        _markers.removeWhere((m) => m.key is ValueKey<String> && (m.key! as ValueKey<String>).value.startsWith('bank_'));
        for (final b in banks) {
          if (b.latitude != 0) {
            _markers.add(Marker(
              key: ValueKey('bank_${b.id}'),
              point: LatLng(b.latitude, b.longitude),
              width: 80,
              height: 50,
              child: Tooltip(
                message: '${b.name}\nBlood Bank',
                child: _buildMarkerWidget(
                  Colors.red,
                  Icons.bloodtype_rounded,
                  b.name.length > 8 ? '${b.name.substring(0, 8)}…' : b.name,
                ),
              ),
            ));
          }
        }
        if (mounted) setState(() {});
      }, onError: (e) {
        debugPrint('>>> Error loading blood banks: $e');
      });
      _subscriptions.add(sub);
    }
  }
}
