// Android + Jetpack Compose UI layer — the mirror of the Swift `AksaraSwiftUI`
// module. It requires the Android Gradle Plugin and an installed Android SDK, so it
// is NOT part of the default Gradle build. Enable it by uncommenting
// `include(":aksara-compose")` in ../settings.gradle.kts once an SDK is available.
plugins {
    id("com.android.library") version "8.5.2"
    kotlin("android") version "2.0.21"
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21"
}

android {
    namespace = "com.aksara.compose"
    compileSdk = 34
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    api(project(":aksara-core"))
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.runtime:runtime")
}
