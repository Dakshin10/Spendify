allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    if (project.name == "telephony") {
        val configureNamespace = {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension != null) {
                try {
                    val baseExt = androidExtension as? com.android.build.gradle.BaseExtension
                    baseExt?.namespace = "com.shounakmulay.telephony"
                } catch (e: Exception) {
                    try {
                        androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                            .invoke(androidExtension, "com.shounakmulay.telephony")
                    } catch (e2: Exception) {
                        // ignore if both fail
                    }
                }
            }
        }
        if (project.state.executed) {
            configureNamespace()
        } else {
            project.afterEvaluate {
                configureNamespace()
            }
        }
    }
}
