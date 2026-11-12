import java.util.Properties

// Upload signing key. Kept out of the repo (see .gitignore) because a leaked
// key lets somebody else sign a build as this app, and a lost one means the
// listing can never be updated again.
//
// Debug builds do not require it. Every release task refuses to run without
// the upload key, so an accidental debug-signed bundle cannot be shipped.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// Device tests use a separate package so installing them cannot erase a
// member's existing app or journal session on the emulator.
val isQaBuild = providers.gradleProperty("innenflowTestBuild").orNull == "true"
val hasUploadKey = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.brahma.brahmaApp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // BuildConfig is off by default from AGP 8. MainActivity reads
    // BuildConfig.DEBUG to decide whether FLAG_SECURE is applied, which is what
    // guarantees a release build is always screenshot-protected.
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (isQaBuild) "com.brahma.brahmaApp.qa" else "com.brahma.brahmaApp"
        multiDexEnabled = true
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // The task-graph guard below requires the upload key for releases.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

tasks.matching { it.name.endsWith("GoogleServices") }.configureEach {
    enabled = !isQaBuild
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") }) {
        check(!isQaBuild) { "QA packages must never be built for release." }
        check(hasUploadKey) { "A release requires the existing Play upload key; debug signing is forbidden." }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
