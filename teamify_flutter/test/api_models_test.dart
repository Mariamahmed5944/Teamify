import 'package:flutter_test/flutter_test.dart';
import 'package:teamify/data/models/models.dart';

void main() {
  test('ApiUser parses numeric ids and snake_case fields', () {
    final user = ApiUser.fromJson({
      'id': 42,
      'display_name': 'matti',
      'full_name': 'Matti Weber',
      'email': 'matti@example.com',
      'role': 'member',
      'user_type': 'freelancer',
      'account_status': 'pending',
      'skills': ['Flutter', 'Dart'],
    });

    expect(user.id, '42');
    expect(user.isPending, isTrue);
    expect(user.displayRole, 'Freelancer');
    expect(user.skills, ['Flutter', 'Dart']);
  });

  test('ApiProject and ApiTask tolerate nullable backend fields', () {
    final project = ApiProject.fromJson({
      'id': 7,
      'name': 'Backend Integration',
      'description': null,
      'status': 'active',
      'tasks': [
        {'id': 3, 'title': 'Wire Flutter', 'project_id': 7}
      ],
    });

    expect(project.id, '7');
    expect(project.tasks.single.id, '3');
    expect(project.tasks.single.projectId, '7');
  });
}
