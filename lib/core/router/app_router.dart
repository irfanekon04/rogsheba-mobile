import 'package:go_router/go_router.dart';

import 'package:rogsheba_mobile/features/clinics/presentation/clinics_screen.dart';
import 'package:rogsheba_mobile/features/triage/presentation/home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/clinics', builder: (_, __) => const ClinicsScreen()),
  ],
);
