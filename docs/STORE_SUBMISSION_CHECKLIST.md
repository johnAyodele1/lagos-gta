# Google Play and Apple App Store Submission Checklist

This checklist separates **player-facing game terms** from the **developer agreements** required to publish an app.

## Important distinction

The in-game Terms & Conditions checkbox is an agreement between the game publisher and the player. It does not accept Google's Play Console Developer Distribution Agreement or Apple's Developer Program License Agreement on the publisher's behalf. The account owner must personally review and accept the current developer agreements in the respective consoles.

Store approval cannot be guaranteed by code. Store rules change and reviewers assess the final binary, metadata, privacy declarations, age rating, assets and actual behaviour.

## Player-facing legal experience

- [x] First-launch legal screen with separate Terms & Conditions and Privacy Notice tabs.
- [x] Explicit unchecked agreement checkbox; no pre-ticked consent.
- [x] Accept button disabled until the player checks the agreement.
- [x] Decline exits the game without entering gameplay.
- [x] Consent version and timestamp stored locally.
- [x] A persistent LEGAL button allows later review.
- [x] Increment the in-game legal version when material terms or consent scope changes.
- [ ] Replace draft publisher/contact information with the real legal publisher identity and monitored address.
- [ ] Obtain qualified legal review for target territories.
- [ ] Publish the final privacy policy at a public, stable, non-geofenced HTTPS URL.
- [ ] Publish final Terms & Conditions at a public, stable HTTPS URL.
- [ ] Ensure policy text, app behaviour, SDK inventory and store disclosures remain consistent.

## Google Play

- [ ] Create/verify the Play Console developer account and accept the current developer agreement.
- [ ] Complete App content, target audience, content rating and Data safety declarations accurately.
- [ ] Add the public privacy-policy URL in Play Console and provide an in-app route to it.
- [ ] Declare every SDK and every data type collected, shared or processed.
- [ ] Provide account deletion in-app and on an external web resource if account creation is introduced.
- [ ] Upload a signed Android App Bundle (AAB), configure app signing and complete required testing tracks.
- [ ] Supply accurate title, description, screenshots, icon, feature graphic and support contact.
- [ ] Confirm the app meets current Android API target, device compatibility and Play quality requirements.

## Apple App Store

- [ ] Enrol in the Apple Developer Program and accept the current programme agreement.
- [ ] Create the App Store Connect app record, bundle identifier and signing configuration.
- [ ] Add the publicly accessible privacy-policy URL to App Store Connect.
- [ ] Complete App Privacy details to match the binary, SDKs, backend and actual data practices.
- [ ] If account creation is introduced, provide in-app account deletion.
- [ ] Complete age rating, export compliance, content rights and other required metadata.
- [ ] Archive and upload a signed build; test through TestFlight before review.
- [ ] Supply review notes and a working demo account only if account-gated functionality is added.

## Assets, rights and geographic data

- [ ] Use original or properly licensed models, textures, sounds, fonts and animations.
- [ ] Do not use GTA/Rockstar logos, game assets, audio or copied map data.
- [ ] Keep a third-party asset register with source, licence, attribution and redistribution rights.
- [ ] If using OpenStreetMap data, comply with ODbL and attribution requirements.
- [ ] Avoid depicting identifiable private people or publishing private addresses/phone numbers without permission.

## Low-budget device quality gates

- [ ] Set minimum supported OS/device specifications based on measured results, not assumptions.
- [ ] Profile on real entry-level Android devices and supported iPhones.
- [ ] Measure average and 1% low frame rate, frame time, memory, thermal behaviour, load time and battery impact.
- [ ] Test at reduced render resolution and low texture quality.
- [ ] Verify no stuck touch controls after interruptions, screen lock, app switching or incoming calls.
- [ ] Test landscape safe areas, notches, home indicators, pause/resume and audio focus.
- [ ] Verify the game remains playable with low storage and intermittent network conditions.

## Release blockers

Do not call the app store-ready until all legal placeholders are replaced, policies are hosted, platform exports are signed, store declarations match the binary, required rights are documented, and physical-device QA passes.
