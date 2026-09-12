// Root build script. All plugin versions are declared here (apply false) and applied
// without versions in the modules — required for a mixed JVM + Android build so the
// Kotlin plugin isn't requested twice on the classpath.
plugins {
    kotlin("jvm") version "2.4.20" apply false
    kotlin("android") version "2.4.20" apply false
    kotlin("plugin.serialization") version "2.4.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.20" apply false
    id("com.android.library") version "9.4.0" apply false
    id("com.vanniktech.maven.publish") version "0.37.0" apply false
}
