import '../core/cache/cache_manager.dart';
import '../core/session/session_controller.dart';
import '../data/repositories/app_repositories.dart';
import 'auth_service.dart';
import 'project_service.dart';
import 'task_service.dart';
import 'ai_service.dart';

/// Central registry for all service layer instances.
///
/// Services depend on repositories (data layer) and infrastructure
/// (cache, session). This class wires them together.
class AppServices {
  late final AuthService auth;
  late final ProjectService projects;
  late final TaskService tasks;
  late final AIService ai;

  AppServices({
    required AppRepositories repos,
    required SessionController session,
    required CacheManager cache,
  }) {
    auth = AuthService(
      repo: repos.auth,
      session: session,
      cache: cache,
    );
    projects = ProjectService(
      repo: repos.projects,
      stats: repos.stats,
      cache: cache,
    );
    tasks = TaskService(
      repo: repos.tasks,
      comments: repos.comments,
      cache: cache,
    );
    ai = AIService(
      ai: repos.ai,
      cv: repos.cv,
    );
  }
}
