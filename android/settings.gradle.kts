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

// The Compose/Android UI layer needs the Android Gradle Plugin + Android SDK, so it's
// excluded from the default build (keeps `:aksara-core:test` runnable without an SDK).
// The publish workflow — and anyone with an Android SDK — opts in with `-PwithAndroid`.
if (providers.gradleProperty("withAndroid").isPresent) {
    include(":aksara-compose")
}
