pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "android-template"

includeBuild("build-system")
includeBuild("compose-project")
includeBuild("xml-project")