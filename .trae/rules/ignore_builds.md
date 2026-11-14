# Build and Temporary File Handling
- Never read, modify, or clean up files inside `build/`, `ios/build/`, `DerivedData/`, `.dart_tool/`, or `.git/`.
- Never ask the user to verify, inspect, or restore deleted temporary files (`tmp_*`, `*.tmp`) or build artifacts from Trash.
- Do not run build, clean, or git write operations in the sandboxed terminal; hand these to Terminal.app.
- Notify the user only if a tracked source file, a `.git/` internal, or a secrets/config file (`pubspec.yaml`, `android/key.properties`, `supabase_config.json`, `appstore_config.json`, `.env*`) is deleted.
