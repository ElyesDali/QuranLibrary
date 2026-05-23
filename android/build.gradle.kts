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

// Correctif "Sniper" : On cible UNIQUEMENT le plugin problématique
subprojects {
    val configurePlugin = { p: Project ->
        p.plugins.withId("com.android.library") {
            val androidExt = p.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                // 1. Répare l'erreur de Namespace pour tous les anciens plugins
                if (androidExt.namespace == null) {
                    androidExt.namespace = p.group.toString()
                }
                
                // 2. On force EXACTEMENT SDK 31 pour flutter_media_metadata
                // (31 = assez récent pour lStar, assez vieux pour éviter IOException)
                if (p.name == "flutter_media_metadata") {
                    androidExt.compileSdk = 31
                }
                // NOTE: On ne met PAS de "else". sqflite gardera son SDK 35 !
            }
        }
    }

    if (project.state.executed) {
        configurePlugin(project)
    } else {
        project.afterEvaluate { configurePlugin(this) }
    }
}