import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sado_mobile/data/api/assessments_api.dart';
import 'package:sado_mobile/data/services/pending_uploads_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockResponse extends Mock implements Response<dynamic> {}

void main() {
  late Directory tempDir;
  late Box box;
  late PendingUploadsService service;
  late File audioFile;

  setUpAll(() {
    registerFallbackValue(FormData());
    registerFallbackValue(Options());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sado_pu_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox(
      'pu_${DateTime.now().microsecondsSinceEpoch}',
    );
    service = PendingUploadsService.fromBox(box);

    audioFile = File('${tempDir.path}/sample.m4a');
    await audioFile.writeAsBytes([0, 1, 2, 3]);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PendingUploadsService', () {
    test('enqueue persists job and bumps count', () async {
      expect(service.count, 0);

      final job = await service.enqueue(
        id: 'a',
        childId: 'child-1',
        exerciseId: 'exercise-1',
        audioPath: audioFile.path,
      );

      expect(service.count, 1);
      expect(job.childId, 'child-1');
      expect(service.all().single.id, 'a');
    });

    test('all() returns jobs sorted by createdAt', () async {
      await service.enqueue(
        id: 'old',
        childId: 'c',
        exerciseId: 'e',
        audioPath: audioFile.path,
      );
      // Force a different timestamp.
      await Future.delayed(const Duration(milliseconds: 5));
      await service.enqueue(
        id: 'new',
        childId: 'c',
        exerciseId: 'e',
        audioPath: audioFile.path,
      );

      final jobs = service.all();
      expect(jobs.map((j) => j.id), ['old', 'new']);
    });

    test('remove() deletes the entry and the audio file', () async {
      final f = File('${tempDir.path}/to_remove.m4a');
      await f.writeAsBytes([7]);
      await service.enqueue(
        id: 'x',
        childId: 'c',
        exerciseId: 'e',
        audioPath: f.path,
      );
      expect(service.count, 1);

      await service.remove('x');

      expect(service.count, 0);
      expect(f.existsSync(), isFalse);
    });

    test('flush() drains successful uploads and keeps failures', () async {
      final dio = _MockDio();
      final response = _MockResponse();
      when(() => response.data).thenReturn({
        'id': 'srv-1',
        'child_id': 'child-1',
        'exercise_id': 'ex-1',
        'status': 'completed',
        'created_at': DateTime.now().toIso8601String(),
      });

      // First call succeeds, second call fails (network)
      var calls = 0;
      when(() => dio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onSendProgress: any(named: 'onSendProgress'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          )).thenAnswer((_) async {
        calls++;
        if (calls == 1) return response;
        throw DioException(
          requestOptions: RequestOptions(path: '/assessments'),
          type: DioExceptionType.connectionError,
        );
      });

      final api = AssessmentsApi(dio);

      await service.enqueue(
        id: 'a',
        childId: 'child-1',
        exerciseId: 'ex-1',
        audioPath: audioFile.path,
      );
      // Use a different file so the success branch's deletion doesn't
      // break the fail branch.
      final secondFile = File('${tempDir.path}/second.m4a');
      await secondFile.writeAsBytes([4, 5]);
      await service.enqueue(
        id: 'b',
        childId: 'child-1',
        exerciseId: 'ex-1',
        audioPath: secondFile.path,
      );

      final result = await service.flush(api);
      expect(result.succeeded, 1);
      expect(result.failed, 1);
      expect(service.count, 1);
      // Failed job's retry counter incremented.
      expect(service.all().single.retries, 1);
    });

    test('flush() drops jobs whose audio file no longer exists', () async {
      final ghost = File('${tempDir.path}/ghost.m4a');
      await ghost.writeAsBytes([1]);
      await service.enqueue(
        id: 'ghost',
        childId: 'c',
        exerciseId: 'e',
        audioPath: ghost.path,
      );
      // Delete the file out of band.
      await ghost.delete();

      final dio = _MockDio();
      final api = AssessmentsApi(dio);
      final result = await service.flush(api);

      expect(result.succeeded, 0);
      expect(result.failed, 0);
      expect(service.count, 0);
      verifyNever(() => dio.post(any()));
    });

    test('PendingUpload round-trips via JSON', () {
      final job = PendingUpload(
        id: 'j1',
        childId: 'c',
        exerciseId: 'e',
        audioPath: '/tmp/foo.m4a',
        createdAt: DateTime.parse('2024-01-02T03:04:05.000Z'),
        retries: 2,
      );
      final json = job.toJson();
      final round = PendingUpload.fromJson(json);
      expect(round.id, job.id);
      expect(round.childId, job.childId);
      expect(round.exerciseId, job.exerciseId);
      expect(round.audioPath, job.audioPath);
      expect(round.createdAt, job.createdAt);
      expect(round.retries, job.retries);
    });
  });
}
