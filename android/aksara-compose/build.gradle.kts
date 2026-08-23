// Android + Jetpack Compose UI layer — the mirror of the Swift `AksaraSwiftUI` module.
// It requires the Android Gradle Plugin and an installed Android SDK, so it's excluded
// from the default build (see ../settings.gradle.kts) and only configured when building
// with `-PwithAndroid`. Publishing produces an AAR.
plugins {
    id("com.android.library")
    kotlin("android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.vanniktech.maven.publish")
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
    buildFeatures {
        compose = true
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    api(project(":aksara-core"))
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.runtime:runtime")
}

mavenPublishing {
    // groupId + version come from gradle.properties (GROUP / VERSION_NAME).
    // Vanniktech auto-configures the Android release variant (AAR + sources).
    coordinates(artifactId = "aksara-compose")
    publishToMavenCentral(com.vanniktech.maven.publish.SonatypeHost.CENTRAL_PORTAL)
    signAllPublications()
    pom {
        name.set("Aksara Compose")
        description.set("Jetpack Compose bindings for Aksara — locString() that recomposes on language switch / OTA update.")
        inceptionYear.set("2026")
        url.set("https://github.com/iQbalADR/aksara")
        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
                distribution.set("repo")
            }
        }
        developers {
            developer {
                id.set("iQbalADR")
                name.set("iQbalADR")
                url.set("https://github.com/iQbalADR")
            }
        }
        scm {
            url.set("https://github.com/iQbalADR/aksara")
            connection.set("scm:git:git://github.com/iQbalADR/aksara.git")
            developerConnection.set("scm:git:ssh://git@github.com/iQbalADR/aksara.git")
        }
    }
}
