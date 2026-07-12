plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Tambahkan baris ini di bawahnya:
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.agrifis"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        // Aktifkan Desugaring di sini
        isCoreLibraryDesugaringEnabled = true 
        
        // Java 17 sudah mencakup Java 8, jadi ini sudah benar
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.agrifis"
        
        // Paksa minSdk ke 21 jika masih error, 
        // karena desugaring bekerja maksimal di minSdk 21+
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Tambahkan ini jika build masih gagal karena limit method
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Naikkan versinya ke 2.1.4 sesuai permintaan error
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
