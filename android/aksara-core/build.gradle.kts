plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    id("com.vanniktech.maven.publish")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")

    testImplementation(kotlin("test-junit"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
}

tasks.test {
    useJUnit()
    testLogging { events("passed", "failed", "skipped") }
}

mavenPublishing {
    // groupId + version come from gradle.properties (GROUP / VERSION_NAME).
    coordinates(artifactId = "aksara-core")
    publishToMavenCentral(com.vanniktech.maven.publish.SonatypeHost.CENTRAL_PORTAL)
    signAllPublications()
    pom {
        name.set("Aksara Core")
        description.set("Cross-platform live localization runtime — Kotlin core: flattened O(1) loader, CLDR plurals, {{var}} interpolation, and OTA updates.")
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
