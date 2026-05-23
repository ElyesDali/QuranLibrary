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

// Aggressive override for older plugins (Namespace and compileSdk)
subprojects {
    afterEvaluate {
        val pluginProject = this
        // Check if the project is an Android library (which Flutter plugins are)
        if (pluginProject.plugins.hasPlugin("com.android.library")) {
            val androidExt = pluginProject.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                // 1. Fix the Namespace error
                if (androidExt.namespace == null) {
                    androidExt.namespace = pluginProject.group.toString()
                }
                // 2. Force compileSdk to 34 to resolve lStar resource error
                androidExt.compileSdk = 34
            }
        }
    }
}