import '../../models/models.dart';
import 'api_helpers.dart';

class ApiTask {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String projectId;
  final String assignedTo;
  final String dueDate;
  final String aiDelayRisk;

  const ApiTask({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.priority = 'medium',
    this.projectId = '',
    this.assignedTo = '',
    this.dueDate = '',
    this.aiDelayRisk = '',
  });

  factory ApiTask.fromJson(Map<String, dynamic> json) {
    return ApiTask(
      id: asString(json['id']),
      title: asString(json['title'], 'Untitled Task'),
      description: asString(json['description']),
      status: asString(json['status'], 'pending'),
      priority: asString(json['priority'], 'medium'),
      projectId: asString(json['project_id'] ?? json['projectId']),
      assignedTo: asString(json['assigned_to'] ?? json['assignedTo']),
      dueDate: asString(json['due_date'] ?? json['dueDate']),
      aiDelayRisk: asString(json['ai_delay_risk'] ?? json['delay_risk']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'project_id': projectId,
        'assigned_to': assignedTo.isEmpty ? null : assignedTo,
        'due_date': dueDate.isEmpty ? null : dueDate,
      };

  TaskModel toDisplayModel() {
    return TaskModel(
      id: id,
      title: title,
      assignee: assignedTo.isNotEmpty ? assignedTo : 'Unassigned',
      assigneeInitials:
          assignedTo.isNotEmpty ? assignedTo.substring(0, 1) : '?',
      status: status,
      priority: priority,
      dueDate: dueDate,
    );
  }
}
