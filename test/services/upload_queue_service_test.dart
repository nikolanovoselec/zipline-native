import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:zipline_native_app/services/debug_service.dart';
import 'package:zipline_native_app/services/upload_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final getIt = GetIt.instance;

  setUp(() {
    getIt.reset();
    getIt.registerSingleton<DebugService>(DebugService());
    UploadQueueService.setAutoProcessEnabled(false);
  });

  tearDown(() {
    UploadQueueService.setAutoProcessEnabled(true);
    getIt.reset();
  });

  test('addToQueue generates UUID identifiers', () async {
    final service = UploadQueueService();
    final tempDir = await Directory.systemTemp.createTemp('upload-queue-test');
    final file = await File('${tempDir.path}/file.txt').create();

    final firstId = await service.addToQueue(file);
    final secondId = await service.addToQueue(file);

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );

    expect(firstId, matches(uuidRegex));
    expect(secondId, matches(uuidRegex));
    expect(firstId, isNot(equals(secondId)));

    service.cancelTask(firstId);
    service.cancelTask(secondId);
    await tempDir.delete(recursive: true);
  });

  test('cleanupTemporaryFileForTest removes shared intent files', () async {
    final service = UploadQueueService();
    final tempDir = await Directory.systemTemp.createTemp('upload-queue-shared');
    final sharedDir = Directory('${tempDir.path}/shared');
    await sharedDir.create(recursive: true);
    final file = await File('${sharedDir.path}/shared.txt').create();
    await file.writeAsString('shared-content');

    final task = UploadTask(
      id: 'task-clean',
      file: file,
      fileName: 'shared.txt',
      isTemporaryFile: true,
    );

    expect(await file.exists(), isTrue);

    await service.cleanupTemporaryFileForTest(task);

    expect(await file.exists(), isFalse);
    await tempDir.delete(recursive: true);
  });
}
