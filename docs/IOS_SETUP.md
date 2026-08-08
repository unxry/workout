# iOS Setup

This repository is now a standalone native iOS app. It does not require Timeweb, Docker, Telegram, a domain, or a server database.

## Requirements

- Xcode installed from the App Store or Apple Developer site
- iPhone connected by USB
- Personal Apple ID signed into Xcode
- Optional: XcodeGen if you want to generate the `.xcodeproj` from `project.yml`

## Generate The Xcode Project

If XcodeGen is installed:

```bash
brew install xcodegen
xcodegen generate
open "AI Fitness Coach.xcodeproj"
```

If XcodeGen is not installed:

1. Open Xcode.
2. Create a new iOS App project named `AI Fitness Coach`.
3. Use SwiftUI, Swift, and iOS 17+.
4. Add the files from the `AI Fitness Coach` folder into the project.
5. Enable HealthKit capability in Signing & Capabilities.
6. Set bundle id to `com.unxry.aifitnesscoach`.

## Run On iPhone

1. Connect iPhone by USB.
2. Select the iPhone as run destination.
3. In Signing & Capabilities, choose your Team.
4. Press Run.

If iPhone asks for trust, tap `Trust This Computer`. If Xcode asks for Apple ID / signing team / 2FA, complete that in Xcode only.

## AI API

OpenAI key is entered inside the app in `Profile -> AI API` and stored in Keychain.

For personal sideloaded use this is the simplest setup. For a public commercial app, the API key should not live on-device; it should be proxied by a backend.
