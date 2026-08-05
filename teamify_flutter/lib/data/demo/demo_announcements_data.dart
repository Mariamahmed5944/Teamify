import 'package:flutter/material.dart';
import '../models/admin_announcement_model.dart';

/// Global in-memory list for Demo Mode Admin Announcements.
final List<AdminAnnouncement> demoAnnouncementsList = [
  AdminAnnouncement(
    id: 'ann_1',
    title: 'Platform Maintenance Notice: v2.5 Deployment',
    message:
        'Teamify will undergo scheduled maintenance tonight at 2:00 AM UTC. Services will be unavailable for approximately 30 minutes while database indexes are updated.',
    audience: AnnouncementAudience.allUsers,
    inAppNotification: true,
    emailNotification: true,
    status: AnnouncementStatus.scheduled,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    scheduledAt: DateTime.now().add(const Duration(hours: 8)),
  ),
  AdminAnnouncement(
    id: 'ann_2',
    title: 'New AI Resume Optimizer Feature Launch',
    message:
        'We are excited to introduce AI Smart Resume Analysis for all Student and Freelancer tier accounts! Check out the Resume tab to build tailored CVs.',
    audience: AnnouncementAudience.students,
    inAppNotification: true,
    emailNotification: true,
    status: AnnouncementStatus.sent,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    sentAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
  ),
  AdminAnnouncement(
    id: 'ann_3',
    title: 'Q3 Team Lead Leadership Workshop',
    message:
        'Exclusive invitation for Startup Founders & Team Owners: Join our live webinar on distributed sprint management and conflict resolution.',
    audience: AnnouncementAudience.teamOwners,
    inAppNotification: true,
    emailNotification: false,
    status: AnnouncementStatus.draft,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  AdminAnnouncement(
    id: 'ann_4',
    title: 'Updated Recruiter Security & Verification Guidelines',
    message:
        'All corporate recruiters are required to enable 2FA authentication by next Friday to maintain access to candidate search endpoints.',
    audience: AnnouncementAudience.recruiters,
    inAppNotification: true,
    emailNotification: true,
    status: AnnouncementStatus.cancelled,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    scheduledAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

/// Helper methods to mutate demo announcements in local state.
class DemoAnnouncementStore extends ChangeNotifier {
  static final DemoAnnouncementStore instance = DemoAnnouncementStore._();
  DemoAnnouncementStore._();

  List<AdminAnnouncement> get items => List.unmodifiable(demoAnnouncementsList);

  void add(AdminAnnouncement item) {
    demoAnnouncementsList.insert(0, item);
    notifyListeners();
  }

  void update(AdminAnnouncement item) {
    final idx = demoAnnouncementsList.indexWhere((element) => element.id == item.id);
    if (idx != -1) {
      demoAnnouncementsList[idx] = item;
      notifyListeners();
    }
  }

  void delete(String id) {
    demoAnnouncementsList.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void duplicate(AdminAnnouncement item) {
    final copy = item.copyWith(
      id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
      title: '${item.title} (Copy)',
      status: AnnouncementStatus.draft,
      createdAt: DateTime.now(),
      sentAt: null,
    );
    demoAnnouncementsList.insert(0, copy);
    notifyListeners();
  }

  void markAsSent(String id) {
    final idx = demoAnnouncementsList.indexWhere((element) => element.id == id);
    if (idx != -1) {
      demoAnnouncementsList[idx] = demoAnnouncementsList[idx].copyWith(
        status: AnnouncementStatus.sent,
        sentAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void cancelScheduled(String id) {
    final idx = demoAnnouncementsList.indexWhere((element) => element.id == id);
    if (idx != -1) {
      demoAnnouncementsList[idx] = demoAnnouncementsList[idx].copyWith(
        status: AnnouncementStatus.cancelled,
      );
      notifyListeners();
    }
  }
}
