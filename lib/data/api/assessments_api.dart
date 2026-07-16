import 'package:dio/dio.dart';

import '../models/models.dart';

class AssessmentsApi {
  AssessmentsApi(this._dio);
  final Dio _dio;

  Future<PaginatedResponse<Assessment>> list({String? childId}) async {
    final res = await _dio.get('/assessments', queryParameters: {
      if (childId != null) 'child_id': childId,
    });
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: (data['has_more'] as bool?) ?? false,
    );
  }

  Future<Assessment> create({
    required String childId,
    required String exerciseId,
    String? audioPath,
  }) async {
    final formData = FormData.fromMap({
      'child_id': childId,
      'exercise_id': exerciseId,
      if (audioPath != null)
        'audio': await MultipartFile.fromFile(audioPath, filename: 'audio.m4a'),
    });
    final res = await _dio.post('/assessments', data: formData);
    return Assessment.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Assessment> get(String id) async {
    final res = await _dio.get('/assessments/$id');
    return Assessment.fromJson(res.data as Map<String, dynamic>);
  }

  /// Fetches the AI speech-analysis envelope for one assessment.
  ///
  /// Hits the parent-safe endpoint `GET /analysis/{assessment_id}` which
  /// is mounted at the root of the v1 router (NOT nested under
  /// `/assessments/...`). The response shape matches FastAPI's
  /// `AssessmentAnalysisResponse`:
  ///
  /// ```json
  /// {
  ///   "assessment_id": "...",
  ///   "overall_risk": "green",
  ///   "overall_confidence": 0.82,
  ///   "status": "completed",
  ///   "completed_at": "2025-06-12T01:00:00Z",
  ///   "results": [
  ///     {
  ///       "recording_id": "...",
  ///       "risk_level": "green",
  ///       "confidence": 0.84,
  ///       "transcript": "olma non rahmat",
  ///       "feature_summary": {
  ///         "duration_sec": 6.2,
  ///         "transcript_word_count": 3,
  ///         "voiced_ratio": 0.78,
  ///         "f0_mean": 245.1,
  ///         "weakest_phonemes": ["r", "sh"]
  ///       },
  ///       "model_name": "mock-xgb-v1",
  ///       "model_version": "0.1.0",
  ///       "created_at": "..."
  ///     }
  ///   ]
  /// }
  /// ```
  ///
  /// Returns an empty [AssessmentAnalysis] when the API responds with
  /// 404 or 204 — these mean "no analysis row yet" rather than "the
  /// request failed". Other transport errors propagate so the UI can
  /// decide whether to show its error state or just hide the card.
  Future<AssessmentAnalysis> getAnalysis(String id) async {
    try {
      final res = await _dio.get('/analysis/$id');
      final data = res.data;
      if (data is! Map) return const AssessmentAnalysis();
      return AssessmentAnalysis.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404 || code == 204) {
        return const AssessmentAnalysis();
      }
      rethrow;
    }
  }
}
