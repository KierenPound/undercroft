import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/attachment.dart';

class EstatePhotoCacheManager extends CacheManager {
  static const _cacheKey = 'estatePhotoCache';
  static final EstatePhotoCacheManager _instance = EstatePhotoCacheManager._();

  factory EstatePhotoCacheManager() => _instance;

  EstatePhotoCacheManager._()
      : super(
          Config(
            _cacheKey,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 100,
          ),
        );
}

String estatePhotoCacheKey(Attachment attachment) {
  final identity = attachment.storagePath.isNotEmpty
      ? attachment.storagePath
      : attachment.id;
  return 'estate-photo:$identity';
}

Future<void> evictEstatePhotoFromCache(Attachment attachment) async {
  try {
    await CachedNetworkImage.evictFromCache(
      attachment.downloadUrl,
      cacheKey: estatePhotoCacheKey(attachment),
      cacheManager: EstatePhotoCacheManager(),
    );
  } catch (_) {
    // Cache eviction should not block replacing a photo.
  }
}

Future<void> clearEstatePhotoCache() async {
  try {
    await EstatePhotoCacheManager().emptyCache();
  } catch (_) {
    // Cache cleanup should never prevent sign-out.
  }
}
