plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStore = System.getenv("MUNORA_KEYSTORE_PATH")
val releaseAlias = System.getenv("MUNORA_KEY_ALIAS")
val releaseStorePassword = System.getenv("MUNORA_KEYSTORE_PASSWORD")
val releaseKeyPassword = System.getenv("MUNORA_KEY_PASSWORD")
val releaseSigningReady = listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword)
    .all { !it.isNullOrBlank() }

android {
    namespace = "com.example.munora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.munora"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningReady) {
                storeFile = file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") &&
        (name.startsWith("package") || name.startsWith("bundle") || name.startsWith("assemble"))) {
        doFirst {
            check(releaseSigningReady) {
                "Release signing is required. Configure the four MUNORA_KEY* environment variables documented in docs/audit/RELEASE_CHECKLIST.md."
            }
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
