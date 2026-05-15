import 'dart:typed_data';

import '../../core/network/api_result.dart';
import '../../core/network/service_error_handler.dart';
import '../../data/repositories/ai_repository.dart';
import '../../data/repositories/cv_repository.dart';

/// Service layer for all AI-powered features.
///
/// Converts raw AI API responses into meaningful, UI-ready results:
/// - Transcription (voice note → text)
/// - Anomaly detection (admin alert enrichment)
/// - Mentor analysis (performance insights dashboard data)
/// - CV building
class AIService with ServiceErrorHandler {
  final AIRepository _ai;
  final CVRepository _cv;

  AIService({
    required AIRepository ai,
    required CVRepository cv,
  })  : _ai = ai,
        _cv = cv;

  // ── Transcription ─────────────────────────────────────────────────────

  /// Transcribes audio bytes into text.
  /// Returns a [TranscriptionResult] ready for UI display.
  Future<ApiResult<TranscriptionResult>> transcribe(
    Uint8List audioBytes, {
    String filename = 'audio.wav',
  }) =>
      guard(() async {
        final data = await _ai.transcribe(audioBytes, filename: filename);
        return TranscriptionResult(
          text: data['text']?.toString() ?? '',
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
          language: data['language']?.toString() ?? 'en',
          durationMs: (data['duration_ms'] as num?)?.toInt() ?? 0,
        );
      });

  // ── Anomaly Detection ─────────────────────────────────────────────────

  /// Runs anomaly detection and returns structured alert data.
  Future<ApiResult<AnomalyReport>> detectAnomaly(
    Map<String, dynamic> payload,
  ) =>
      guard(() async {
        final data = await _ai.detectAnomaly(payload);
        final anomalies = (data['anomalies'] as List?)
                ?.map((e) => AnomalyItem.fromJson(
                    e is Map<String, dynamic> ? e : const {}))
                .toList() ??
            const [];
        return AnomalyReport(
          isAnomalous: data['is_anomalous'] == true,
          riskScore: (data['risk_score'] as num?)?.toDouble() ?? 0.0,
          anomalies: anomalies,
          summary: data['summary']?.toString() ?? '',
        );
      });

  // ── Mentor Analysis ───────────────────────────────────────────────────

  /// Fetches the full mentor analysis for a user,
  /// combining recommendations + performance + courses.
  Future<ApiResult<MentorInsights>> getMentorInsights(String userId) =>
      guard(() async {
        final results = await Future.wait([
          _ai.mentorAnalyse(userId),
          _ai.mentorPerformance(userId),
          _ai.mentorCourses(userId),
        ]);
        final analysis = results[0];
        final performance = results[1];
        final courses = results[2];

        return MentorInsights(
          overallScore: (analysis['overall_score'] as num?)?.toDouble() ?? 0.0,
          strengths: _toStringList(analysis['strengths']),
          weaknesses: _toStringList(analysis['weaknesses']),
          performanceHistory: performance,
          recommendedCourses: (courses['courses'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              const [],
          rawAnalysis: analysis,
        );
      });

  // ── Task AI features ──────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> classifyTask(String text) =>
      guard(() => _ai.classifyTask(text));

  Future<ApiResult<Map<String, dynamic>>> suggestPriority({
    required String projectId,
    String title = '',
    String description = '',
  }) =>
      guard(() => _ai.suggestPriority(
            projectId: projectId,
            title: title,
            description: description,
          ));

  Future<ApiResult<Map<String, dynamic>>> suggestDeadline({
    required String projectId,
    String priority = 'medium',
    String title = '',
    String description = '',
  }) =>
      guard(() => _ai.suggestDeadline(
            projectId: projectId,
            priority: priority,
            title: title,
            description: description,
          ));

  Future<ApiResult<Map<String, dynamic>>> predictDelay({
    String? taskId,
    String? projectId,
  }) =>
      guard(() => _ai.predictDelay(taskId: taskId, projectId: projectId));

  // ── CV AI ─────────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> buildCVWithAI(
          {String? targetUserId}) =>
      guard(() => _cv.buildWithAI(targetUserId: targetUserId));

  /// Downloads a CV PDF via secure token, returning raw bytes.
  Future<ApiResult<Uint8List>> downloadCVByToken(String token) =>
      guard(() async {
        final response = await _cv.downloadByToken(token);
        return Uint8List.fromList(response.data ?? []);
      });

  // ── Helpers ───────────────────────────────────────────────────────────

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}

// ── Result Models ─────────────────────────────────────────────────────────

class TranscriptionResult {
  final String text;
  final double confidence;
  final String language;
  final int durationMs;

  const TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.language,
    required this.durationMs,
  });
}

class AnomalyReport {
  final bool isAnomalous;
  final double riskScore;
  final List<AnomalyItem> anomalies;
  final String summary;

  const AnomalyReport({
    required this.isAnomalous,
    required this.riskScore,
    required this.anomalies,
    required this.summary,
  });
}

class AnomalyItem {
  final String type;
  final String description;
  final String severity;

  const AnomalyItem({
    required this.type,
    required this.description,
    required this.severity,
  });

  factory AnomalyItem.fromJson(Map<String, dynamic> json) => AnomalyItem(
        type: json['type']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'low',
      );
}

class MentorInsights {
  final double overallScore;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, dynamic> performanceHistory;
  final List<Map<String, dynamic>> recommendedCourses;
  final Map<String, dynamic> rawAnalysis;

  const MentorInsights({
    required this.overallScore,
    required this.strengths,
    required this.weaknesses,
    required this.performanceHistory,
    required this.recommendedCourses,
    required this.rawAnalysis,
  });
}
