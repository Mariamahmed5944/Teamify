import '../core/network/api_result.dart';
import '../core/network/request_deduplicator.dart';
import '../core/network/service_error_handler.dart';
import '../data/models/models.dart';
import '../data/repositories/search_repository.dart';

class SearchService with ServiceErrorHandler {
  final SearchRepository _repo;

  SearchService(this._repo);

  final RequestDeduplicator _dedup = RequestDeduplicator();

  Future<ApiResult<List<ApiUser>>> users(
    String query, {
    String? userType,
    int perPage = 100,
  }) =>
      _dedup.deduplicate(
        'search_users_${query}_${userType}_$perPage',
        () => guard(
          () => _repo.users(query, userType: userType, perPage: perPage),
        ),
      );

  Future<ApiResult<List<ApiProject>>> projects(String query) =>
      _dedup.deduplicate(
        'search_projects_$query',
        () => guard(() => _repo.projects(query)),
      );
}
