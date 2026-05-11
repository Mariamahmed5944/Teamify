import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import 'admin_repository.dart';
import 'ai_repository.dart';
import 'auth_repository.dart';
import 'cv_repository.dart';
import 'file_repository.dart';
import 'notification_repository.dart';
import 'project_repository.dart';
import 'search_repository.dart';
import 'task_repository.dart';
import 'user_repository.dart';

class AppRepositories {
  final TokenStorage tokenStorage;
  final ApiClient apiClient;
  late final AuthRepository auth;
  late final UserRepository users;
  late final ProjectRepository projects;
  late final TaskRepository tasks;
  late final NotificationRepository notifications;
  late final SearchRepository search;
  late final AdminRepository admin;
  late final FileRepository files;
  late final CVRepository cv;
  late final AIRepository ai;

  AppRepositories._({
    required this.tokenStorage,
    required this.apiClient,
  }) {
    auth =
        AuthRepository(client: apiClient, tokenStorage: tokenStorage);
    users = UserRepository(apiClient);
    projects = ProjectRepository(apiClient);
    tasks = TaskRepository(apiClient);
    notifications = NotificationRepository(apiClient);
    search = SearchRepository(apiClient);
    admin = AdminRepository(apiClient);
    files = FileRepository(apiClient);
    cv = CVRepository(apiClient);
    ai = AIRepository(apiClient);
  }

  factory AppRepositories({
    TokenStorage? tokenStorage,
    ApiClient? apiClient,
  }) {
    final storage = tokenStorage ?? TokenStorage();
    return AppRepositories._(
      tokenStorage: storage,
      apiClient: apiClient ?? ApiClient(tokenStorage: storage),
    );
  }
}
