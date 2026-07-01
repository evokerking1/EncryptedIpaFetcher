# EncryptedIpaFetcher

SwiftUI iOS app scaffold inspired by [ipatool](https://github.com/majd/ipatool):
- Apple ID sign-in form with 2FA code support
- App Store software search
- Download initiator, queue/status, and history tabs (liquid-glass style UI)
- Live Activity showing active download progress
- IPATool-style API handling and downloading flow adapted from PancakeStore

## Credits

- `IPATool.swift` migration source: [jailbreakdotparty/PancakeStore - MuffinStoreJailed/Functions/IPATool.swift](https://github.com/jailbreakdotparty/PancakeStore/blob/main/MuffinStoreJailed/Functions/IPATool.swift)
- Thanks to the PancakeStore/MuffinStoreJailed creators and contributors for the implementation used as the basis for this app's API and download flow.

## Local development

```bash
brew install xcodegen
xcodegen generate
open EncryptedIpaFetcher.xcodeproj
```

## CI build

GitHub Actions workflow `.github/workflows/ios-build.yml`:
1. Generates the Xcode project from `project.yml`
2. Builds the app for iPhoneOS without code signing
3. Packages an unsigned `.ipa` artifact for sideload tooling

## Notes

- The private Apple authentication + purchase/download APIs used by `ipatool` are not publicly documented for direct third-party iOS clients.
- This repository provides the iOS UI and service architecture to integrate those flows where legally/technically permitted.
