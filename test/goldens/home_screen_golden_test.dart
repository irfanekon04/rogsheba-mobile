import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rogsheba_mobile/core/services/connectivity_service.dart';
import 'package:rogsheba_mobile/core/services/speech_service.dart';
import 'package:rogsheba_mobile/core/services/tts_service.dart';
import 'package:rogsheba_mobile/core/theme/app_theme.dart';
import 'package:rogsheba_mobile/features/triage/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/bundled_fonts.dart';
import '../helpers/fake_connectivity_service.dart';
import '../helpers/fake_speech_service.dart';
import '../helpers/fake_tts_service.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester, Brightness brightness) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(414, 1900));
    await loadBundledFonts(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechServiceProvider.overrideWithValue(FakeSpeechService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness),
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home screen — light theme', (tester) async {
    await pumpHome(tester, Brightness.light);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_light.png'),
    );
  });

  testWidgets('home screen — dark theme', (tester) async {
    await pumpHome(tester, Brightness.dark);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_dark.png'),
    );
  });
}
