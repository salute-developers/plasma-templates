// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    id("convention.root-project")
    alias(libs.plugins.android.app) apply false
    alias(libs.plugins.android.lib) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.android.cache.fix) apply false
    alias(libs.plugins.gradlePluginPublish) apply false
    alias(libs.plugins.themebuilder) apply false
}

buildscript {
    dependencies {
        classpath(libs.base.gradle.detekt)
        classpath(libs.base.gradle.spotless)
    }
}