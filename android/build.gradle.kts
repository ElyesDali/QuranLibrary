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

// Correctif ultra-sécurisé pour le Namespace ET l'erreur lStar
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            // 1. Répare l'erreur de Namespace
            if (androidExt.namespace == null) {
                androidExt.namespace = project.group.toString()
            }
            // 2. Répare l'erreur "lStar not found" en forçant le SDK récent
            androidExt.compileSdkVersion(34)
        }
    }
}