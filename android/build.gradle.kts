// Root build script. Plugin versions are declared here (apply false) and applied in
// the modules.
plugins {
    kotlin("jvm") version "2.4.10" apply false
    kotlin("plugin.serialization") version "2.4.10" apply false
    id("com.vanniktech.maven.publish") version "0.30.0" apply false
}
