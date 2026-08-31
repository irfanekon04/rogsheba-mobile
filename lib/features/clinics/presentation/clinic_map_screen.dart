import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';

/// Full-screen map showing a single clinic pin. The user can pan and zoom,
/// then tap "Directions" to open turn-by-turn navigation in an external app.
class ClinicMapScreen extends StatelessWidget {
  const ClinicMapScreen({
    required this.lat,
    required this.lon,
    required this.name,
    this.address,
    super.key,
  });

  final double lat;
  final double lon;
  final String name;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lon);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 16,
          onTap: (_, __) => {},
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.rogsheba.rogsheba_mobile',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_pin,
                  color: scheme.error,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: kShadowSoft,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (address != null) ...[
                const SizedBox(height: 4),
                Text(
                  address!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, size: 18),
                label: const Text(BnStrings.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
