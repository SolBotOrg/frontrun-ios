#!/bin/zsh

set -e

# Run the app on simulator or physical device without debugging
# Based on launch_and_debug.sh but without the debugger attachment

DEFAULT_DISK_CACHE="$HOME/telegram-bazel-cache"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Detect if we're in a git worktree and find main repo
MAIN_REPO_ROOT=""
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ -n "$GIT_COMMON_DIR" && "$GIT_COMMON_DIR" != ".git" && "$GIT_COMMON_DIR" != "$PROJECT_ROOT/.git" ]]; then
    # We're in a worktree - main repo is parent of .git directory
    MAIN_REPO_ROOT=$(dirname "$GIT_COMMON_DIR")
    echo "Detected worktree, main repo: $MAIN_REPO_ROOT"

    # Initialize submodules if needed (check if any submodule dir is empty)
    SUBMODULE_EMPTY=false
    for submod_dir in build-system/bazel-rules/apple_support build-system/bazel-rules/rules_apple; do
        if [[ -d "$PROJECT_ROOT/$submod_dir" && -z "$(ls -A "$PROJECT_ROOT/$submod_dir" 2>/dev/null)" ]]; then
            SUBMODULE_EMPTY=true
            break
        fi
    done
    if [[ "$SUBMODULE_EMPTY" == true ]]; then
        echo "Initializing submodules for worktree..."
        git submodule update --init --recursive
    fi

    # Set up build-input directory structure if missing
    if [[ ! -d "$PROJECT_ROOT/build-input" ]]; then
        echo "Setting up build-input directory for worktree..."
        mkdir -p "$PROJECT_ROOT/build-input/configuration-repository/profiles"
        mkdir -p "$PROJECT_ROOT/build-input/configuration-repository/provisioning"

        # Symlink the bazel binary
        if [[ -f "$MAIN_REPO_ROOT/build-input/bazel-8.4.2-darwin-arm64" ]]; then
            ln -sf "$MAIN_REPO_ROOT/build-input/bazel-8.4.2-darwin-arm64" "$PROJECT_ROOT/build-input/bazel-8.4.2-darwin-arm64"
        fi

        # Copy bazel config files (BUILD, MODULE.bazel, WORKSPACE, etc.)
        for file in BUILD MODULE.bazel MODULE.bazel.lock WORKSPACE; do
            if [[ -f "$MAIN_REPO_ROOT/build-input/configuration-repository/$file" ]]; then
                cp "$MAIN_REPO_ROOT/build-input/configuration-repository/$file" "$PROJECT_ROOT/build-input/configuration-repository/$file"
            fi
        done

        # Copy provisioning profiles if they exist
        if [[ -d "$MAIN_REPO_ROOT/build-input/configuration-repository/profiles" ]]; then
            cp -r "$MAIN_REPO_ROOT/build-input/configuration-repository/profiles/"* "$PROJECT_ROOT/build-input/configuration-repository/profiles/" 2>/dev/null || true
        fi
    fi
fi

# Set configuration file based on build config
case "$BUILD_CONFIG" in
    dev|development)
        CONFIG_FILE="$PROJECT_ROOT/build-system/development-configuration.json"
        APS_ENVIRONMENT="development"
        echo "Using development configuration"
        ;;
    dist|distribution)
        CONFIG_FILE="$PROJECT_ROOT/build-system/frontrun-distribution-config.json"
        APS_ENVIRONMENT="production"
        echo "Using distribution configuration"
        ;;
    *)
        echo "Unknown config: $BUILD_CONFIG (use 'dev' or 'dist')"
        exit 1
        ;;
esac

# If config file doesn't exist and we're in a worktree, copy from main repo
if [[ ! -f "$CONFIG_FILE" && -n "$MAIN_REPO_ROOT" ]]; then
    MAIN_CONFIG_FILE="$MAIN_REPO_ROOT/build-system/$(basename "$CONFIG_FILE")"
    if [[ -f "$MAIN_CONFIG_FILE" ]]; then
        echo "Copying configuration from main repo..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cp "$MAIN_CONFIG_FILE" "$CONFIG_FILE"
    else
        echo "Error: Config file not found in main repo: $MAIN_CONFIG_FILE"
        exit 1
    fi
fi

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

# Copy provisioning profiles based on config
PROFILES_SRC="$PROJECT_ROOT/build-input/configuration-repository/profiles"
PROFILES_DST="$PROJECT_ROOT/build-input/configuration-repository/provisioning"

if [[ "$USE_DEVICE" == true ]]; then
    echo "Setting up provisioning profiles for $BUILD_CONFIG..."

    case "$BUILD_CONFIG" in
        dev|development)
            PROFILE_SUFFIX="_Development"
            ;;
        dist|distribution)
            PROFILE_SUFFIX=""
            ;;
    esac

    # Copy profiles with correct naming
    for target in Telegram Share Widget NotificationService NotificationContent Intents BroadcastUpload; do
        src_file="$PROFILES_SRC/${target}${PROFILE_SUFFIX}.mobileprovision"
        dst_file="$PROFILES_DST/${target}.mobileprovision"
        if [[ -f "$src_file" ]]; then
            cp "$src_file" "$dst_file"
            echo "  Copied ${target}${PROFILE_SUFFIX}.mobileprovision -> ${target}.mobileprovision"
        else
            echo "  Warning: $src_file not found"
        fi
    done
fi

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

    # Remove old bundle to ensure clean install (preserves user data in separate container)
    OLD_BUNDLE=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || echo "")
    if [[ -n "$OLD_BUNDLE" && -d "$OLD_BUNDLE" ]]; then
        echo "Removing old bundle..."
        rm -rf "$OLD_BUNDLE"
    fi

    # Install the app
    echo "Installing..."
    xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

    # Launch the app (without debugger)
    echo "Launching..."
    xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"

    echo "App launched successfully!"
fi
