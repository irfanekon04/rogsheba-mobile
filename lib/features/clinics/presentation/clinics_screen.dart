import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/services/launcher_service.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/clinics/domain/clinic.dart';
import 'package:rogsheba_mobile/features/clinics/presentation/clinics_controller.dart';
import 'package:rogsheba_mobile/features/emergency/presentation/hotline_pill.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';

/// The clinics screen, faithful to the web component: locating + loading
/// waiting states, the nearest-first facility list with distance chips and
/// address, and per-facility দিকনির্দেশ / ম্যাপে দেখুন deep links.
///
/// Locates the user automatically on open — no button press needed. The
/// controller handles the granted path; denied/disabled/failed surface an
/// error with a retry here until slice #9 lands its Dhaka fallback.
class ClinicsScreen extends ConsumerStatefulWidget {
  const ClinicsScreen({super.key});

  @override
  ConsumerState<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends ConsumerState<ClinicsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(clinicsControllerProvider.notifier)
          .locateAndLoad(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clinicsControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(BnStrings.clinicsTitle),
        actions: const [HotlinePill()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    BnStrings.clinicsSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  switch (state.phase) {
                    ClinicsPhase.locating => const _WaitingCard(
                      message: BnStrings.locating,
                    ),
                    ClinicsPhase.loading => const _WaitingCard(
                      message: BnStrings.clinicsLoading,
                    ),
                    ClinicsPhase.ready => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.usingFallback)
                          _FallbackBanner(message: state.fallbackReason!),
                        _ClinicList(
                          clinics: state.clinics,
                          userLat: state.userLat,
                          userLon: state.userLon,
                        ),
                        if (state.usingFallback) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: _PillButton(
                              label: BnStrings.retry,
                              filled: false,
                              onPressed: () => ref
                                  .read(clinicsControllerProvider.notifier)
                                  .locateAndLoad(),
                            ),
                          ),
                        ],
                      ],
                    ),
                    ClinicsPhase.failed => _FailedCard(
                      message: state.errorMessage ?? BnStrings.genericError,
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One spinner card shared by the two waiting states, with the web's distinct
/// Bangla messages.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label: message,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber info banner shown above the fallback list when location did not
/// resolve. The Bangla copy lives in [BnStrings] and is rendered verbatim.
/// Matches the web's tone: explain why we fell back, not just that we did.
class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: scheme.tertiary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: scheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: 16),
          _PillButton(
            label: BnStrings.retry,
            filled: false,
            onPressed: () {
              ref
                  .read(clinicsControllerProvider.notifier)
                  .locateAndLoad();
            },
          ),
        ],
      ),
    );
  }
}

class _ClinicList extends ConsumerWidget {
  const _ClinicList({
    required this.clinics,
    required this.userLat,
    required this.userLon,
  });

  final List<Clinic> clinics;
  final double? userLat;
  final double? userLon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final (index, clinic) in clinics.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClinicItem(
              index: index,
              clinic: clinic,
              userLat: userLat,
              userLon: userLon,
            ),
          ),
      ],
    );
  }
}

class _ClinicItem extends ConsumerWidget {
  const _ClinicItem({
    required this.index,
    required this.clinic,
    required this.userLat,
    required this.userLon,
  });

  final int index;
  final Clinic clinic;
  final double? userLat;
  final double? userLon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final launch = ref.read(launcherServiceProvider);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.local_hospital,
              color: scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '#${index + 1} ',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(text: clinic.name),
                          ],
                        ),
                        // No maxLines/ellipsis: Bangla clinic names are longer
                        // than their English originals and must wrap rather
                        // than clip, even at 200% system text scale.
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.xxxl),
                      ),
                      child: Text(
                        '${clinic.distanceKm.toStringAsFixed(1)} km',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (clinic.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    clinic.address!,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillButton(
                      label: BnStrings.directions,
                      filled: true,
                      icon: Icons.navigation,
                      onPressed: () => launch(
                        MapUrls.directions(
                          destinationLat: clinic.lat,
                          destinationLon: clinic.lon,
                          originLat: userLat,
                          originLon: userLon,
                        ),
                      ),
                    ),
                    _PillButton(
                      label: BnStrings.viewOnMap,
                      filled: false,
                      icon: Icons.map_outlined,
                      onPressed: () => launch(
                        MapUrls.osmLocation(lat: clinic.lat, lon: clinic.lon),
                      ),
                    ),
                    if (clinic.type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.xxxl),
                        ),
                        child: Text(
                          clinic.type!,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondary,
                            fontWeight: FontWeight.w600,
                          ),
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
}

/// Small pill action, matching the web's primary / outlined pills. Filled and
/// outlined variants share the theme-resolved colours — no hardcoded tokens.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = filled ? scheme.primary : Colors.transparent;
    final foreground = filled ? scheme.onPrimary : scheme.onSurface;
    final border = filled ? BorderSide.none : BorderSide(color: scheme.outline);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
        side: border,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
