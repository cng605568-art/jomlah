#!/usr/bin/env bash
# Installs the Android NDK version Flutter asks for, before the build starts.
#
# GitHub's build machines don't come with the exact NDK Flutter wants, so otherwise Gradle downloads
# it (about 1 GB) in the middle of the build, and one broken download fails the whole build. Here the
# download is tried up to 3 times. If it still fails, the app is built with the closest NDK that is
# already on the machine instead (the NDK is only used to shrink the app's native libraries).
#
# Never fails the job: the worst case is the old behaviour, where Gradle downloads the NDK itself.
set -u

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [ -z "$sdk" ] || [ ! -x "$sdkmanager" ]; then
  echo "::warning title=NDK not pre-installed::No Android sdkmanager found; Gradle will fetch the NDK during the build."
  exit 0
fi

# The version is written in Flutter's Gradle plugin and changes with Flutter releases.
ver="${NDK_VERSION:-}"
if [ -z "$ver" ] && [ -n "${FLUTTER_ROOT:-}" ]; then
  ver=$(grep -rhoE 'ndkVersion[^"]*"[0-9]+\.[0-9]+\.[0-9]+"' "$FLUTTER_ROOT/packages/flutter_tools/gradle/src/main" 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
fi
if [ -z "$ver" ]; then
  echo "::warning title=NDK not pre-installed::Could not read Flutter's NDK version; Gradle will fetch it during the build."
  exit 0
fi

if [ -f "$sdk/ndk/$ver/source.properties" ]; then
  echo "NDK $ver is already installed."
  exit 0
fi

yes | "$sdkmanager" --licenses > /dev/null 2>&1 || true
log="${RUNNER_TEMP:-/tmp}/ndk-install.log"
for try in 1 2 3; do
  echo "Installing NDK $ver (try $try of 3)..."
  if "$sdkmanager" --install "ndk;$ver" > "$log" 2>&1 && [ -f "$sdk/ndk/$ver/source.properties" ]; then
    echo "Installed NDK $ver."
    exit 0
  fi
  # sdkmanager draws progress bars with \r; keep the lines that say what went wrong.
  why=$(tr '\r' '\n' < "$log" | grep -iE 'error|warning|fail|exception' | tail -n 2 | tr '\n' ' ')
  [ -n "$why" ] || why=$(tr '\r' '\n' < "$log" | grep -vE '^\[|^[[:space:]]*$' | tail -n 2 | tr '\n' ' ')
  echo "::warning title=NDK download failed (try $try of 3)::$why"
  rm -rf "$sdk/ndk/$ver"
  sleep 20
done

# Still no luck: use the closest NDK the machine already has (the next newer one, else the newest).
have=$(ls "$sdk/ndk" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V)
pick=$(printf '%s\n%s\n' "$have" "$ver" | sort -V | grep -A1 -xF "$ver" | sed -n 2p)
[ -n "$pick" ] || pick=$(printf '%s\n' "$have" | tail -n 1)
gradle_file=android/app/build.gradle.kts
if [ -n "$pick" ] && [ -f "$gradle_file" ] && grep -q 'ndkVersion = flutter.ndkVersion' "$gradle_file"; then
  sed -i "s/ndkVersion = flutter.ndkVersion/ndkVersion = \"$pick\"/" "$gradle_file"
  echo "::warning title=Using NDK $pick instead::NDK $ver could not be downloaded, so the app is built with NDK $pick, which is already on this machine."
else
  echo "::warning title=NDK not pre-installed::NDK $ver could not be downloaded; Gradle will try again during the build."
fi
exit 0
