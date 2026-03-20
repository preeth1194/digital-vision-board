# =============================================================================
# ProGuard / R8 rules — Habit Seeding (Digital Vision Board)
# =============================================================================

# ---------------------------------------------------------------------------
# Flutter engine
# ---------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }

# ---------------------------------------------------------------------------
# App entry points & widget receivers
# ---------------------------------------------------------------------------
-keep class com.habitseeding.app.** { *; }

# ---------------------------------------------------------------------------
# Firebase / Google Play Services
# ---------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---------------------------------------------------------------------------
# Google Sign-In
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }

# ---------------------------------------------------------------------------
# Google Mobile Ads (AdMob)
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ---------------------------------------------------------------------------
# RevenueCat
# ---------------------------------------------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# ---------------------------------------------------------------------------
# flutter_local_notifications
# ---------------------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ---------------------------------------------------------------------------
# geolocator / geocoding
# ---------------------------------------------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.**

# ---------------------------------------------------------------------------
# image_cropper (uCrop)
# ---------------------------------------------------------------------------
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# ---------------------------------------------------------------------------
# audioplayers / record
# ---------------------------------------------------------------------------
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.llfbandit.record.** { *; }

# ---------------------------------------------------------------------------
# Kotlin & coroutines (required by many plugins)
# ---------------------------------------------------------------------------
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ---------------------------------------------------------------------------
# OkHttp / Okio (used by network plugins)
# ---------------------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ---------------------------------------------------------------------------
# JSON / serialisation
# ---------------------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ---------------------------------------------------------------------------
# Suppress common benign warnings
# ---------------------------------------------------------------------------
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
