#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_PATH="$ROOT_DIR/supabase_config.json"
OUTPUT_PATH="$ROOT_DIR/ios/Flutter/Local.xcconfig"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing $CONFIG_PATH" >&2
  exit 1
fi

python3 - "$CONFIG_PATH" "$OUTPUT_PATH" <<'PY'
import base64
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

config = json.loads(config_path.read_text())

defines = [
    f"SUPABASE_URL={config['SUPABASE_URL']}",
    f"SUPABASE_ANON_KEY={config['SUPABASE_ANON_KEY']}",
]

encoded = ",".join(
    base64.b64encode(item.encode("utf-8")).decode("ascii") for item in defines
)

output_path.write_text(
    "// Generated from supabase_config.json. Do not commit.\n"
    f"DART_DEFINES={encoded}\n"
)
PY

echo "Wrote $OUTPUT_PATH"
