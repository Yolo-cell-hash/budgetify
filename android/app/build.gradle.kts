import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from android/key.properties, which is kept out of
// the repo (see android/.gitignore). On machines without that file the build
// falls back to debug signing so `flutter run --release` still works for
// everyone; only a machine holding the upload keystore can produce a
// Play-uploadable, release-signed bundle.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jayrk.budget_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jayrk.budget_tracker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    packaging {
        jniLibs {
            // 16 KB page-size compliance (Play Console: "Your app could crash
            // on 16 KB devices").
            //
            // androidx.datastore ships a *prebuilt* libdatastore_shared_counter.so
            // that its own .note.android.ident records as built with NDK r20 —
            // an NDK old enough to have the known 16 KB bug, and the only
            // library in the bundle whose PT_GNU_RELRO segment is neither
            // 16 KB-aligned nor a suffix of a LOAD segment. Every other .so we
            // ship (libflutter/libapp from Flutter's own NDK r28c, libdartjni)
            // already passes. Upgrading doesn't help: 1.2.0 is the current
            // stable and carries the same r20 binary. See
            // https://github.com/flutter/flutter/issues/182744.
            //
            // Dropping it is safe, not a workaround with a runtime cost: the
            // library is loaded only by MultiProcessDataStore, and the sole
            // dependency that pulls DataStore in — shared_preferences_android —
            // uses the single-process `preferencesDataStore` delegate. R8 already
            // proves it: the shipped release DEX contains no SharedCounter, no
            // MultiProcessDataStore, and not even the "datastore_shared_counter"
            // library-name string, so nothing in the app can call
            // System.loadLibrary for it. Revisit if a future dependency starts
            // using multi-process DataStore.
            excludes += "**/libdatastore_shared_counter.so"
        }
    }

    buildTypes {
        release {
            // Use the upload key from android/key.properties when present;
            // otherwise fall back to debug signing (for `flutter run --release`
            // on machines without the keystore).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
