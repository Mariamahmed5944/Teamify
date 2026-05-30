import '../cache/cache_manager.dart';

/// Non-web platforms: OAuth callbacks are handled by native SDKs.
Future<void> stashOAuthRedirectIfPresent(CacheManager cache) async {}
