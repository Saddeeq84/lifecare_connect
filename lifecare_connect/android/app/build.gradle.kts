// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

android {
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    namespace = "com.lifecare_connect"
    compileSdk = 36 // Use 36 for latest plugin and Play Store support (API 36)
    ndkVersion = "27.0.12077973" // NDK r27+ required for latest plugins and 16 KB page size support

    defaultConfig {
        applicationId = "com.lifecare_connect"
        minSdk = flutter.minSdkVersion // Recommended for 16 KB support
        targetSdk = 36
        versionCode = 17 // Bump version for next Play Store release
        versionName = "1.0.17" // Updated version name
        multiDexEnabled = true // ✅ Required for large apps using many methods (e.g., Firebase)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ For Java 8+ APIs on lower API levels
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("/Users/muhammadsaddiq/my-release-key.jks")
            storePassword = "rhemn_2025"
            keyAlias = "my-key-alias" // Update with your key alias
            keyPassword = "rhemn_2025"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
        // Use the latest AndroidX window dependencies for agora_rtc_engine and related plugins
        dependencies {
            implementation("androidx.window:window:1.2.0")
            implementation("androidx.window:window-java:1.2.0")
            implementation("androidx.window:window-extensions:1.0.0")
            implementation("androidx.window:window-sidecar:1.0.0")
        }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase Bill of Materials - synchronizes Firebase dependency versions
    implementation(platform("com.google.firebase:firebase-bom:34.0.0"))

    // ✅ Firebase SDKs
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-appcheck")
    implementation("com.google.firebase:firebase-messaging")

    // ✅ Kotlin and AndroidX dependencies
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.10")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")

    // ✅ Java 8+ desugaring support for backward compatibility
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
