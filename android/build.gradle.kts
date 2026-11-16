// Use the shared Android dependency repositories.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Android output under the Flutter build folder.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Give each Android module a separate output folder.
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Remove generated build output when clean is requested.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
