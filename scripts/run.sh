#!/bin/zsh

set -e

# Run the app on simulator or physical device without debugging
# Based on launch_and_debug.sh but without the debugger attachment

DEFAULT_DISK_CACHE="$HOME/telegram-bazel-cache"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Handle git worktree: symlink build-input from main worktree if missing
if [[ ! -d "$PROJECT_ROOT/build-input" ]]; then
    main_worktree=$(git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null | grep "^worktree " | head -1 | cut -d' ' -f2-)
    if [[ -n "$main_worktree" && "$main_worktree" != "$PROJECT_ROOT" && -d "$main_worktree/build-input" ]]; then
        echo "Git worktree detected. Symlinking build-input from main worktree..."
        ln -s "$main_worktree/build-input" "$PROJECT_ROOT/build-input"
    else
        echo "Error: build-input directory not found and could not locate main worktree"
        exit 1
    fi
fi

# Parse arguments
DISK_CACHE="$DEFAULT_DISK_CACHE"
SKIP_BUILD=false
USE_DEVICE=false
DEVICE_UDID=""
BUILD_CONFIG="dev"
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
        --device)
            USE_DEVICE=true
            shift
            ;;
        --device=*)
            USE_DEVICE=true
            DEVICE_UDID="${arg#*=}"
            shift
            ;;
        --config=*)
            BUILD_CONFIG="${arg#*=}"
            shift
            ;;
        --dev)
            BUILD_CONFIG="dev"
            shift
            ;;
        --dist)
            BUILD_CONFIG="dist"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --dev                Use development configuration (default)"
            echo "  --dist               Use distribution configuration"
            echo "  --config=<dev|dist>  Set build configuration"
            echo "  --disk-cache=<path>  Set custom disk cache path (default: ~/telegram-bazel-cache)"
            echo "  --no-disk-cache      Disable disk cache"
            echo "  --skip-build         Skip build, just install and launch"
            echo "  --device             Build and install on physical device (requires provisioning)"
            echo "  --device=<udid>      Build and install on specific physical device"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
    esac
done

# Function to find config file, checking local first, then main worktree
find_config_file() {
    local config_name="$1"
    local local_path="$PROJECT_ROOT/build-system/$config_name"

    # Check local first
    if [[ -f "$local_path" ]]; then
        echo "$local_path"
        return
    fi

    # Try to find in main worktree
    local main_worktree=$(git worktree list --porcelain 2>/dev/null | grep "^worktree " | head -1 | cut -d' ' -f2-)
    if [[ -n "$main_worktree" && "$main_worktree" != "$PROJECT_ROOT" ]]; then
        local main_path="$main_worktree/build-system/$config_name"
        if [[ -f "$main_path" ]]; then
            echo "$main_path"
            return
        fi
    fi

    # Not found
    echo ""
}

# Set configuration file based on build config
case "$BUILD_CONFIG" in
    dev|development)
        CONFIG_FILE=$(find_config_file "development-configuration.json")
        APS_ENVIRONMENT="development"
        echo "Using development configuration"
        ;;
    dist|distribution)
        CONFIG_FILE=$(find_config_file "frontrun-distribution-config.json")
        APS_ENVIRONMENT="production"
        echo "Using distribution configuration"
        ;;
    *)
        echo "Unknown config: $BUILD_CONFIG (use 'dev' or 'dist')"
        exit 1
        ;;
esac

# Verify config file was found
if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found for '$BUILD_CONFIG' config"
    echo "Looked in: $PROJECT_ROOT/build-system/"
    main_worktree=$(git worktree list --porcelain 2>/dev/null | grep "^worktree " | head -1 | cut -d' ' -f2-)
    if [[ -n "$main_worktree" && "$main_worktree" != "$PROJECT_ROOT" ]]; then
        echo "Also looked in: $main_worktree/build-system/"
    fi
    exit 1
fi

echo "Config file: $CONFIG_FILE"

# Update variables.bzl from JSON config
VARIABLES_FILE="$PROJECT_ROOT/build-input/configuration-repository/variables.bzl"
echo "Updating $VARIABLES_FILE from $CONFIG_FILE..."

