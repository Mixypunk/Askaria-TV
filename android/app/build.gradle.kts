import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Lecture du fichier key.properties (local ou généré en CI) ────────────────
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.mixypunk.askaria_tv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // ── Signing configs ──────────────────────────────────────────────────────
    signingConfigs {
        create("release") {
            // Priorité : key.properties → variables d'environnement CI
            keyAlias     = keystoreProperties["keyAlias"]?.toString()
                           ?: System.getenv("KEY_ALIAS")
            keyPassword  = keystoreProperties["keyPassword"]?.toString()
                           ?: System.getenv("KEY_PASSWORD")
            storePassword = keystoreProperties["storePassword"]?.toString()
                           ?: System.getenv("STORE_PASSWORD")
            val storeFilePath = keystoreProperties["storeFile"]?.toString()
                                ?: System.getenv("KEYSTORE_PATH")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
        }
    }

    defaultConfig {
        applicationId = "com.mixypunk.askaria_tv"
        minSdk        = 21
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        release {
            // ✅ Signature release (même clé à chaque build → MAJ acceptées)
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled  = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
