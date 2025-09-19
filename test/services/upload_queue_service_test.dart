import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zipline_native_app/services/upload_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    UploadQueueService.setAutoProcessEnabled(false);
  });

  tearDown(() {
    UploadQueueService.setAutoProcessEnabled(true);
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
}
