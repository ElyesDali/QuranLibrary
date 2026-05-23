allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Correctif chirurgical : SDK 31 pour le plugin capricieux, SDK 34 pour le reste
subprojects {
    val configurePlugin = { p: Project ->
        p.plugins.withId("com.android.library") {
            val androidExt = p.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                // 1. Répare l'erreur de Namespace
                if (androidExt.namespace == null) {
                    androidExt.namespace = p.group.toString()
                }
                
                // 2. Le "Sweet Spot" pour contourner l'erreur IOException
                if (p.name == "flutter_media_metadata") {
                    androidExt.compileSdk = 31
                } else {
                    androidExt.compileSdk = 34
                }
            }
        }
    }

    if (project.state.executed) {
        configurePlugin(project)
    } else {
        project.afterEvaluate { configurePlugin(this) }
    }
}