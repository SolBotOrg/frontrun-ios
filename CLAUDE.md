# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository.

## Build
The app is built using Bazel. Use `scripts/run.sh` to build, install, and launch.

### Build and Run on Simulator
```bash
./scripts/run.sh
```

### Build and Run on Physical Device
```bash
./scripts/run.sh --device
```

### Options
- `--dev` - Use development configuration (default)
- `--dist` - Use distribution configuration
- `--skip-build` - Skip build, just install and launch
- `--device` - Build and install on physical device
- `--device=<udid>` - Build and install on specific device

## Code Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/methods
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