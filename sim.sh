#!/bin/bash
# Fast CLI companion for launching iOS and Android simulators
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect JAVA_HOME
if [ -z "$JAVA_HOME" ]; then
  if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
  elif [ -d "/opt/homebrew/opt/openjdk@21" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
  elif [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
fi

# Auto-detect ANDROID_HOME
if [ -z "$ANDROID_HOME" ]; then
  if [ -d "/opt/homebrew/share/android-commandlinetools" ]; then
    export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
  elif [ -d "$HOME/Library/Android/sdk" ]; then
    export ANDROID_HOME="$HOME/Library/Android/sdk"
  fi
fi

export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

case "$1" in
  ios)
    echo "🍏 Starting iOS Simulator..."
    DEVICE_ID=$(xcrun simctl list devices available | grep -E "iPhone" | head -n 1 | grep -o -E "\([A-F0-9-]+\)" | tr -d "()")
    if [ -n "$DEVICE_ID" ]; then
      xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
      open -a Simulator
      echo "✅ iOS Simulator launched!"
    else
      echo "⚠️ No iOS simulator found. Creating iPhone 17 Pro..."
      xcrun simctl create "iPhone 17 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
      open -a Simulator
    fi
    ;;

  android)
    echo "🤖 Starting Android Emulator..."
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    AVD_NAME=$(avdmanager list avd -c 2>/dev/null | grep -E "Pixel_9_Pro_API_37" | head -n 1)
    if [ -z "$AVD_NAME" ]; then
      AVD_NAME=$(avdmanager list avd -c 2>/dev/null | head -n 1)
    fi
    if [ -z "$AVD_NAME" ]; then
      echo "⚠️ No Android AVD found. Setting up Pixel 9 Pro (API 37)..."
      SYS_IMG="system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a"
      if ! sdkmanager --list_installed | grep -q "$SYS_IMG"; then
        echo "==> Downloading system image..."
        echo "y" | sdkmanager --install "$SYS_IMG"
      fi
      echo "no" | avdmanager create avd -n "Pixel_9_Pro_API_37" -k "$SYS_IMG" -d "pixel_9_pro" --force
      AVD_NAME="Pixel_9_Pro_API_37"
    fi
    echo "==> Launching emulator for $AVD_NAME..."
    nohup "$ANDROID_HOME/emulator/emulator" -avd "$AVD_NAME" >/tmp/emulator.log 2>&1 &
    echo "✅ Android Emulator launched in background! (Log: /tmp/emulator.log)"
    ;;

  setup)
    echo "🚀 Auto-setting up latest iOS & Android Simulators..."
    # 1. iOS
    IOS_COUNT=$(xcrun simctl list devices available | grep -c "iPhone" || true)
    if [ "$IOS_COUNT" -eq 0 ]; then
      echo "==> Creating iPhone 17 Pro..."
      xcrun simctl create "iPhone 17 Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
    else
      echo "✅ iOS Simulator ready!"
    fi

    # 2. Android
    AVD_COUNT=$(avdmanager list avd -c 2>/dev/null | wc -l | tr -d ' ')
    if [ "$AVD_COUNT" -eq 0 ]; then
      SYS_IMG="system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a"
      echo "==> Creating Android AVD Pixel 9 Pro..."
      echo "no" | avdmanager create avd -n "Pixel_9_Pro_API_37" -k "$SYS_IMG" -d "pixel_9_pro" --force
    fi
    echo "✅ Android AVD ready!"
    ;;

  list)
    echo "🍏 iOS Simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" || echo "None"
    echo ""
    echo "🤖 Android Emulators:"
    avdmanager list avd 2>/dev/null | grep -E "Name:|Based on:" || echo "None"
    ;;

  delete-android)
    if [ -n "$2" ]; then
      echo "🗑️ Deleting Android AVD: $2"
      avdmanager delete avd -n "$2"
      echo "✅ Đã xoá AVD $2!"
    else
      echo "⚠️ Vui lòng cung cấp tên AVD cần xoá. Ví dụ: ./sim.sh delete-android Pixel_9_Pro_API_37"
    fi
    ;;

  delete-ios)
    if [ -n "$2" ]; then
      echo "🗑️ Deleting iOS Simulator: $2"
      xcrun simctl delete "$2"
      echo "✅ Đã xoá iOS Simulator $2!"
    else
      echo "⚠️ Vui lòng cung cấp UDID hoặc tên thiết bị cần xoá. Ví dụ: ./sim.sh delete-ios <UDID>"
    fi
    ;;

  download-image)
    IMG_TARGET="${2:-system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a}"
    echo "📥 Downloading Android System Image: $IMG_TARGET"
    echo "y" | sdkmanager --install "$IMG_TARGET"
    echo "✅ Hoàn tất tải gói $IMG_TARGET!"
    ;;

  app)
    echo "🖥️ Opening DeviceLauncher.app..."
    if [ ! -d "$DIR/build/DeviceLauncher.app" ]; then
      echo "Building app first..."
      "$DIR/build.sh"
    fi
    open "$DIR/build/DeviceLauncher.app"
    ;;

  *)
    echo "Device Launcher CLI"
    echo "Usage: ./sim.sh [command] [args]"
    echo "  ios                         - Bật iOS Simulator"
    echo "  android                     - Bật Android Emulator"
    echo "  setup                       - Tự động setup bản mới nhất cho cả iOS & Android nếu chưa có"
    echo "  list                        - Liệt kê các simulator/emulator hiện có"
    echo "  delete-ios <UDID>           - Xoá thiết bị iOS Simulator không cần thiết"
    echo "  delete-android <AVD_NAME>   - Xoá máy ảo Android AVD không cần thiết"
    echo "  download-image [PACKAGE]    - Tải thêm System Image Android về máy"
    echo "  app                         - Mở ứng dụng GUI DeviceLauncher.app"
    ;;
esac
