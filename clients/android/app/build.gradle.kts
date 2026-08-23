plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.pianoflow.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.pianoflow.android"
        minSdk = 26
        targetSdk = 36
        versionCode = 2
        versionName = "0.2.0-win-parity"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

// Sync scores / piano wav / verovio from repo assets before packaging.
tasks.register<Exec>("syncNativeAssets") {
    val repoRoot = rootProject.projectDir.parentFile.parentFile
    workingDir = repoRoot
    commandLine(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        repoRoot.resolve("scripts/sync-android-native-assets.ps1").absolutePath,
    )
}

tasks.named("preBuild").configure {
    dependsOn("syncNativeAssets")
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.webkit:webkit:1.12.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
