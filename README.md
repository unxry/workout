# AI Fitness Coach iOS

Standalone native iOS fitness coach app.

The app is designed for direct installation on a personal iPhone through Xcode. It does not require Timeweb, Docker, Telegram, a domain, webhook setup, or a server database.

## Architecture

```text
iPhone
├─ SwiftUI interface
├─ SwiftData local database
├─ local nutrition and progress calculations
├─ local coach memory
├─ HealthKit integration
├─ UserNotifications
├─ Keychain for AI API key
└─ direct AI API calls
```

## Current Features

- Premium dark SwiftUI dashboard inspired by the reference design
- Onboarding for profile, goal, sex, height, weight, training frequency, meals, allergies, and exclusions
- Local BMR, TDEE, calories, protein, fat, carbs, water, weekly pace, and goal-date calculation
- Local meal diary
- Smooth weight-trend chart with Swift Charts
- AI Coach chat with OpenAI API support and deterministic fallback mode
- Long-term local coach memory through SwiftData
- HealthKit service for steps, active energy, weight, height, sleep, and heart data permissions
- Daily notification check-in service
- Keychain storage for OpenAI API key

## Run

See [docs/IOS_SETUP.md](docs/IOS_SETUP.md).

Short version:

```bash
brew install xcodegen
xcodegen generate
open "AI Fitness Coach.xcodeproj"
```

Then choose your iPhone in Xcode, select your signing team, and press Run.

## Important

For a personal sideloaded app, storing the OpenAI key in Keychain is acceptable and simple. For a public/commercial release, use a backend proxy instead of putting an API key on-device.
