# Architecture decisions

## 2026-11-05 — iOS 16.0 minimum; ML Kit iOS translation

**Status:** Accepted and applied.

### Decision

- Set the iOS app's minimum deployment target to **iOS 16.0** for both the Xcode project configurations and the VibeSyncIOSApp target configurations.
- Set the Kotlin/Native iOS device and simulator framework minimum to **iOS 16.0** using the Kotlin 2.2.21 target-specific compiler properties **-Xoverride-konan-properties=osVersionMin.ios_arm64=16.0;osVersionMin.ios_simulator_arm64=16.0**. Both properties are set explicitly because Kotlin 2.2.21's simulator property is not derived from minVersion.ios.
- Use **Google ML Kit for iOS Translation** as the planned on-device translation provider. Do not use Apple's Translation framework for this product requirement.

### Rationale

The SwiftUI scaffold uses NavigationStack, which is native from iOS 16. Matching the Xcode app and Kotlin framework minimums avoids a deployment-target mismatch at link time. Kotlin 2.2.21 exposes target-specific osVersionMin properties; the iOS device and simulator values are both overridden explicitly because the simulator property is independently defined in the plugin's konan.properties.

Google's ML Kit iOS guidance documents iOS **15.5 or later** and 64-bit architecture support. Its Translation API runs on-device and downloads language-specific models to the device as needed. Therefore ML Kit can support the app's iOS 16.0 floor without depending on Apple's iOS 18 Translation framework availability.

References:
- Kotlin/Native target support and minVersion.ios compiler property: https://kotlinlang.org/docs/native-target-support.html
- ML Kit iOS prerequisites (iOS 15.5+, 64-bit): https://developers.google.com/ml-kit/migration/ios
- ML Kit iOS Translation (on-device API and downloadable language models): https://developers.google.com/ml-kit/language/translation/ios

### Reach trade-off

The product accepts dropping iOS 15.x devices and older unsupported devices in exchange for native NavigationStack and a consistent iOS 16.0 platform baseline. An expected **95%+ device reach** is accepted as a launch-planning assumption for this new app; it is not a measurement from this repository's analytics and should be checked against launch-market device data.

Reverting the app minimum to iOS 15 would require an **AdaptiveNavigation wrapper** that uses NavigationStack on iOS 16+ and a compatible NavigationView fallback on iOS 15. The Xcode app and Kotlin/Native framework deployment targets would both need to be lowered together.


## 2026-11-06 — iOS visual verification, PDF signatures and OCR translation

**Status:** Implemented in the iOS target.

- CI boots an iOS Simulator, installs and launches VibeSync, and uploads light/dark home plus ID Card Composer, Signature Manager and Translation screen screenshots as the `VibeSyncIOS-Visual-Screenshots` artifact.
- Signature Manager now imports an existing PDF, previews a selected page, lets the user place/size/rotate a saved Keychain signature, embeds the image into a new multi-page PDF with PDFKit and UIGraphicsPDFRenderer, and presents the system save picker.
- The common iOS `OcrEngine` provider is backed by Apple Vision (`VNRecognizeTextRequest`) and wired to image/PDF imports.
- `IosMLKitTranslator` uses Google ML Kit Translation with on-device language models. The UI discloses model downloads and restricts them to Wi-Fi.
- Both iOS build and simulator-stream workflows install CocoaPods and build the generated Xcode workspace. No Android app sources are modified.
