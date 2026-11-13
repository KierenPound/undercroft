#!/usr/bin/env zsh
#
# UnderCroft — archive the iOS app and send it to App Store Connect.
#
# This is the scripted form of the Xcode round trip:
#
#   1. bump the build number in pubspec.yaml
#   2. regenerate ios/Flutter/Local.xcconfig (the Supabase defines)
#   3. flutter pub get + flutter build ios --config-only
#   4. xcodebuild clean                 (Product > Clean Build Folder)
#   5. xcodebuild archive               (Product > Archive)
#   6. xcodebuild -exportArchive        (Distribute App > App Store Connect)
#   7. xcrun altool --upload-app        (the Upload button)
#
# Run this from Terminal.app rather than the IDE: signing an App Store archive
# needs your login keychain, which the IDE's sandboxed agents cannot reach.
#
# The upload needs an App Store Connect API key, created at
# App Store Connect > Users and Access > Integrations > App Store Connect API.
# Put the .p8 in ~/.appstoreconnect/private_keys/ (where altool looks for it)
# and supply the two identifiers either as environment variables
#
#   ASC_KEY_ID=ABC123DEFG ASC_ISSUER_ID=1234abcd-5678-... ./newappios.sh
#
# or in a gitignored appstore_config.json next to supabase_config.json:
#
#   { "ASC_KEY_ID": "ABC123DEFG",
#     "ASC_ISSUER_ID": "1234abcd-5678-..." }
#
# Usage: ./newappios.sh [--no-upload]

set -euo pipefail

cd "$(dirname "$0")"

readonly TEAM_ID="WB7569A54X"
readonly SCHEME="Runner"
readonly WORKSPACE="ios/Runner.xcworkspace"
readonly ARCHIVE_PATH="build/ios/Runner.xcarchive"
readonly EXPORT_DIR="build/ios/ipa"
readonly EXPORT_OPTIONS="build/ios/ExportOptions.plist"
readonly SUPABASE_CONFIG="supabase_config.json"
readonly APPSTORE_CONFIG="appstore_config.json"

usage() {
  cat <<'EOF'
Usage: ./newappios.sh [--no-upload]

  Bumps the pubspec build number, regenerates the Supabase xcconfig, cleans,
  archives the Runner scheme, exports the .ipa and uploads it to App Store
  Connect.

  --no-upload   stop once the .ipa exists; skip the App Store Connect push
EOF
}

skip_upload=0
for arg in "$@"; do
  case "$arg" in
    --no-upload) skip_upload=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$SUPABASE_CONFIG" ]]; then
  echo "Cannot find $SUPABASE_CONFIG — the Supabase credentials live there." >&2
  exit 1
fi

# --- 1. Build number ------------------------------------------------------
# App Store Connect rejects an upload whose build number it has already seen,
# so every release has to move it on. The iOS target reads FLUTTER_BUILD_NUMBER,
# which Flutter derives from the "+n" suffix here — updating pubspec is enough.
echo "Bumping the build number..."
python3 - <<'PY'
import pathlib
import re

path = pathlib.Path("pubspec.yaml")
text = path.read_text()

match = re.search(r"^version:[ \t]*(\d+\.\d+\.\d+\+)(\d+)[ \t]*$", text, re.MULTILINE)
if match is None:
    raise SystemExit("pubspec.yaml has no 'version: x.y.z+n' line to bump")

old = f"{match.group(1)}{match.group(2)}"
new = f"{match.group(1)}{int(match.group(2)) + 1}"

path.write_text(text[: match.start()] + f"version: {new}" + text[match.end() :])
print(f"  pubspec version: {old} -> {new}")
PY

# --- 2. Supabase defines --------------------------------------------------
# The app reads these at compile time, so the release build has to carry them
# or it starts up with no Supabase host. Release.xcconfig #includes the output.
echo "Generating ios/Flutter/Local.xcconfig..."
zsh scripts/generate_ios_local_xcconfig.sh

