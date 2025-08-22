// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.lifecare_connect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Optional: Use only if you're relying on NDK features

    defaultConfig {
        applicationId = "com.lifecare_connect"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
    versionCode = 8 // Increased from 7 to 8
    versionName = "1.0.8" // Updated version name
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
