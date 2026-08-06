// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

android {
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    namespace = "com.lifecare_connect"
    compileSdk = 36 // Use 36 for latest plugin and Play Store support (API 36)
    ndkVersion = "27.0.12077973" // NDK r27+ required for latest plugins and 16 KB page size support

    defaultConfig {
        applicationId = "com.lifecare_connect"
        // cloud_firestore requires Android API level 23 or higher.
        minSdk = 23
        targetSdk = 36 // Target Android 15+ for 16KB page size support
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // ✅ Required for large apps using many methods (e.g., Firebase)
        
        // Keep release bundles to phone/tablet ABIs; x86_64 is emulator-only and
        // adds another expensive AOT snapshot during appbundle builds.
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ For Java 8+ APIs on lower API levels
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
            // Keep release code intact. R8 is expensive on this project and can
            // fail on optional desktop-only classes from transitive libraries.
            isMinifyEnabled = false
            isShrinkResources = false // DISABLE resource shrinking - can cause issues
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
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
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.3.0")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.window:window:1.3.0")
    implementation("androidx.window:window-java:1.3.0")

    // ✅ Java 8+ desugaring support for backward compatibility
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
