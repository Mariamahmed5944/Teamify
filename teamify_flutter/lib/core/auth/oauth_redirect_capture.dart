import '../cache/cache_manager.dart';

import 'oauth_redirect_capture_stub.dart'
    if (dart.library.html) 'oauth_redirect_capture_web.dart' as impl;

/// Persist OAuth callback params from the browser URL into local cache.
Future<void> stashOAuthRedirectIfPresent(CacheManager cache) =>
    impl.stashOAuthRedirectIfPresent(cache);
