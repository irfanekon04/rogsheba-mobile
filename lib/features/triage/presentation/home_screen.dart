import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:rogsheba_mobile/core/theme/app_theme.dart';
import 'package:rogsheba_mobile/core/theme/app_theme_tokens.dart';
import 'package:rogsheba_mobile/features/emergency/presentation/hotline_pill.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_level.dart';
import 'package:rogsheba_mobile/features/triage/domain/triage_result.dart';
import 'package:rogsheba_mobile/features/triage/presentation/triage_controller.dart';
import 'package:rogsheba_mobile/features/triage/presentation/tts_script.dart';
import 'package:rogsheba_mobile/shared/widgets/app_button.dart';
import 'package:rogsheba_mobile/shared/widgets/app_card.dart';
import 'package:rogsheba_mobile/shared/widgets/app_chip.dart';
import 'package:rogsheba_mobile/shared/widgets/offline_banner.dart';

/// The home / triage screen, porting the web layout: hero, symptom entry card,
/// example chips, feature strip and the triage result card. All colours and
/// geometry resolve through the theme — no hardcoded tokens in feature code.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Attached to the result card so a freshly produced result can be scrolled
  /// into view (issue #6 acceptance: "submit scrolls the result into view").
  final GlobalKey _resultKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(triageControllerProvider);
    final controller = ref.read(triageControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    _scrollResultIntoViewOnSubmit();

    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: BnStrings.appBrand,
                style: TextStyle(fontFamily: AppFonts.display),
              ),
              TextSpan(text: ' '),
              TextSpan(text: BnStrings.appTitle),
            ],
          ),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [HotlinePill()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned above the scrollable content so the user sees why a new
            // request will not work the moment connectivity drops. Hidden
            // entirely (zero height) when online, so it never shifts the
            // layout for connected users.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: const OfflineBanner(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 768),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Hero(),
                        const SizedBox(height: 24),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _VoiceSymptomField(
                                onChanged: controller.onSymptomsChanged,
                                onSubmitted: controller.submit,
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: state.isSubmitting
                                    ? BnStrings.submitting
                                    : BnStrings.submit,
                                isLoading: state.isSubmitting,
                                onPressed: state.canSubmit
                                    ? controller.submit
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                BnStrings.inlineDisclaimer,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              if (state.errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: scheme.error),
                                ),
                              ],
                              if (state.result == null && !state.isSubmitting)
                                const _ExampleChips(),
                            ],
                          ),
                        ),
                        if (state.result == null && !state.isSubmitting) ...[
                          const SizedBox(height: 32),
                          const _FeatureStrip(),
                        ],
                        if (state.result != null) ...[
                          const SizedBox(height: 24),
                          KeyedSubtree(
                            key: _resultKey,
                            child: TriageResultCard(result: state.result!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Once a fresh result lands, scrolls the result card into view so the
  /// outcome is immediately visible without manual scrolling.
  void _scrollResultIntoViewOnSubmit() {
    ref.listen<TriageFormState>(triageControllerProvider, (previous, next) {
      if (previous?.result == null && next.result != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultContext = _resultKey.currentContext;
          if (resultContext != null && resultContext.mounted) {
            Scrollable.ensureVisible(
              resultContext,
              alignment: 0.3,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = TextSpan(
      children: [
        const TextSpan(text: 'আপনার লক্ষণ বলুন — '),
        TextSpan(
          text: 'তাৎক্ষণিক স্বাস্থ্য পরামর্শ',
          style: TextStyle(color: scheme.primary),
        ),
        const TextSpan(text: ' পান'),
      ],
    );
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
          ),
          child: Text(
            BnStrings.heroBadge,
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          title,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          BnStrings.heroSubtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Multiline symptom field with the web's voice-input controls: a mic button
/// with pulse animation (tap toggles listening), a live "শুনছি…" + interim
/// transcript while speaking, a one-tap clear button, and — when no `bn-BD`
/// recogniser exists — the web's fallback message with typing still available.
class _VoiceSymptomField extends ConsumerStatefulWidget {
  const _VoiceSymptomField({
    required this.onChanged,
    required this.onSubmitted,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_VoiceSymptomField> createState() => _VoiceSymptomFieldState();
}

class _VoiceSymptomFieldState extends ConsumerState<_VoiceSymptomField>
    with SingleTickerProviderStateMixin {
  static const _pulseDuration = Duration(milliseconds: 1300);

  final TextEditingController _text = TextEditingController();
  late final AnimationController _pulse;

  /// Captured in [initState]; must not be read through `ref` in [dispose].
  late final SpeechService _speech;
  StreamSubscription<SpeechTranscript>? _subscription;

  /// `null` while the capability check is in flight.
  bool? _voiceAvailable;
  bool _isListening = false;
  String _interim = '';

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechServiceProvider);
    _pulse = AnimationController(vsync: this, duration: _pulseDuration);
    _text.addListener(_notifyChanged);
    _checkVoiceAvailable();
  }

  Future<void> _checkVoiceAvailable() async {
    final available = await _speech.supportsBangla();
    if (mounted) setState(() => _voiceAvailable = available);
  }

  void _notifyChanged() => widget.onChanged(_text.text);

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    _subscription = _speech.transcripts.listen(_onTranscript);
    await _speech.startListening();
    if (mounted) {
      setState(() {
        _isListening = true;
        _interim = '';
      });
      unawaited(_pulse.repeat());
    }
  }

  void _onTranscript(SpeechTranscript transcript) {
    if (!mounted) return;
    if (transcript.isFinal) {
      _appendTranscript(transcript.text);
      _stopListening();
    } else {
      setState(() => _interim = transcript.text);
    }
  }

  void _appendTranscript(String text) {
    final current = _text.text;
    final appended = current.trim().isEmpty ? text : '$current $text';
    _text.value = TextEditingValue(
      text: appended,
      selection: TextSelection.collapsed(offset: appended.length),
    );
  }

  Future<void> _stopListening() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _speech.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _interim = '';
      });
      if (_pulse.isAnimating) _pulse.stop();
    }
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _speech.stopListening();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          onSubmitted: (_) => widget.onSubmitted(),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          minLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: BnStrings.symptomPlaceholder,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_text.text.isNotEmpty && !_isListening)
                  IconButton(
                    tooltip: BnStrings.clearField,
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  ),
                if (_voiceAvailable ?? true) _buildMicButton(),
              ],
            ),
          ),
        ),
        if (_isListening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                _PulsingDot(animation: _pulse),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _interim.isEmpty
                        ? BnStrings.listeningIndicator
                        : '${BnStrings.listeningIndicator} $_interim',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_voiceAvailable == false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              BnStrings.voiceUnavailable,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMicButton() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listening = _isListening;
    return Tooltip(
      message: listening ? BnStrings.stopListening : BnStrings.micLabel,
      child: InkWell(
        onTap: _toggleListening,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? scheme.error : scheme.primaryContainer,
          ),
          child: Icon(
            listening ? Icons.stop : Icons.mic,
            size: 22,
            color: listening ? scheme.onError : scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Expanding, fading dot that pulses behind while the mic is active — the
/// web's pulse animation, driven by the field's [AnimationController].
class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - value).clamp(0.0, 1.0),
                child: Container(
                  width: 8 + 24 * value,
                  height: 8 + 24 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExampleChips extends ConsumerWidget {
  const _ExampleChips();

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

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FeatureItem(
          icon: Icons.health_and_safety_outlined,
          title: BnStrings.featureTriageTitle,
          body: BnStrings.featureTriageBody,
        ),
        _FeatureItem(
          icon: Icons.local_hospital_outlined,
          title: BnStrings.featureClinicsTitle,
          body: BnStrings.featureClinicsBody,
        ),
        _FeatureItem(
          icon: Icons.lock_outline,
          title: BnStrings.featurePrivateTitle,
          body: BnStrings.featurePrivateBody,
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled triage result card. The full level-specific blocks (RED emergency
/// band, TTS, clinics CTA) land with the triage-levels slice; this establishes
/// the card chrome and the theme-resolved level colouring.
class TriageResultCard extends StatelessWidget {
  const TriageResultCard({required this.result, super.key});

  final TriageResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _LevelBadge(level: result.level)),
              const SizedBox(width: 8),
              _SpeakButton(result: result),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.titleBn,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(result.summaryBn, style: textTheme.bodyLarge),
          if (result.adviceBn.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeading(BnStrings.adviceTitle),
            for (final (index, step) in result.adviceBn.indexed)
              Text('${index + 1}. $step', style: textTheme.bodyMedium),
          ],
          if (result.warningSignsBn.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeading(BnStrings.warningSignsTitle),
            for (final sign in result.warningSignsBn)
              Text('• $sign', style: textTheme.bodyMedium),
          ],
          if (result.followupQuestionBn != null) ...[
            const SizedBox(height: 12),
            Text(
              '${BnStrings.followupPrefix}${result.followupQuestionBn}',
              style: textTheme.bodyMedium,
            ),
          ],
          const _ClinicsCtaButton(),
          const SizedBox(height: 12),
          Text(
            result.disclaimerBn,
            style: textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Speaker toggle on the result card header: reads the result aloud in Bangla,
/// or stops playback when already speaking. As on the web, the button is hidden
/// entirely when no `bn-BD` voice is installed — Bangla read with an English
/// voice is worse than no audio.
class _SpeakButton extends ConsumerStatefulWidget {
  const _SpeakButton({required this.result});

  final TriageResult result;

  @override
  ConsumerState<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<_SpeakButton> {
  /// `null` while the capability check is in flight, `false` when no `bn-BD`
  /// voice exists. Only `true` renders the button.
  bool? _voiceAvailable;
  bool _isSpeaking = false;

  /// Captured in [initState]; must not be read through `ref` in [dispose],
  /// which Riverpod forbids.
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    _checkVoiceAvailable();
  }

  Future<void> _checkVoiceAvailable() async {
    final available = await _tts.supportsBanglaVoice();
    if (mounted) setState(() => _voiceAvailable = available);
  }

  Future<void> _toggle() async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _tts.speak(buildSpeechText(widget.result));
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  void dispose() {
    // Audio must never outlive the card: stop on dispose and navigation.
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_voiceAvailable != true) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _isSpeaking ? Icons.stop : Icons.volume_up,
        size: 20,
      ),
      label: Text(_isSpeaking ? BnStrings.ttsStop : BnStrings.ttsListen),
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final TriageLevel level;

  @override
  Widget build(BuildContext context) {
    final triage = triageColorsOf(context);
    final background = triage.backgroundFor(level, isForeground: false);
    final foreground = triage.backgroundFor(level, isForeground: true);
    final label = switch (level) {
      TriageLevel.green => BnStrings.levelGreen,
      TriageLevel.yellow => BnStrings.levelYellow,
      TriageLevel.red => BnStrings.levelRed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xxxl),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// The web's clinics CTA under every result: primary pill that routes to the
/// `/clinics` screen via go_router (web `to=/clinics`), shown for every level.
class _ClinicsCtaButton extends StatelessWidget {
  const _ClinicsCtaButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
          ),
          child: InkWell(
            onTap: () => context.go('/clinics'),
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: scheme.onPrimary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    BnStrings.nearbyClinicsCta,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
