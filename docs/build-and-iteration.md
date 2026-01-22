# Build and Iteration Guide

Quick reference for building and iterating efficiently on this project.

## Quick Start

```bash
# Build and run on simulator
./scripts/run.sh

# Run with debugger attached
./scripts/launch_and_debug.sh

# Skip build, just reinstall (useful after closing simulator)
./scripts/run.sh --skip-build

# Build and run on physical device
./scripts/run.sh --device
```

## How Caching Works

Bazel uses two layers of caching:

| Location                 | Purpose                                          |
| ------------------------ | ------------------------------------------------ |
| `~/telegram-bazel-cache` | Persistent cache shared across branches/sessions |
| `./bazel-bin/`           | Current build output (symlink)                   |

When you change a file, Bazel:
1. Hashes the file + compiler flags + dependencies
2. Checks if that hash exists in disk cache
3. On cache hit: copies cached result (fast)
4. On cache miss: compiles and stores result

This means switching branches is fast—artifacts compiled before are reused.

## Iteration Workflow

```bash
# Make code changes, then:
./scripts/run.sh

# Bazel only recompiles what changed
# First build: slow (compiles everything)
# Subsequent builds: fast (incremental)
```

All code changes (including UI) require recompilation. There's no hot-reload.

## Building Specific Modules

When working on a single module, build just that target for faster feedback:

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TelegramUI:TelegramUI
```

This is faster than building the full app.

## Debugging Build Issues

### See why something is rebuilding

```bash
./build-input/bazel-8.4.2-darwin-arm64 build Telegram/Telegram \
  --explain=/tmp/explain.log \
  --verbose_explanations
cat /tmp/explain.log
```

### Profile slow Swift compilation

```bash
./build-input/bazel-8.4.2-darwin-arm64 build Telegram/Telegram --config=swift_profile
```

Runs single-threaded and warns about expressions taking >350ms to type-check.

### View build graph

```bash
./build-input/bazel-8.4.2-darwin-arm64 query 'deps(//Telegram:Telegram)' --output=graph | dot -Tpng > deps.png
```

## Clearing Caches

```bash
# Clear current build output
./build-input/bazel-8.4.2-darwin-arm64 clean

# Nuclear option: clear everything (forces full rebuild)
./build-input/bazel-8.4.2-darwin-arm64 clean
rm -rf ~/telegram-bazel-cache
```

Only clear the disk cache if you suspect corruption. Normal development never needs this.

## Script Options

### run.sh

| Flag | Effect |
|------|--------|
| `--skip-build` | Skip compilation, just install and launch |
| `--device` | Build for and deploy to connected device |
| `--device=<UDID>` | Deploy to specific device |
| `--disk-cache=<path>` | Use custom cache location |
| `--no-disk-cache` | Disable disk cache |

### launch_and_debug.sh

Same cache options as `run.sh`, but attaches LLDB debugger on port 6667.

## Troubleshooting

**Build fails with cryptic error**
```bash
./build-input/bazel-8.4.2-darwin-arm64 clean
./scripts/run.sh
```

**Simulator won't launch / blank screen**
```bash
xcrun simctl shutdown all
xcrun simctl erase all  # Warning: erases simulator data
./scripts/run.sh
```

**"No provisioning profile" on device builds**
Device builds require valid provisioning profiles. Simulator builds use `--//Telegram:disableProvisioningProfiles` to skip this.

**Build is slow after pulling changes**
Expected—new/changed files need compilation. The disk cache helps but can't cache what hasn't been built yet.
