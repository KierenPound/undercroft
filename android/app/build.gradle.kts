import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.isFile) {
        releaseSigningPropertiesFile.inputStream().use(::load)
    }
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun resolveKeystorePath(path: String): String =
    if (path.startsWith("~/")) {
        System.getProperty("user.home") + path.substring(1)
    } else {
        path
    }

if (releaseBuildRequested) {
    if (!releaseSigningPropertiesFile.isFile) {
        throw GradleException(
            "Android release signing is not configured. " +
                "See android/RELEASE_SIGNING.md."
        )
    }

    val requiredProperties = listOf(
        "storeFile",
        "storePassword",
        "keyAlias",
        "keyPassword",
    )
    val missingProperties = requiredProperties.filter {
        releaseSigningProperties.getProperty(it).isNullOrBlank()
    }
    if (missingProperties.isNotEmpty()) {
        throw GradleException(
            "Missing ${missingProperties.joinToString()} in android/key.properties."
        )
    }

    val storeFilePath = resolveKeystorePath(
        releaseSigningProperties.getProperty("storeFile")
            ?: throw GradleException("Missing storeFile in android/key.properties.")
    )
    if (!rootProject.file(storeFilePath).isFile) {
        throw GradleException(
            "Android release keystore was not found at: $storeFilePath"
        )
    }
}

android {
    namespace = "com.undercroft.undercroft"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            keyAlias = releaseSigningProperties.getProperty("keyAlias")
            keyPassword = releaseSigningProperties.getProperty("keyPassword")
            storeFile = releaseSigningProperties.getProperty("storeFile")?.let {
                rootProject.file(resolveKeystorePath(it))
            }
            storePassword = releaseSigningProperties.getProperty("storePassword")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kierenpound.undercroft"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
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
