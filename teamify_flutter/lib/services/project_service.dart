import '../../core/cache/cache_manager.dart';
import '../../core/network/api_result.dart';
import '../../core/network/service_error_handler.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/stats_repository.dart';

/// Service layer for project lifecycle management.
///
/// Provides:
/// - Cache-first reads for project lists
/// - Combined project + stats fetching
/// - Member management orchestration
class ProjectService with ServiceErrorHandler {
  final ProjectRepository _repo;
  final StatsRepository _stats;
  final CacheManager _cache;

  static const _box = 'projects';

  ProjectService({
    required ProjectRepository repo,
    required StatsRepository stats,
    required CacheManager cache,
  })  : _repo = repo,
        _stats = stats,
        _cache = cache;

  // ── Cached list ────────────────────────────────────────────────────────

  /// Lists projects with cache-first strategy.
  Future<ApiResult<List<ApiProject>>> listProjects({
    bool forceRefresh = false,
  }) =>
      guard(() async {
        // Try cache first
        if (!forceRefresh) {
          final cached = await _cache.getList(_box, 'all');
          if (cached != null) {
            return cached.map(ApiProject.fromJson).toList();
          }
        }

        // Fetch from API
        final projects = await _repo.listProjects();

        // Update cache
        await _cache.putList(
          _box,
          'all',
          projects.map((p) => p.toJson()).toList(),
        );

        return projects;
      });

  /// Gets a single project (no full-list fetch needed).
  Future<ApiResult<ApiProject>> getProject(String id) =>
      guardWithRetry(() => _repo.getProject(id));

  /// Creates a project and invalidates the cache.
  Future<ApiResult<ApiProject>> createProject(
      Map<String, dynamic> payload) =>
      guard(() async {
        final project = await _repo.createProject(payload);
        await _cache.invalidateBox(_box);
        return project;
      });

  // ── Lifecycle ─────────────────────────────────────────────────────────

  Future<ApiResult<ApiProject>> completeProject(String id) =>
      guard(() async {
        final project = await _repo.completeProject(id);
        await _cache.invalidateBox(_box);
        return project;
      });

  Future<ApiResult<ApiProject>> reopenProject(String id) =>
      guard(() async {
        final project = await _repo.reopenProject(id);
        await _cache.invalidateBox(_box);
        return project;
      });

  // ── Members ───────────────────────────────────────────────────────────

  Future<ApiResult<List<ApiUser>>> listMembers(String projectId) =>
      guard(() => _repo.listProjectMembers(projectId));

  Future<ApiResult<void>> addMember(String projectId, String userId) =>
      guard(() => _repo.addProjectMember(
            projectId: projectId,
            userId: userId,
          ));

  Future<ApiResult<void>> removeMember(String projectId, String userId) =>
      guard(() => _repo.removeProjectMember(
            projectId: projectId,
            userId: userId,
          ));

  // ── Combined data ─────────────────────────────────────────────────────

  /// Fetches project details + stats in parallel for a dashboard view.
  Future<ApiResult<ProjectWithStats>> getProjectWithStats(String id) =>
      guard(() async {
        final results = await Future.wait([
          _repo.getProject(id),
          _stats.getProjectStats(id),
        ]);
        return ProjectWithStats(
          project: results[0] as ApiProject,
          stats: results[1] as Map<String, dynamic>,
        );
      });
}

/// Combined project + stats payload.
class ProjectWithStats {
  final ApiProject project;
  final Map<String, dynamic> stats;

  const ProjectWithStats({required this.project, required this.stats});
}