# --- 3. Pub / generated files --------------------------------------------
# xcodebuild needs Generated.xcconfig and ios/Flutter/ephemeral, which the
# Flutter tool writes. `pub get` alone is NOT enough: it leaves the generated
# xcconfig alone, so the iOS target keeps reading the previous build number and
# the archive ships stamped with the wrong one (App Store Connect then rejects
# it as a duplicate). `--config-only` rewrites those files from the pubspec we
# just bumped, without doing a full build.
echo "Resolving packages..."
flutter pub get

echo "Regenerating the Flutter iOS config..."
flutter build ios --release --config-only

# --- 3b. Verify the build number actually moved --------------------------
# Cheaper to fail here than to find out from App Store Connect.
generated_version="$(sed -n 's/^FLUTTER_BUILD_NUMBER=//p' ios/Flutter/Generated.xcconfig)"
pubspec_version="$(sed -n 's/^version: *//p' pubspec.yaml | head -n 1)"
echo "  pubspec:   $pubspec_version"
echo "  archive:   ${generated_version:-<missing>}"
if [[ "${pubspec_version##*+}" != "$generated_version" ]]; then
  echo "Generated.xcconfig did not pick up the new build number." >&2
  echo "The archive would be stamped with a stale version." >&2
  exit 1
fi

# --- 4. Clean -------------------------------------------------------------
echo "Cleaning..."
xcodebuild clean \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release

# --- 5. Archive -----------------------------------------------------------
# -allowProvisioningUpdates lets xcodebuild create or fetch the Apple
# Distribution certificate and the App Store profile itself, which is what the
# Xcode "Automatically manage signing" checkbox does when you archive by hand.
echo "Archiving..."
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

# --- 6. Export ------------------------------------------------------------
# Written to build/ rather than committed: it is generated per release and the
# team ID lives in the script. manageAppVersionAndBuildNumber stays false so
# the build number we just bumped is the one that ships.
echo "Exporting the .ipa..."
mkdir -p "$(dirname "$EXPORT_OPTIONS")"
cat <<PLIST > "$EXPORT_OPTIONS"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

ipa="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit)"
if [[ -z "$ipa" ]]; then
  echo "The export produced no .ipa in $EXPORT_DIR." >&2
  exit 1
fi

# --- 7. Upload ------------------------------------------------------------
if (( skip_upload )); then
  echo
  echo "Skipping the upload (--no-upload)."
  echo "  Archive: $ARCHIVE_PATH"
  echo "  IPA:     $ipa"
else
  api_key_id="${ASC_KEY_ID:-}"
  api_issuer_id="${ASC_ISSUER_ID:-}"

  if [[ -f "$APPSTORE_CONFIG" ]]; then
    read_config() {
      python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' \
        "$APPSTORE_CONFIG" "$1"
    }
    [[ -z "$api_key_id" ]] && api_key_id="$(read_config ASC_KEY_ID)"
    [[ -z "$api_issuer_id" ]] && api_issuer_id="$(read_config ASC_ISSUER_ID)"
  fi

  if [[ -z "$api_key_id" || -z "$api_issuer_id" ]]; then
    echo "No App Store Connect API key configured." >&2
    echo "Export ASC_KEY_ID and ASC_ISSUER_ID, or add them to $APPSTORE_CONFIG." >&2
    exit 1
  fi

  key_file="$HOME/.appstoreconnect/private_keys/AuthKey_${api_key_id}.p8"
  if [[ ! -f "$key_file" ]]; then
    echo "Cannot find the API key at $key_file." >&2
    echo "Download it from App Store Connect and put it there." >&2
    exit 1
  fi

  echo "Uploading to App Store Connect..."
  xcrun altool --upload-app \
    --type ios \
    --file "$ipa" \
    --apiKey "$api_key_id" \
    --apiIssuer "$api_issuer_id"
fi

echo
echo "Done."
echo "  Archive: $ARCHIVE_PATH"
echo "  IPA:     $ipa"
echo
echo "The build number bump is still uncommitted — commit pubspec.yaml before"
echo "the next release so the version history stays in step with the store."