BUNDLE_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['bundle_id'])")
API_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['api_id'])")
API_HASH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['api_hash'])")
TEAM_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['team_id'])")
APP_CENTER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['app_center_id'])")
IS_INTERNAL=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['is_internal_build'])")
IS_APPSTORE=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['is_appstore_build'])")
APPSTORE_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['appstore_id'])")
URL_SCHEME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['app_specific_url_scheme'])")
PREMIUM_IAP=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['premium_iap_product_id'])")
ENABLE_SIRI=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['enable_siri'])")
ENABLE_ICLOUD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['enable_icloud'])")

cat > "$VARIABLES_FILE" << EOF
telegram_bazel_path = "$PROJECT_ROOT/build-input/bazel-8.4.2-darwin-arm64"
telegram_use_xcode_managed_codesigning = False
telegram_bundle_id = "$BUNDLE_ID"
telegram_api_id = "$API_ID"
telegram_api_hash = "$API_HASH"
telegram_team_id = "$TEAM_ID"
telegram_app_center_id = "$APP_CENTER_ID"
telegram_is_internal_build = "$IS_INTERNAL"
telegram_is_appstore_build = "$IS_APPSTORE"
telegram_appstore_id = "$APPSTORE_ID"
telegram_app_specific_url_scheme = "$URL_SCHEME"
telegram_premium_iap_product_id = "$PREMIUM_IAP"
telegram_aps_environment = "$APS_ENVIRONMENT"
telegram_enable_siri = $ENABLE_SIRI
telegram_enable_icloud = $ENABLE_ICLOUD
telegram_enable_watch = True
EOF

echo "Bundle ID: $BUNDLE_ID"

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
    if [[ "$USE_DEVICE" == true ]]; then
        echo "Building for physical device..."
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
            --ios_multi_cpus=arm64 \
            --watchos_cpus=arm64_32 \
            --features=swift.enable_batch_mode
    else
        echo "Building for simulator..."
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
fi

# Extract the app
echo "Extracting..."
unzip -o bazel-bin/Telegram/Telegram.ipa -d /tmp/telegram-app-extract

# Get bundle ID from Info.plist
APP_PATH="/tmp/telegram-app-extract/Payload/Telegram.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")
echo "Bundle ID: $BUNDLE_ID"

if [[ "$USE_DEVICE" == true ]]; then
    # Physical device installation
    if [[ -z "$DEVICE_UDID" ]]; then
        # Find a connected device
        echo "Looking for connected devices..."
        DEVICE_UDID=$(xcrun devicectl list devices 2>/dev/null | grep "connected" | awk '{print $3}' | head -1 || echo "")

        if [[ -z "$DEVICE_UDID" ]]; then
            echo "Error: No physical device found. Please connect a device or specify --device=<udid>"
            echo ""
            echo "Available devices:"
            xcrun devicectl list devices 2>/dev/null || echo "  (none found)"
            exit 1
        fi
    fi

    echo "Using device: $DEVICE_UDID"

    # Install to physical device using devicectl
    echo "Installing to device..."
    xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

    # Launch the app on device
    echo "Launching on device..."
    xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID"

    echo "App launched on device successfully!"
else
    # Simulator installation
    # Get a booted simulator or boot one
    SIMULATOR_UDID=$(xcrun simctl list devices booted -j | python3 -c "import sys,json; devices=json.load(sys.stdin)['devices']; booted=[d['udid'] for v in devices.values() for d in v if d['state']=='Booted']; print(booted[0] if booted else '')" 2>/dev/null || echo "")

    if [[ -z "$SIMULATOR_UDID" ]]; then
        echo "No booted simulator found. Booting iPhone 17 Pro..."
        SIMULATOR_UDID=$(xcrun simctl list devices -j | python3 -c "import sys,json; devices=json.load(sys.stdin)['devices']; iphones=[d['udid'] for v in devices.values() for d in v if 'iPhone' in d['name'] and d['isAvailable']]; print(iphones[0] if iphones else '')")
        xcrun simctl boot "$SIMULATOR_UDID"
        sleep 3
    fi

    echo "Using simulator: $SIMULATOR_UDID"

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
fi
