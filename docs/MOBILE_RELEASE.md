# Mobile Release Checklist

## Current state

The game now has a shared touch-input layer for Android and iOS targets:

- Left-side virtual joystick for movement.
- Right-side drag area for camera look.
- Hold-to-sprint and tap-to-jump controls.
- Control sizing based on viewport dimensions.
- Godot Compatibility renderer configured for mobile.

This is input support, not yet an installable Android APK/AAB or iOS app. The project still needs export presets, platform export templates, signing configuration and physical-device QA.

## Android

1. Install the Godot 4.3 export templates matching the editor version.
2. Configure OpenJDK 17 and the Android SDK in Godot Editor Settings.
3. Add an Android export preset and set a permanent, unique package identifier.
4. Build a debug APK and install it on a real Android device.
5. Verify touch input, orientation, safe areas, resume/pause, audio and performance.
6. Create a release keystore and store it outside the repository. Never commit keystore files or passwords.
7. Produce a signed Android App Bundle (AAB) for Google Play release.

Official setup guide: https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html

## iOS

1. Use a macOS build environment with Xcode installed; Godot's iOS export process requires macOS and Xcode.
2. Install the matching Godot 4.3 export templates.
3. Add an iOS export preset with the final bundle identifier and Apple Developer Team ID.
4. Export the Xcode project and configure signing with an Apple Development/Distribution certificate and provisioning profile.
5. Build and install on a physical iPhone or iPad.
6. Verify touch input, safe areas, orientation, suspend/resume, audio, memory and sustained frame time.
7. Archive and distribute through TestFlight before App Store submission.

Official setup guide: https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_ios.html

## CI and secrets

- Android release signing material belongs in encrypted CI secrets, not in Git.
- iOS signing requires a macOS runner and protected signing assets/secrets.
- Do not create a public release until both platform exports and device tests pass.
- Keep debug builds separate from release builds.

## Device QA matrix

At minimum, test:

- One low-to-mid-range Android phone and one recent Android phone.
- One supported iPhone with a smaller display and one larger iPhone.
- Simultaneous joystick movement and camera drag.
- Sprint and jump while moving.
- Touch release/cancel behavior when the app loses focus.
- Landscape safe areas, notches and home indicators.
- Pause/resume, incoming interruptions, audio focus and thermal throttling.

Record device model, OS version, average frame time, memory use and any crashes for each test run.


## Player terms and privacy

The project includes an in-game first-run Terms & Conditions / Privacy Notice screen and a persistent LEGAL button. This is the player-facing agreement, not the developer's acceptance of the Google Play or Apple Developer distribution agreements. The publisher must accept those separately in Play Console and App Store Connect.

The current legal documents are development drafts: [Terms & Conditions](TERMS_OF_SERVICE.md), [Privacy Policy](PRIVACY_POLICY.md), and [Store Submission Checklist](STORE_SUBMISSION_CHECKLIST.md). Before store submission, complete the real publisher identity and support/privacy contact, obtain legal review, and host the final privacy policy at a stable, public, non-geofenced HTTPS URL.
