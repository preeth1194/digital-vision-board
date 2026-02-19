import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../../utils/app_typography.dart';

class LocationMapPickerResult {
  final double lat;
  final double lng;
  final String? address;
  const LocationMapPickerResult({required this.lat, required this.lng, this.address});
}

class LocationMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationMapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationMapPickerScreen> createState() => _LocationMapPickerScreenState();
}

class _LocationMapPickerScreenState extends State<LocationMapPickerScreen> {
  late final MapController _mapController;
  late LatLng _center;
  String? _resolvedAddress;
  bool _isGeocoding = false;
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = LatLng(
      widget.initialLat ?? 20.0,
      widget.initialLng ?? 78.0,
    );
    if (widget.initialLat != null && widget.initialLng != null) {
      _reverseGeocode(_center);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      final c = _mapController.camera.center;
      setState(() => _center = c);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        _reverseGeocode(c);
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          [
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
          ].join(', '),
          [
            if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ].join(' '),
        ].where((s) => s.trim().isNotEmpty).toList();
        if (mounted) setState(() => _resolvedAddress = parts.join('\n'));
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    if (mounted) setState(() => _isGeocoding = false);
  }

  Future<void> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchFocusNode.unfocus();
    setState(() => _isGeocoding = true);
    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        _mapController.move(target, 15.0);
        setState(() => _center = target);
        await _reverseGeocode(target);
        return;
      }
    } catch (e) {
      debugPrint('Forward geocode error: $e');
    }
    if (mounted) {
      setState(() => _isGeocoding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No results found for "$trimmed"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      LocationMapPickerResult(
        lat: _center.latitude,
        lng: _center.longitude,
        address: _resolvedAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Choose Location',
          style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: (widget.initialLat != null) ? 15.0 : 4.0,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.seerohabitseeding.app',
              ),
            ],
          ),

          // Center pin (always fixed at center of map)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: colorScheme.primary,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: colorScheme.shadow.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          // Pin shadow dot
          Center(
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.shadow.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: AppTypography.body(context).copyWith(fontSize: 14),
                textInputAction: TextInputAction.search,
                onSubmitted: _searchLocation,
                decoration: InputDecoration(
                  hintText: 'Search an address or place...',
                  hintStyle: AppTypography.bodySmall(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(Icons.search, size: 22, color: colorScheme.onSurfaceVariant),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Bottom card with address + confirm button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding > 0 ? bottomPadding : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isGeocoding)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (_resolvedAddress != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _resolvedAddress!,
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Pan the map to select a location',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _resolvedAddress != null ? _confirm : null,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      'Use This Location',
                      style: AppTypography.button(context).copyWith(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
