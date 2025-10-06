import com.sdds.plugin.themebuilder.OutputLocation.SRC
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
    id("convention.compose")
    id("convention.maven-publish")
    alias(libs.plugins.themebuilder)
    id("convention.docusaurus")
}

android {
    namespace = "$themePackage.compose"
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
    compose()
    ktPackage(themePackage)
    mode(THEME)
    autoGenerate(false)
    outputLocation(SRC)
}

dependencies {
    implementation(libs.sdds.uikit.compose)
    implementation(libs.sdds.icons)
    implementation(libs.base.androidX.compose.foundation)
}

val Project.themePackage: String
    get() = properties["theme-package"]?.toString()
        ?: throw GradleException("theme-package must be specified for ThemeBuilder to work")