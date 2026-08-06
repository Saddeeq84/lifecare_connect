# ========================================
# CRITICAL: Flutter Core - DO NOT REMOVE
# ========================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter Engine
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Keep all classes that extend FlutterPlugin
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$Registrar { *; }

# Keep all generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ========================================
# Firebase - Keep all classes
# ========================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep interface com.google.firebase.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepclassmembers class com.google.firebase.firestore.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keepclassmembers class com.google.firebase.auth.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }
-keepclassmembers class com.google.firebase.storage.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keepclassmembers class com.google.firebase.messaging.** { *; }

# AndroidX Window classes - Required for 16KB page size support
-keep class androidx.window.** { *; }
-keep class androidx.window.extensions.** { *; }
-keep class androidx.window.extensions.layout.** { *; }
-keep class androidx.window.extensions.area.** { *; }
-keep class androidx.window.sidecar.** { *; }
-keep class androidx.window.core.** { *; }
-keep class androidx.window.layout.** { *; }
-keep class androidx.window.layout.adapter.** { *; }
-keep class androidx.window.area.** { *; }
-dontwarn androidx.window.**
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**

# Keep classes referenced by androidx.window
-keep class * extends androidx.window.extensions.** { *; }
-keep class * implements androidx.window.extensions.** { *; }
-keep class * extends androidx.window.sidecar.** { *; }
-keep class * implements androidx.window.sidecar.** { *; }

# Agora RTC
-keep class io.agora.**{*;}
-dontwarn io.agora.**

# Apache Tika references the desktop StAX exception type from code paths that are
# not used on Android, but R8 still needs the optional class warning suppressed.
-dontwarn javax.xml.stream.XMLStreamException

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.examples.android.model.** { <fields>; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ========================================
# OkHttp & gRPC - FIX FOR MISSING CLASSES
# ========================================
# Keep OkHttp classes
-dontwarn com.squareup.okhttp.**
-keep class com.squareup.okhttp.** { *; }
-dontwarn okio.**
-keep class okio.** { *; }

# Keep gRPC classes
-dontwarn io.grpc.**
-keep class io.grpc.** { *; }
-keepclassmembers class io.grpc.** { *; }

# Keep OkHttp3 classes
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep interface okhttp3.** { *; }

# ========================================
# General Android optimizations - SAFER SETTINGS
# ========================================
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# DISABLE aggressive optimizations that can break Flutter
-dontoptimize
-dontpreverify
-dontshrink

-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference
-keep public class com.android.vending.licensing.ILicensingService

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

-keepclassmembers class * extends android.app.Activity {
   public void *(android.view.View);
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# ========================================
# CRITICAL: Keep model classes for Firestore
# ========================================
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName *;
}
-keepclassmembers class * {
  @com.google.firebase.firestore.ServerTimestamp *;
}
-keepclassmembers class * {
  @com.google.firebase.firestore.DocumentId *;
}

# Keep all model classes that might be used with Firestore
-keep class * implements java.io.Serializable { *; }

# ========================================
# Reflection - Keep classes accessed via reflection
# ========================================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ========================================
# Crashlytics/Firebase
# ========================================
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ========================================
# Keep all native methods
# ========================================
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# ========================================
# CRITICAL: Prevent stripping of View constructors
# ========================================
-keepclassmembers class * extends android.view.View {
   public <init>(android.content.Context);
   public <init>(android.content.Context, android.util.AttributeSet);
   public <init>(android.content.Context, android.util.AttributeSet, int);
}
