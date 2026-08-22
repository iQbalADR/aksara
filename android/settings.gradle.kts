pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
        google()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}

rootProject.name = "aksara"

include(":aksara-core")

// The Compose/Android UI layer requires the Android Gradle Plugin + Android SDK, so
// it is not part of the default build. Enable it once an Android SDK is available:
//   include(":aksara-compose")
