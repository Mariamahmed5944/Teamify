import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/models.dart' as api;
import 'widgets.dart';

/// Rich member row: avatar, name, @username, meta line, optional skills.
class ProjectMemberDetailTile extends StatelessWidget {
  final api.ApiUser user;
  final bool showSkills;
  final bool showJoinedAt;
  final bool useAccountRole;
  final Widget? trailing;

  const ProjectMemberDetailTile({
    super.key,
    required this.user,
    this.showSkills = true,
    this.showJoinedAt = false,
    this.useAccountRole = false,
    this.trailing,
  });

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final name = user.primaryName;
    final role = useAccountRole ? user.displayRole : user.projectRoleLabel;
    final meta = _metaLine(user);
    final skills = user.skillsSummary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TAvatar(initials: _initials(name), radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (user.displayName.isNotEmpty &&
                  user.displayName != name)
                Text(
                  '@${user.displayName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (role.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              if (showSkills && skills.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Skills: $skills',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              if (showJoinedAt && user.joinedAt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Joined ${_formatJoined(user.joinedAt)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatJoined(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }

  String _metaLine(api.ApiUser user) {
    final parts = <String>[];
    if (user.email.isNotEmpty) parts.add(user.email);
    if (!useAccountRole && user.displayRole.isNotEmpty) {
      parts.add(user.displayRole);
    }
    if (user.professionalField.isNotEmpty) {
      parts.add(user.professionalField);
    }
    if (user.availability.isNotEmpty) parts.add(user.availability);
    if (user.experienceLevel.isNotEmpty) parts.add(user.experienceLevel);
    return parts.join(' · ');
  }
}
