import 'package:go_router/go_router.dart';

import 'package:rogsheba_mobile/features/clinics/presentation/clinic_map_screen.dart';
import 'package:rogsheba_mobile/features/clinics/presentation/clinics_screen.dart';
import 'package:rogsheba_mobile/features/triage/presentation/home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/clinics', builder: (_, __) => const ClinicsScreen()),
    GoRoute(
      path: '/clinic-map',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ClinicMapScreen(
          lat: (extra['lat'] as num?)?.toDouble() ?? 0,
          lon: (extra['lon'] as num?)?.toDouble() ?? 0,
          name: extra['name'] as String? ?? '',
          address: extra['address'] as String?,
        );
      },
    ),
  ],
);
