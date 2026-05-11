import '../../models/models.dart';
import 'api_helpers.dart';
import 'api_task.dart';

class ApiProject {
  final String id;
  final String name;
  final String description;
  final String status;
  final int progress;
  final String ownerId;
  final String category;
  final List<ApiTask> tasks;
  final List<String> members;

  const ApiProject({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'active',
    this.progress = 0,
    this.ownerId = '',
    this.category = '',
    this.tasks = const [],
    this.members = const [],
  });

  factory ApiProject.fromJson(Map<String, dynamic> json) {
    return ApiProject(
      id: asString(json['id']),
      name: asString(json['name'] ?? json['title'], 'Untitled Project'),
      description: asString(json['description']),
      status: asString(json['status'], 'active'),
      progress: asInt(json['progress']),
      ownerId: asString(json['user_id'] ?? json['owner_id']),
      category: asString(json['category']),
      tasks: asMapList(json['tasks']).map(ApiTask.fromJson).toList(),
      members: asStringList(json['members']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'status': status,
        'progress': progress,
        'user_id': ownerId,
        'category': category,
      };

  ProjectModel toDisplayModel() {
    return ProjectModel(
      id: id,
      name: name,
      company: category.isNotEmpty ? category : 'Teamify',
      description: description,
      status: status,
      delayRisk: 'Unknown',
      progress: progress,
      tasks: tasks.map((task) => task.toDisplayModel()).toList(),
      members: members,
    );
  }
}
