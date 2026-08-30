import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_controller.dart';
import 'package:rogsheba_mobile/shared/widgets/app_chip.dart';

class ExampleChips extends ConsumerWidget {
  const ExampleChips({super.key});

  static const _examples = [
    BnStrings.exampleFeverThroat,
    BnStrings.exampleChestPain,
    BnStrings.exampleStomach,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(triageControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BnStrings.exampleHeader,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final example in _examples)
                AppChip(
                  label: example,
                  onTap: () => controller.onSymptomsChanged(example),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
