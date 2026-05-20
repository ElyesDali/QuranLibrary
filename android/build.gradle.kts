// 1. Dépôts standards
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 2. Gestion des dossiers de build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// 3. Tâche de nettoyage
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// 4. Correction automatique des namespaces (La partie critique qui bloquait)
subprojects {
    plugins.withId("com.android.application") {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
        }
    }
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
            // Fix ressource linking errors
            if (android.compileSdkVersion == null || 
                android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull()?.let { it < 34 } == true) {
                android.compileSdkVersion(34)
            }
        }
    }
}