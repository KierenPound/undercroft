#!/usr/bin/env zsh
#
# Write ios/Flutter/Local.xcconfig from supabase_config.json.
#
# Usage: ./scripts/generate_ios_local_xcconfig.sh [--dev-tools]
#
#   --dev-tools   also pass ENABLE_DEV_TOOLS=true, which turns on the
#                 Developer tools section in Settings and the "Beta build"
#                 marker beside the version number. Beta builds pass this;
#                 anything heading for the App Store must not.
#
# The archive takes its dart-defines from this file rather than from the
# flutter command line: Release.xcconfig includes Generated.xcconfig and then
# this one, so whatever is written here wins.

set -euo pipefail

dev_tools=0
for arg in "$@"; do
  case "$arg" in
    --dev-tools) dev_tools=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_PATH="$ROOT_DIR/supabase_config.json"
OUTPUT_PATH="$ROOT_DIR/ios/Flutter/Local.xcconfig"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing $CONFIG_PATH" >&2
  exit 1
fi

UNDERCROFT_DEV_TOOLS="$dev_tools" python3 - "$CONFIG_PATH" "$OUTPUT_PATH" <<'PY'
import base64
import json
import os
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

config = json.loads(config_path.read_text())

defines = [
    f"SUPABASE_URL={config['SUPABASE_URL']}",
    f"SUPABASE_ANON_KEY={config['SUPABASE_ANON_KEY']}",
]

if os.environ.get("UNDERCROFT_DEV_TOOLS") == "1":
    defines.append("ENABLE_DEV_TOOLS=true")

encoded = ",".join(
    base64.b64encode(item.encode("utf-8")).decode("ascii") for item in defines
)

dev_tools_marker = "1" if os.environ.get("UNDERCROFT_DEV_TOOLS") == "1" else "0"
output_path.write_text(
    "// Generated from supabase_config.json. Do not commit.\n"
    f"// DEV_TOOLS={dev_tools_marker}\n"
    f"DART_DEFINES={encoded}\n"
)
PY

echo "  Wrote $OUTPUT_PATH"
if (( dev_tools )); then
  echo "  Including ENABLE_DEV_TOOLS=true (Developer tools will be visible)."
else
  echo "  Developer tools not enabled."
fi
