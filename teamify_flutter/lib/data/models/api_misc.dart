import 'api_helpers.dart';

class ApiNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;

  const ApiNotification({
    required this.id,
    required this.title,
    this.body = '',
    this.isRead = false,
    this.createdAt = '',
  });

  factory ApiNotification.fromJson(Map<String, dynamic> json) {
    return ApiNotification(
      id: asString(json['id']),
      title: asString(json['title']),
      body: asString(json['body'] ?? json['message']),
      isRead: asBool(json['is_read'] ?? json['isRead']),
      createdAt: asString(json['created_at'] ?? json['createdAt']),
    );
  }
}

class ApiFile {
  final String id;
  final String name;
  final String size;
  final String type;
  final String uploadedBy;
  final String createdAt;

  const ApiFile({
    required this.id,
    required this.name,
    this.size = '',
    this.type = '',
    this.uploadedBy = '',
    this.createdAt = '',
  });

  factory ApiFile.fromJson(Map<String, dynamic> json) {
    return ApiFile(
      id: asString(json['id'] ?? json['file_id']),
      name: asString(json['filename'] ?? json['name']),
      size: asString(json['size'] ?? json['file_size']),
      type: asString(json['mime_type'] ?? json['type']),
      uploadedBy: asString(json['uploaded_by'] ?? json['user_id']),
      createdAt: asString(json['created_at'] ?? json['uploaded_at']),
    );
  }
}

class ApiCV {
  final String id;
  final String userId;
  final Map<String, dynamic> data;

  const ApiCV({
    required this.id,
    required this.userId,
    required this.data,
  });

  factory ApiCV.fromJson(Map<String, dynamic> json) {
    return ApiCV(
      id: asString(json['id'] ?? json['cv_id']),
      userId: asString(json['user_id']),
      data: json,
    );
  }
}
