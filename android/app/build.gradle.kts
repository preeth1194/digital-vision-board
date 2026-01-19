import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Needed for Firebase config (google-services.json)
    id("com.google.gms.google-services") apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Allow local/dev builds without Firebase config.
// If `google-services.json` is present, enable Google Services processing.
if (file("google-services.json").exists() || file("src/debug/google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("google-services.json not found; skipping com.google.gms.google-services")
}

// Load keystore properties from key.properties file if it exists
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Remove old package directories to prevent duplicate class errors
tasks.register("cleanOldPackage") {
    doLast {
        val oldExampleDir = file("src/main/kotlin/com/example")
        val oldIntentDir = file("src/main/kotlin/com/intent")
        if (oldExampleDir.exists()) {
            logger.warn("Removing old package directory: ${oldExampleDir.absolutePath}")
            oldExampleDir.deleteRecursively()
        }
        if (oldIntentDir.exists()) {
            logger.warn("Removing old package directory: ${oldIntentDir.absolutePath}")
            oldIntentDir.deleteRecursively()
        }
    }
}

// Ensure old package is removed before compilation
tasks.named("preBuild").configure {
    dependsOn("cleanOldPackage")
}

android {
    namespace = "com.digitalvisionboard.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Application ID for Google Play - must be unique and not use com.example
        applicationId = "com.digitalvisionboard.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePasswordValue = keystoreProperties.getProperty("storePassword")
            val keyAliasValue = keystoreProperties.getProperty("keyAlias")
            val keyPasswordValue = keystoreProperties.getProperty("keyPassword")

            if (storeFilePath != null &&
                storePasswordValue != null &&
                keyAliasValue != null &&
                keyPasswordValue != null
            ) {
                // Resolve keystore path relative to android directory
                val keystoreFile = rootProject.file(storeFilePath)
                if (keystoreFile.exists()) {
                    storeFile = keystoreFile
                    storePassword = storePasswordValue
                    keyAlias = keyAliasValue
                    keyPassword = keyPasswordValue
                } else {
                    logger.warn("Keystore file not found: ${keystoreFile.absolutePath}")
                }
            }
        }
    }

    buildTypes {
        release {
            // Use release signing if `android/key.properties` is present; otherwise fall back to debug
            // so local `flutter run --release` still works without secrets.
            signingConfig =
                if (keystorePropertiesFile.exists()) {
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
    // Required by flutter_local_notifications (and other plugins) for Java 8+ library APIs on Android.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
