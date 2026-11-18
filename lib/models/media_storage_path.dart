const _legacySupabaseStoragePrefix = 'estate-documents/';

bool isLegacySupabaseStoragePath(String? path) =>
    path?.startsWith(_legacySupabaseStoragePrefix) ?? false;

String normalizeMediaStoragePath(String? path) {
  if (path == null || isLegacySupabaseStoragePath(path)) return '';
  return path;
}
