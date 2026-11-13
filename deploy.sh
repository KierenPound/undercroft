#!/usr/bin/env zsh
#
# Build and install UnderCroft on a cable-connected device.
#
# Run this from Terminal.app rather than the IDE: signing the iOS build needs
# your login keychain, which the IDE's sandboxed agents cannot reach.
#
# Usage: ./deploy.sh [--beta]
#
#   --beta   include ENABLE_DEV_TOOLS=true, so the Developer tools section and
#            the "Beta build" marker appear. Omit it to sanity-check the build
#            exactly as an App Store release will behave.

set -euo pipefail

cd "$(dirname "$0")"

beta=0
for arg in "$@"; do
  case "$arg" in
    --beta) beta=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

# Keep Gradle's home on the internal disk. By default it lives at ~/.gradle,
# which here is a symlink onto the external SSD — and on that volume Gradle's
# atomic temp-file writes fail ("problems-report*.html: File exists"), killing
# every build before it starts. The internal copy holds the same cache, so
# nothing is re-downloaded. Override GRADLE_USER_HOME to point it elsewhere.
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle-internal}"

readonly CONFIG="supabase_config.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Cannot find $CONFIG — the Supabase credentials live there." >&2
  exit 1
fi

read_config() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' \
    "$CONFIG" "$1"
}

# The app reads these at compile time, so every build has to carry them or it
# starts up with no Supabase host.
defines=(
  "--dart-define=SUPABASE_URL=$(read_config SUPABASE_URL)"
  "--dart-define=SUPABASE_ANON_KEY=$(read_config SUPABASE_ANON_KEY)"
)

if (( beta )); then
  echo "Beta build — Developer tools will be visible in Settings."
  defines+=("--dart-define=ENABLE_DEV_TOOLS=true")
else
  echo "Release build — no Developer tools."
fi

echo "UnderCroft deploy"
echo "  1) iOS     (iPhone / iPad on the cable)"
echo "  2) Android (phone on the cable)"
printf "Choose 1 or 2: "
read -r choice

case "$choice" in
  1) platform="ios" ;;
  2) platform="android" ;;
  *)
    echo "Please choose 1 or 2." >&2
    exit 1
    ;;
esac

if [[ "$platform" == "ios" ]]; then
  # Find the cabled iPhone/iPad via devicectl, which reports the transport type
  # per device. `xctrace list devices` cannot be used for this: on recent Xcode
  # versions it files a cabled iPhone under "== Devices Offline ==", so the old
  # lookup matched nothing, pipefail failed the pipeline, and `set -e` killed
  # the script before it could print anything at all.
  #
  # `|| true` on both commands keeps that same silent death from happening
  # again if devicectl ever changes shape; the friendly message below runs
  # instead.
  devices_json="$(mktemp -t undercroft-devices)"
  xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1 || true
  udid="$(python3 -c '
import json, sys

try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []

for device in devices:
    hardware = device.get("hardwareProperties") or {}
    connection = device.get("connectionProperties") or {}
    if hardware.get("reality") != "physical":
        continue
    if hardware.get("deviceType") not in ("iPhone", "iPad"):
        continue
    if connection.get("transportType") != "wired":
        continue
    print(hardware.get("udid") or device.get("identifier", ""))
    break
' "$devices_json" || true)"
  rm -f "$devices_json"

  if [[ ! "$udid" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
    echo "No iPhone or iPad found on the cable." >&2
    echo "Check it is plugged in, unlocked, and that Developer Mode is on" >&2
    echo "(Settings > Privacy & Security > Developer Mode)." >&2
    echo "Note: a phone paired over Wi-Fi only will not be picked up here." >&2
    exit 1
  fi

  # The iOS build takes its dart-defines from ios/Flutter/Local.xcconfig, not
  # from the flutter command line: Release.xcconfig includes Generated.xcconfig
  # and then Local.xcconfig, so Local wins and Xcode exports its DART_DEFINES to
  # the Dart compile. A stale Local file left over from a previous release would
  # therefore silently strip the beta flag — regenerate it to match this run.
  if (( beta )); then
    zsh scripts/generate_ios_local_xcconfig.sh --dev-tools
  else
    zsh scripts/generate_ios_local_xcconfig.sh
  fi

  echo "Building for iOS..."
  flutter build ios --release "${defines[@]}"

  echo "Installing onto $udid..."
  xcrun devicectl device install app --device "$udid" \
    build/ios/iphoneos/Runner.app

  echo "Done. A free Apple ID install stops working after 7 days — just re-run this."
else
  # `|| true` for the same reason as the iOS branch: an adb hiccup should reach
  # the message below rather than killing the script silently.
  serial="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }' || true)"

  if [[ -z "$serial" ]]; then
    echo "No Android device found on the cable." >&2
    echo "Check it is plugged in and USB debugging is authorised." >&2
    echo "If it is connected but unseen: adb kill-server && adb start-server" >&2
    exit 1
  fi

  if [[ ! -f android/key.properties ]]; then
    echo "Android release signing is not configured." >&2
    echo "Follow android/RELEASE_SIGNING.md before deploying an Android release." >&2
    exit 1
  fi

  echo "Building for Android..."
  flutter build apk --release "${defines[@]}"

  echo "Installing onto $serial..."
  adb install -r build/app/outputs/flutter-apk/app-release.apk

  echo "Done."
fi
