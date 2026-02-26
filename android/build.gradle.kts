allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Fix for old plugins that don't declare a namespace (required by AGP 8+)
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExt.namespace.isNullOrEmpty()) {
            val manifest = file("src/main/AndroidManifest.xml")
            if (manifest.exists()) {
                val pkg = Regex("""package\s*=\s*"([^"]+)"""")
                    .find(manifest.readText())?.groupValues?.get(1)
                if (!pkg.isNullOrEmpty()) {
                    androidExt.namespace = pkg
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
