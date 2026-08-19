import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: read the human's keystore from `key.properties` (gitignored,
// never committed). When absent — e.g. CI, or a developer who has not yet set
// up release keys — fall back to debug signing so `flutter build apk --release`
// still produces an installable artifact. See docs/release-android.md.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore =
    keystoreProperties.getProperty("storeFile") != null &&
        keystoreProperties.getProperty("storePassword") != null &&
        keystoreProperties.getProperty("keyAlias") != null &&
        keystoreProperties.getProperty("keyPassword") != null

android {
    namespace = "com.rogsheba.rogsheba_mobile"
    // permission_handler_android 12+ compiles against API 37; the Flutter
    // default (36) triggers an AGP "unsupported compileSdk" fixup. Pin 37 so
    // the release build is on the same API the plugins build against.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.rogsheba.rogsheba_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Versioning scheme: `versionName` is the human-readable release
        // (e.g. "1.0.0"); `versionCode` must increase monotonically for every
        // upload to the Play Console internal track. Both come from
        // pubspec.yaml (version: <name>+<build>).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // No keystore configured yet (CI / local without keys).
                // Installable, but NOT fit for Play Console upload.
                signingConfig = signingConfigs.getByName("debug")
            }
            // R8 code + resource shrinking with the plugin keep rules in
            // proguard-rules.pro (speech_to_text, flutter_tts,
            // permission_handler and geolocator use reflection / native
            // channels that R8 would otherwise strip).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}