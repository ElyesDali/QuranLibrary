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

// Correctif blindé : Vérifie l'état d'évaluation avant d'agir
subprojects {
    val configurePlugin = { p: Project ->
        p.plugins.withId("com.android.library") {
            val androidExt = p.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                // 1. Répare l'erreur de Namespace
                if (androidExt.namespace == null) {
                    androidExt.namespace = p.group.toString()
                }
                // 2. Répare l'erreur "lStar not found"
                androidExt.compileSdk = 34
            }
        }
    }

    if (project.state.executed) {
        // Déjà évalué, on applique tout de suite !
        configurePlugin(project)
    } else {
        // Pas encore évalué, on le programme !
        project.afterEvaluate { configurePlugin(this) }
    }
}