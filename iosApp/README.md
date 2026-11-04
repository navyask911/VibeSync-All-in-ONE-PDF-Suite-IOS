# iOS application scaffold

This directory contains a minimal SwiftUI application and Xcode project. The app links the Kotlin Multiplatform `Shared.framework` produced by the existing `shared` module.

## Build the iOS Simulator target

Requirements: macOS, Xcode with an iOS Simulator SDK, and JDK 17.

From the repository root:

```bash
xcodebuild \
  -project iosApp/VibeSyncIOS.xcodeproj \
  -scheme VibeSyncIOSApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The Xcode target's first build phase invokes:

```bash
cd android
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

The generated static framework is linked from `shared/build/bin/iosSimulatorArm64/debugFramework/Shared.framework`.

## Gradle plugin configuration

The repository already declares Kotlin Multiplatform `2.2.21` in `android/build.gradle.kts` and applies `kotlin("multiplatform")` in `shared/build.gradle.kts`. No CocoaPods or Compose Multiplatform plugin is required for this SwiftUI + KMP framework bridge. The shared Gradle script configures static frameworks for `iosArm64` and `iosSimulatorArm64`.

The shared module is still a skeleton. This app only calls the existing `KmpCheck` diagnostic; it does not migrate Android business logic.
