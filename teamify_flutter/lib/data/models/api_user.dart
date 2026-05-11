import '../../models/models.dart';
import 'api_helpers.dart';

class ApiUser {
  final String id;
  final String displayName;
  final String fullName;
  final String email;
  final String role;
  final String userType;
  final String accountStatus;
  final List<String> skills;

  const ApiUser({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.email,
    required this.role,
    required this.userType,
    required this.accountStatus,
    this.skills = const [],
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isStudent => userType.toLowerCase() == 'student';
  bool get isFreelancer => userType.toLowerCase() == 'freelancer';
  bool get isPending => accountStatus.toLowerCase() == 'pending';

  String get displayRole {
    if (isAdmin) return 'Admin';
    if (isStudent) return 'Student';
    return 'Freelancer';
  }

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    final display = asString(
      json['display_name'] ?? json['displayName'] ?? json['name'],
      'User',
    );
    return ApiUser(
      id: asString(json['id']),
      displayName: display,
      fullName: asString(json['full_name'] ?? json['fullName'], display),
      email: asString(json['email']),
      role: asString(json['role'], 'member'),
      userType: asString(json['user_type'] ?? json['userType'], 'freelancer'),
      accountStatus: asString(
        json['account_status'] ?? json['accountStatus'],
        'approved',
      ),
      skills: asStringList(json['skills']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'full_name': fullName,
        'email': email,
        'role': role,
        'user_type': userType,
        'account_status': accountStatus,
        'skills': skills,
      };

  UserModel toDisplayModel() {
    return UserModel(
      id: id,
      name: fullName.isNotEmpty ? fullName : displayName,
      email: email,
      role: displayRole,
      skills: skills,
    );
  }
}
