# App Store and AdMob release setup

This guide covers the iOS-specific Google AdMob identifiers, the unsigned device IPA produced by GitHub Actions, and the remaining signing step for TestFlight.

## 1. Create the iOS app in AdMob

1. Sign in at [Google AdMob](https://admob.google.com/).
2. Open **Apps** and choose **Add app**.
3. Select **iOS**. When asked whether the app is already published in an app store, choose **No** until the iOS app is live. Name it **VibeSync PDF Suite** (or another recognizable name) and add it.
4. Open the new app in AdMob. Copy its **App ID**.
5. Open **Ad units** and choose **Add ad unit**. Create one **Banner** unit and one **Interstitial** unit. Copy each unit ID after creation.

The identifiers have different formats:

- **App ID**: ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY (contains a tilde, ~).
- **Ad unit ID**: ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY (contains a slash, /). Create separate IDs for Banner and Interstitial.

Google's help pages: [Add an app and create ad units](https://support.google.com/admob/answer/15948559), [find and copy App ID / ad unit IDs](https://support.google.com/admob/answer/7356431).

## 2. Paste the IDs into the iOS Release build settings

Do **not** paste production IDs into Android, and do not hard-code them in AdMobProvider.swift. This iOS implementation reads the values from the built app's Info.plist.

Open iosApp/VibeSyncIOS.xcodeproj in Xcode, select the **VibeSyncIOSApp** target, open **Build Settings**, select **All**, and search for each user-defined setting below. Set the value in the **Release** configuration only:

| Xcode build setting | Paste this AdMob value |
|---|---|
| **ADMOB_APP_ID** | The iOS app's **App ID** |
| **ADMOB_BANNER_AD_UNIT_ID** | The **Banner** ad unit ID |
| **ADMOB_INTERSTITIAL_AD_UNIT_ID** | The **Interstitial** ad unit ID |

Alternatively, edit iosApp/VibeSyncIOS.xcodeproj/project.pbxproj and replace the three REPLACE_WITH_IOS_... values in the **VibeSyncIOSApp → Release** build configuration. Keep the three Debug values as Google's iOS test IDs.

The mapping is already wired in iosApp/VibeSyncIOSApp/Info.plist:

- **GADApplicationIdentifier** ← **$(ADMOB_APP_ID)**
- **ADMOB_BANNER_AD_UNIT_ID** ← **$(ADMOB_BANNER_AD_UNIT_ID)**
- **ADMOB_INTERSTITIAL_AD_UNIT_ID** ← **$(ADMOB_INTERSTITIAL_AD_UNIT_ID)**

AdMobProvider.swift reads those three Info.plist keys. No Swift source changes are needed after the Release build settings are populated. The Release placeholders intentionally prevent the SDK from initializing until genuine iOS values are supplied.

**Use only identifiers created for this iOS app.** Android App IDs and Android ad unit IDs are not interchangeable with iOS IDs. Do not put a Banner unit ID into the App ID field.

## 3. Test ads safely before production

The Debug configuration intentionally retains Google's iOS demo identifiers. Keep these while running simulator tests and development builds. Google documents its demo IDs and warns developers to use test ads during development to avoid invalid-traffic enforcement: [Google Mobile Ads iOS test ads](https://developers.google.com/admob/ios/test-ads).

For a physical-device smoke test using your own AdMob units, register that iPhone as a **test device** in AdMob before making ad requests. Do not click live ads during testing. A newly created ad unit may also need time before it begins serving ads.

## 4. Build and install the unsigned IPA with Sideloadly

1. Push the Release AdMob build-setting changes to main, or make the equivalent settings change in your local Xcode project.
2. Open the repository's **Actions** tab and select the **iOS Device Archive and Simulator Tests** workflow.
3. Open the completed run for the commit you want to test. In **Artifacts**, download **VibeSyncIOSApp-iOS-Unsigned-IPA**.
4. Connect and unlock the iPhone, open Sideloadly on the computer, drag the downloaded .ipa into it, select the connected device, sign in with the Apple Account that Sideloadly will use for re-signing, and start the sideload.
5. On iOS 16 or later, enable **Settings → Privacy & Security → Developer Mode** if iOS requests it, then restart and confirm. If iOS asks you to trust the signing account, use **Settings → General → VPN & Device Management**.

The workflow builds the app for the physical-device iphoneos platform and arm64, disables Xcode code signing, and packages the unsigned app as a standard Payload/VibeSyncIOSApp.app IPA. Sideloadly must re-sign the app with an Apple-issued signing identity/provisioning profile before iOS will install it; the raw unsigned IPA is not directly installable. See [Sideloadly's FAQ](https://sideloadly.io/faq.html) and [OWASP's IPA signing overview](https://mas.owasp.org/MASTG/techniques/ios/MASTG-TECH-0092/).

## 5. TestFlight is a separate, signed distribution step

The unsigned IPA is for physical-device smoke testing through a re-signing tool. It is **not** a TestFlight upload artifact. TestFlight distribution requires the app to be archived and signed for App Store distribution with the appropriate Apple Developer team, provisioning, and App Store Connect setup. Once those credentials are available, change the workflow to export a signed App Store archive/IPA; do not upload this unsigned artifact to App Store Connect.
