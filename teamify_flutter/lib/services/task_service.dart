import '../../core/cache/cache_manager.dart';
import '../../core/network/api_result.dart';
import '../../core/network/service_error_handler.dart';
import '../../data/models/models.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../../core/network/request_deduplicator.dart';
import '../../core/cache/swr_helper.dart';

/// Service layer for task management.
///
/// Provides:
/// - Cache-first task lists per project
/// - Status transition logic
/// - Task + comments combined fetching
class TaskService with ServiceErrorHandler {
  final TaskRepository _repo;
  final CommentRepository _comments;
  final CacheManager _cache;

  static const _box = 'tasks';

  TaskService({
    required TaskRepository repo,
    required CommentRepository comments,
    required CacheManager cache,
  })  : _repo = repo,
        _comments = comments,
        _cache = cache {
      _swr = SwrHelper(_cache);
    }

  final RequestDeduplicator _dedup = RequestDeduplicator();
  late final SwrHelper _swr;

  // ── Cached list ────────────────────────────────────────────────────────

  Future<ApiResult<List<ApiTask>>> listTasks({
    required String projectId,
    bool forceRefresh = false,
    void Function(List<ApiTask>)? onRefreshed,
  }) =>
      _dedup.deduplicate('list_tasks_$projectId', () => guard(() async {
            if (forceRefresh) {
              final tasks = await _repo.listTasks(projectId: projectId);
              await _cache.putList(_box, 'project_$projectId', tasks.map((t) => t.toJson()).toList());
              return tasks;
            }

            return _swr.withSwrList<ApiTask>(
              boxName: _box,
              key: 'project_$projectId',
              fetcher: () => _repo.listTasks(projectId: projectId),
              fromJson: ApiTask.fromJson,
              toJson: (t) => t.toJson(),
              onRefreshed: onRefreshed,
            ).then((res) => res.isSuccess ? res.data! : throw Exception(res.error));
          }));

  Future<ApiResult<ApiTask>> getTask(String id) =>
      _dedup.deduplicate('get_task_$id', () => guardWithRetry(() => _repo.getTask(id)));

  // ── CRUD ──────────────────────────────────────────────────────────────

  Future<ApiResult<ApiTask>> createTask(Map<String, dynamic> payload) =>
      guard(() async {
        final task = await _repo.createTask(payload);
        await _cache.invalidateBox(_box);
        return task;
      });

  Future<ApiResult<ApiTask>> updateTask(
    String id,
    Map<String, dynamic> payload,
  ) =>
      guard(() async {
        final task = await _repo.updateTask(id, payload);
        await _cache.invalidateBox(_box);
        return task;
      });

  Future<ApiResult<ApiTask>> updateStatus(String id, String status) =>
      guard(() async {
        final task = await _repo.updateTaskStatus(id, status);
        await _cache.invalidateBox(_box);
        return task;
      });

  Future<ApiResult<void>> deleteTask(String id) =>
      guard(() async {
        await _repo.deleteTask(id);
        await _cache.invalidateBox(_box);
      });

  // ── Comments ──────────────────────────────────────────────────────────

  Future<ApiResult<List<Map<String, dynamic>>>> getComments(
          String taskId) =>
      guard(() => _comments.getTaskComments(taskId));

  Future<ApiResult<void>> addComment(String taskId, String content) =>
      guard(() => _comments.addComment(taskId, content));

  // ── Combined ──────────────────────────────────────────────────────────

  /// Fetches a task and its comments in parallel.
  Future<ApiResult<TaskWithComments>> getTaskWithComments(String id) =>
      guard(() async {
        final results = await Future.wait([
          _repo.getTask(id),
          _comments.getTaskComments(id),
        ]);
        return TaskWithComments(
          task: results[0] as ApiTask,
          comments: results[1] as List<Map<String, dynamic>>,
        );
      });
}

class TaskWithComments {
  final ApiTask task;
  final List<Map<String, dynamic>> comments;

  const TaskWithComments({required this.task, required this.comments});
}
