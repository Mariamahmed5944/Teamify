import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the course provider URL (Coursera, Udemy, YouTube, etc.) in the browser.
Future<void> openCourseLink(
  BuildContext context,
  Map<String, dynamic> course,
) async {
  final title = course['title']?.toString() ?? 'Course';
  final platform = course['platform']?.toString() ??
      course['provider']?.toString() ??
      'provider';
  final urlStr = course['url']?.toString() ?? '';
  final uri = Uri.tryParse(urlStr);
  if (uri == null || !uri.hasScheme) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No link available for $title')),
    );
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  if (launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $title on $platform…')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open course link')),
    );
  }
}
