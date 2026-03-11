allprojects {
    repositories {
        // Local fallback for transitive plugin artifacts when JitPack is unavailable.
        maven(url = rootProject.file("local-maven").toURI())
        google()
        mavenCentral()
        // Restrict JitPack to GitHub-hosted artifacts only (e.g. com.github.Yalantis:ucrop)
        // so Flutter's io.flutter artifacts do not get resolved from JitPack.
        maven(url = "https://jitpack.io") {
            content {
                includeGroupByRegex("com\\.github\\..*")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
