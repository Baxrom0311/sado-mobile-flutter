import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/assessments_api.dart';
import '../models/models.dart';

/// A single assessment audio submission that has been queued because the
/// network was unavailable when the user finished recording.
@immutable
class PendingUpload {
  final String id;
  final String childId;
  final String exerciseId;
  final String audioPath;
  final DateTime createdAt;
  final int retries;

  const PendingUpload({
    required this.id,
    required this.childId,
    required this.exerciseId,
    required this.audioPath,
    required this.createdAt,
    this.retries = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'child_id': childId,
        'exercise_id': exerciseId,
        'audio_path': audioPath,
        'created_at': createdAt.toIso8601String(),
        'retries': retries,
      };

  factory PendingUpload.fromJson(Map json) => PendingUpload(
        id: json['id'] as String,
        childId: json['child_id'] as String,
        exerciseId: json['exercise_id'] as String,
        audioPath: json['audio_path'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        retries: (json['retries'] as int?) ?? 0,
      );

  PendingUpload incrementRetries() => PendingUpload(
        id: id,
        childId: childId,
        exerciseId: exerciseId,
        audioPath: audioPath,
        createdAt: createdAt,
        retries: retries + 1,
      );
}

/// Outcome of a flush() / processAll() run.
@immutable
class FlushResult {
  final int succeeded;
  final int failed;
  final List<Assessment> uploaded;

  const FlushResult({
    required this.succeeded,
    required this.failed,
    required this.uploaded,
  });

  bool get hasWork => succeeded + failed > 0;
}

/// Hive-backed queue for assessment audio submissions that failed because
/// the network was unreachable. Items are retried automatically when the
/// device comes back online or manually from the UI.
class PendingUploadsService {
  PendingUploadsService._(this._box);

  static const _boxName = 'sado_pending_uploads';

  final Box _box;

  // Single in-flight flush at a time so we don't double-submit a job.
  bool _flushing = false;

  /// Open or reuse the Hive box.
  static Future<PendingUploadsService> open() async {
    final box = await Hive.openBox(_boxName);
    return PendingUploadsService._(box);
  }

  /// Synchronous variant for tests, given an already-open box.
  @visibleForTesting
  factory PendingUploadsService.fromBox(Box box) =>
      PendingUploadsService._(box);

  /// Add a job to the queue. The audio file at [audioPath] should already be
  /// in a stable location (e.g. application documents directory). The job is
  /// keyed by [id] (typically a millisecond timestamp).
  Future<PendingUpload> enqueue({
    required String id,
    required String childId,
    required String exerciseId,
    required String audioPath,
  }) async {
    final job = PendingUpload(
      id: id,
      childId: childId,
      exerciseId: exerciseId,
      audioPath: audioPath,
      createdAt: DateTime.now(),
    );
    await _box.put(id, job.toJson());
    return job;
  }

  /// All queued jobs, oldest first.
  List<PendingUpload> all() {
    final out = <PendingUpload>[];
    for (final raw in _box.values) {
      if (raw is Map) {
        try {
          out.add(PendingUpload.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // skip malformed entries
        }
      }
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  int get count => _box.length;

  /// Stream of queue size; emits on every box mutation plus an initial value.
  Stream<int> watchCount() async* {
    yield _box.length;
    await for (final _ in _box.watch()) {
      yield _box.length;
    }
  }

  Future<void> remove(String id) async {
    final job = _box.get(id);
    await _box.delete(id);
    // Best-effort: delete the cached audio file too.
    if (job is Map) {
      final p = job['audio_path'];
      if (p is String) {
        try {
          final f = File(p);
          if (f.existsSync()) await f.delete();
        } catch (_) {/* ignore */}
      }
    }
  }

  Future<void> clear() => _box.clear();

  /// Try to upload a single queued job. Returns `null` on success (the job
  /// is removed from the queue) or the bumped [PendingUpload] on failure.
  /// Used by the UI when the user taps "retry" on a specific row.
  Future<PendingUpload?> retryOne(String id, AssessmentsApi api) async {
    final raw = _box.get(id);
    if (raw is! Map) return null;
    final job = PendingUpload.fromJson(Map<String, dynamic>.from(raw));
    final file = File(job.audioPath);
    if (!file.existsSync()) {
      // Audio gone — drop the orphaned entry.
      await _box.delete(id);
      return null;
    }
    try {
      await api.create(
        childId: job.childId,
        exerciseId: job.exerciseId,
        audioPath: job.audioPath,
      );
      await remove(id);
      return null;
    } catch (_) {
      final bumped = job.incrementRetries();
      await _box.put(id, bumped.toJson());
      return bumped;
    }
  }

  /// Try to upload every queued job using [api]. Returns a summary.
  /// On failure, the job's retry counter is bumped and it stays in the queue.
  Future<FlushResult> flush(AssessmentsApi api) async {
    if (_flushing) {
      return const FlushResult(succeeded: 0, failed: 0, uploaded: []);
    }
    _flushing = true;
    int ok = 0;
    int bad = 0;
    final uploaded = <Assessment>[];
    try {
      for (final job in all()) {
        // Audio file might have been cleaned up out of band.
        final file = File(job.audioPath);
        if (!file.existsSync()) {
          await _box.delete(job.id);
          continue;
        }
        try {
          final result = await api.create(
            childId: job.childId,
            exerciseId: job.exerciseId,
            audioPath: job.audioPath,
          );
          uploaded.add(result);
          await remove(job.id);
          ok++;
        } catch (_) {
          // Bump retries and keep it for next time.
          await _box.put(job.id, job.incrementRetries().toJson());
          bad++;
        }
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(succeeded: ok, failed: bad, uploaded: uploaded);
  }
}
