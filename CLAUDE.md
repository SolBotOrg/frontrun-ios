# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository.

## Build
The app is built using Bazel.

### Build and Run on Simulator

1. Build for simulator:
```bash
bazel build Telegram/Telegram --features=swift.use_global_module_cache --verbose_failures --jobs=16 --define=buildNumber=10000 --define=telegramVersion=12.2.1 -c dbg --ios_multi_cpus=sim_arm64 --features=swift.enable_batch_mode --//Telegram:disableProvisioningProfiles
```

2. Install and launch on simulator (requires a booted simulator):
```bash
unzip -o bazel-bin/Telegram/Telegram.ipa -d bazel-bin/Telegram/Telegram_extracted && xcrun simctl install booted bazel-bin/Telegram/Telegram_extracted/Payload/Telegram.app && xcrun simctl launch booted org.6638093a9a369d0c.Telegram
```

## Code Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/methods
- **Frontrun Naming**: New Frontrun-specific files and folders should be prefixed with `Frontrun` (e.g., `FrontrunAISettingsController.swift`). Files inside a Frontrun-prefixed folder do not need the prefix.
- **Imports**: Group and sort imports at the top of files
- **Error Handling**: Properly handle errors with appropriate redaction of sensitive data
- **Formatting**: Use standard Swift/Objective-C formatting and spacing
- **Types**: Prefer strong typing and explicit type annotations where needed
- **Documentation**: Document public APIs with comments

## Project Structure
- Core launch and application extensions code is in `Telegram/` directory
- Most code is organized into libraries in `submodules/`
- External code is located in `third-party/`
- No tests are used at the moment

## Git Workflow
- This is a fork of Telegram-iOS. Always push to `SolBotOrg/frontrun-ios`, not the upstream repo.
- When creating PRs, use: `gh pr create --repo SolBotOrg/frontrun-ios`