# RogSheba release keep rules (R8 / ProGuard).
#
# Dart is AOT-compiled before R8, so the Dart side needs no keep rules. These
# protect the Java/Kotlin plugin channels that use reflection or runtime
# registration and would otherwise be stripped or renamed by R8.

# speech_to_text (SpeechToTextPlugin): android.speech reflection.
-keep class com.csdcorp.speech_to_text.** { *; }

# flutter_tts (FlutterTtsPlugin): TextToSpeech runtime.
-keep class com.eyedeadevelopment.fluttertts.** { *; }

# permission_handler (PermissionHandlerPlugin): per-permission calls.
-keep class com.baseflow.permissionhandler.** { *; }

# geolocator (GeolocatorPlugin): FusedLocationProviderClient via reflection.
-keep class com.baseflow.geolocator.** { *; }

# shared_preferences / dio: keep their entry points intact.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.dio.** { *; }

# The Flutter embedding itself resolves classes by name at startup.
-keep class io.flutter.** { *; }

# The Flutter engine's PlayStoreSplitApplication / deferred-component manager
# reference `com.google.android.play.core.*` classes that are not on the app's
# compile classpath (they are only present when Play Store split delivery is
# used). R8 must not fail on them, and if present they must survive.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }