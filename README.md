# EncryptedIpaFetcher

SwiftUI iOS app scaffold inspired by [ipatool](https://github.com/majd/ipatool):
- Apple ID sign-in form
- App Store software search
- IPA download request queue/status UI

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
