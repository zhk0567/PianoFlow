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

fun Project.applyCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    val methods = android.javaClass.methods
    val setter = methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
    if (setter != null) {
        val p0 = setter.parameterTypes[0]
        when {
            p0 == Int::class.javaPrimitiveType || p0 == Integer::class.java ->
                setter.invoke(android, 36)
            p0 == String::class.java ->
                setter.invoke(android, "36")
            else -> setter.invoke(android, 36)
        }
        return
    }
    // Older AGP: compileSdkVersion("android-36")
    methods.firstOrNull {
        it.name == "compileSdkVersion" && it.parameterCount == 1
    }?.invoke(android, "android-36")
}

subprojects {
    val action = Action<Project> { applyCompileSdk36() }
    if (state.executed) {
        action.execute(this)
    } else {
        afterEvaluate(action)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
