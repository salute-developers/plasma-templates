import com.sdds.plugin.themebuilder.OutputLocation.SRC
import com.sdds.plugin.themebuilder.ShapeAppearanceConfig.Companion.sddsShape
import com.sdds.plugin.themebuilder.ThemeBuilderMode.THEME
import utils.componentsName
import utils.componentsVersion
import utils.themeAlias
import utils.themeName
import utils.themeResPrefix
import utils.themeVersion

@Suppress("DSL_SCOPE_VIOLATION")
plugins {
    id("convention.android-lib")
    alias(libs.plugins.themebuilder)
    id("convention.maven-publish")
    id("convention.docusaurus")
}

android {
    namespace = "com.sdds.serv"
    resourcePrefix = themeResPrefix
}

themeBuilder {
    themeSource {
        url("file:///${projectDir.absolutePath}/theme.zip")
        name(themeAlias)
    }
    componentSource {
        url("file:///${projectDir.absolutePath}/components.zip")
        name(themeAlias)
    }
    view{
        themeParents {
            materialComponentsTheme()
        }
        setupShapeAppearance(sddsShape())
    }
    ktPackage(themePackage)
    autoGenerate(false)
    mode(THEME)
    outputLocation(SRC)
}

dependencies {
    implementation(libs.sdds.icons)
    implementation(libs.sdds.uikit)
    implementation(libs.base.androidX.core)
    implementation(libs.base.androidX.appcompat)
}

val Project.themePackage: String
    get() = properties["theme-package"]?.toString()
        ?: throw GradleException("theme-package must be specified for ThemeBuilder to work")