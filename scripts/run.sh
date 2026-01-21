#!/bin/zsh

set -e

# Run the app on simulator without debugging
# Based on launch_and_debug.sh but without the debugger attachment

DEFAULT_DISK_CACHE="$HOME/telegram-bazel-cache"

# Parse arguments
DISK_CACHE="$DEFAULT_DISK_CACHE"
SKIP_BUILD=false
for arg in "$@"; do
    case $arg in
        --disk-cache=*)
            DISK_CACHE="${arg#*=}"
            shift
            ;;
        --no-disk-cache)
            DISK_CACHE=""
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --disk-cache=<path>  Set custom disk cache path (default: ~/telegram-bazel-cache)"
            echo "  --no-disk-cache      Disable disk cache"
            echo "  --skip-build         Skip build, just install and launch"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
    esac
done

# Build disk cache argument
DISK_CACHE_ARG=""
if [[ -n "$DISK_CACHE" ]]; then
    mkdir -p "$DISK_CACHE"
    DISK_CACHE_ARG="--disk_cache=$DISK_CACHE"
    echo "Using disk cache: $DISK_CACHE"
else
    echo "Disk cache disabled"
fi

# Build if not skipped
if [[ "$SKIP_BUILD" == false ]]; then
    echo "Building..."
    ./build-input/bazel-8.4.2-darwin-arm64 build Telegram/Telegram \
        --announce_rc \
        --features=swift.use_global_module_cache \
        --verbose_failures \
        --remote_cache_async \
        --jobs=16 \
        --define=buildNumber=10000 \
        --define=telegramVersion=12.2.1 \
        ${DISK_CACHE_ARG} \
        -c dbg \
        --ios_multi_cpus=sim_arm64 \
        --watchos_cpus=arm64_32 \
        --features=swift.enable_batch_mode \
        --//Telegram:disableProvisioningProfiles
fi

# Get a booted simulator or boot one
SIMULATOR_UDID=$(xcrun simctl list devices booted -j | python3 -c "import sys,json; devices=json.load(sys.stdin)['devices']; booted=[d['udid'] for v in devices.values() for d in v if d['state']=='Booted']; print(booted[0] if booted else '')" 2>/dev/null || echo "")

if [[ -z "$SIMULATOR_UDID" ]]; then
    echo "No booted simulator found. Booting iPhone 17 Pro..."
    SIMULATOR_UDID=$(xcrun simctl list devices -j | python3 -c "import sys,json; devices=json.load(sys.stdin)['devices']; iphones=[d['udid'] for v in devices.values() for d in v if 'iPhone' in d['name'] and d['isAvailable']]; print(iphones[0] if iphones else '')")
    xcrun simctl boot "$SIMULATOR_UDID"
    sleep 3
fi

echo "Using simulator: $SIMULATOR_UDID"

# Extract the app
echo "Extracting..."
unzip -o bazel-bin/Telegram/Telegram.ipa -d /tmp/telegram-app-extract

# Get bundle ID from Info.plist
APP_PATH="/tmp/telegram-app-extract/Payload/Telegram.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")
echo "Bundle ID: $BUNDLE_ID"

# Terminate any existing instance
echo "Terminating any existing instances..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true

# Install the app
echo "Installing..."
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

# Launch the app (without debugger)
echo "Launching..."
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"

echo "App launched successfully!"
