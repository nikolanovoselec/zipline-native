import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:zipline_native_app/services/activity_service.dart';
import 'package:zipline_native_app/services/file_upload_service.dart';
import 'package:zipline_native_app/services/sharing_service.dart';
import 'package:zipline_native_app/services/upload_queue_service.dart';

class MockFileUploadService extends Mock implements FileUploadService {}

class MockUploadQueueService extends Mock implements UploadQueueService {}

class MockActivityService extends Mock implements ActivityService {}

void main() {
  final getIt = GetIt.instance;
  late MockFileUploadService mockFileUploadService;
  late MockUploadQueueService mockUploadQueueService;
  late MockActivityService mockActivityService;
  late StreamController<Map<String, dynamic>> completionController;
  late SharingService sharingService;

  setUpAll(() {
    registerFallbackValue(<File>[]);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    SharingService().dispose();
    getIt.reset();

    mockFileUploadService = MockFileUploadService();
    mockUploadQueueService = MockUploadQueueService();
    mockActivityService = MockActivityService();
    completionController = StreamController<Map<String, dynamic>>.broadcast();

    getIt.registerSingleton<FileUploadService>(mockFileUploadService);
    getIt.registerSingleton<UploadQueueService>(mockUploadQueueService);
    getIt.registerSingleton<ActivityService>(mockActivityService);

    when(() => mockUploadQueueService.completionStream)
        .thenAnswer((_) => completionController.stream);
    when(() => mockActivityService.addActivity(any()))
        .thenAnswer((_) async {});

    sharingService = SharingService();
  });

  tearDown(() async {
    await completionController.close();
    sharingService.dispose();
    getIt.reset();
  });

  test('notifies completion for queued uploads', () async {
    when(() => mockFileUploadService.uploadMultipleFiles(
          any(),
          onProgress: null,
          useQueue: true,
        )).thenAnswer((_) async => [
          {
            'success': true,
            'queued': true,
            'taskIds': ['task-1'],
          }
        ]);

    final completer = Completer<List<Map<String, dynamic>>>();
    sharingService.onUploadComplete = completer.complete;
    sharingService.onError = (message) {
      fail('Unexpected error: $message');
    };

    await sharingService.uploadFiles([File('dummy')]);

    completionController.add({
      'taskId': 'task-1',
      'success': true,
      'files': [
        {
          'id': 'id-1',
          'name': 'test.txt',
          'url': 'https://example.com/test.txt',
          'size': 42,
        }
      ],
    });

    final results = await completer.future;
    expect(results, hasLength(1));
    expect(results.first['files'], isNotEmpty);
    expect(results.first['files'][0]['url'], 'https://example.com/test.txt');

    final captured = verify(() => mockActivityService.addActivity(captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(captured['type'], 'file_upload');
    expect(captured['success'], isTrue);
  });

  test('propagates errors from queue completions', () async {
    when(() => mockFileUploadService.uploadMultipleFiles(
          any(),
          onProgress: null,
          useQueue: true,
        )).thenAnswer((_) async => [
          {
            'success': true,
            'queued': true,
            'taskIds': ['task-err'],
          }
        ]);

    final errorCompleter = Completer<String>();
    sharingService.onError = errorCompleter.complete;

    await sharingService.uploadFiles([File('dummy')]);

    completionController.add({
      'taskId': 'task-err',
      'success': false,
      'error': 'network down',
    });

    expect(await errorCompleter.future, 'network down');
    verifyNever(() => mockActivityService.addActivity(any()));
  });

  test('handles immediate upload success responses', () async {
    when(() => mockFileUploadService.uploadMultipleFiles(
          any(),
          onProgress: null,
          useQueue: true,
        )).thenAnswer((_) async => [
          {
            'success': true,
            'files': [
              {
                'id': 'id-2',
                'name': 'direct.txt',
                'url': 'https://example.com/direct.txt',
                'size': 21,
              }
            ],
          }
        ]);

    final completer = Completer<List<Map<String, dynamic>>>();
    sharingService.onUploadComplete = completer.complete;

    await sharingService.uploadFiles([File('dummy')]);

    final results = await completer.future;
    expect(results, hasLength(1));
    final capture = verify(() => mockActivityService.addActivity(captureAny()))
        .captured
        .single as Map<String, dynamic>;
    expect(capture['type'], 'file_upload');
    expect((capture['files'] as List).first['url'],
        'https://example.com/direct.txt');
  });
}
