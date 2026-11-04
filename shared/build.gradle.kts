plugins {
    kotlin("multiplatform")
    id("com.android.library")
}

kotlin {
    androidTarget()

    // Produce a static framework that can be linked directly by the SwiftUI Xcode target.
    // Keep the device target available while CI validates the arm64 simulator target.
    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { target ->
        target.binaries.configureEach {
            // Match the Xcode app target; Kotlin/Native defaults to iOS 15.0.
            freeCompilerArgs += "-Xoverride-konan-properties=minVersion.ios=16.0"
        }
        target.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
        }
    }
}

android {
    namespace = "com.vibesync.shared"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }
}
