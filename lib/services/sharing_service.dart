import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../core/service_locator.dart';
import 'activity_service.dart';
import 'file_upload_service.dart';
import 'upload_queue_service.dart';

class SharingService {
  FileUploadService get _uploadService => GetIt.I<FileUploadService>();
  UploadQueueService get _queueService => GetIt.I<UploadQueueService>();
  ActivityService get _activityService => locator.activity;

  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  Function(List<File>)? onFilesShared;
  Function(double progress)? onProgress;
  Function(String)? onError;
  Function(List<Map<String, dynamic>>)? onUploadComplete;

  final Map<String, _PendingUpload> _pendingUploads = {};
  final Map<String, String> _taskIdToSession = {};
  StreamSubscription<Map<String, dynamic>>? _queueSubscription;
  final Uuid _uuid = const Uuid();

  void initialize() {
    _queueSubscription ??= _queueService.completionStream.listen((event) {
      unawaited(_handleQueueCompletion(event));
    });
  }

  Future<void> uploadFiles(
    List<File> files, {
    bool useQueue = true,
  }) async {
    initialize();
    try {
      onFilesShared?.call(files);
      final results = await _uploadService.uploadMultipleFiles(
        files,
        onProgress: !useQueue && onProgress != null
            ? (progress) => onProgress?.call(progress.clamp(0.0, 1.0))
            : null,
        useQueue: useQueue,
      );
      final queuedEntry = results.firstWhere(
        (result) => result['queued'] == true && result['taskIds'] is List,
        orElse: () => {},
      );

      if (queuedEntry.isEmpty) {
        if (results.isNotEmpty && results.any((r) => r['success'] == false)) {
          final message = results
                  .firstWhere((r) => r['success'] == false)['error']
                  ?.toString() ??
              'Upload failed';
          onError?.call(message);
        } else if (results.isNotEmpty) {
          onProgress?.call(1.0);
          onUploadComplete?.call(results);
          await _recordActivities(results);
        }
        return;
      }

      final taskIds = List<String>.from(queuedEntry['taskIds']);
      if (taskIds.isEmpty) {
        return;
      }

      final sessionId = _uuid.v4();
      final pending = _PendingUpload(taskIds.toSet());
      _pendingUploads[sessionId] = pending;
      for (final taskId in taskIds) {
        _taskIdToSession[taskId] = sessionId;
      }
    } catch (e) {
      onError?.call('Upload failed: $e');
    } finally {
      if (!useQueue) {
        unawaited(_cleanupTemporaryFiles(files));
      }
    }
  }

  void dispose() {
    _queueSubscription?.cancel();
    _pendingUploads.clear();
    _taskIdToSession.clear();
  }

  Future<void> _handleQueueCompletion(Map<String, dynamic> event) async {
    final taskId = event['taskId']?.toString();
    if (taskId == null) {
      return;
    }

    final sessionId = _taskIdToSession.remove(taskId);
    if (sessionId == null) {
      await _handleStandaloneEvent(event);
      return;
    }

    final pending = _pendingUploads[sessionId];
    if (pending == null) {
      await _handleStandaloneEvent(event);
      return;
    }

    pending.remainingTaskIds.remove(taskId);

    if (event['success'] == true) {
      final files = event['files'];
      final result = {
        'success': true,
        'files': files,
      };
      pending.successResults.add(result);
      await _recordActivities([result]);
    } else {
      final message = event['error']?.toString() ?? 'Upload failed';
      pending.errors.add(message);
      onError?.call(message);
    }

    if (pending.remainingTaskIds.isEmpty) {
      if (pending.successResults.isNotEmpty) {
        onUploadComplete?.call(pending.successResults);
      }
      _pendingUploads.remove(sessionId);
    }
  }

  Future<void> _handleStandaloneEvent(Map<String, dynamic> event) async {
    if (event['success'] == true) {
      final result = {
        'success': true,
        'files': event['files'],
      };
      onUploadComplete?.call([result]);
      await _recordActivities([result]);
    } else {
      final message = event['error']?.toString() ?? 'Upload failed';
      onError?.call(message);
    }
  }

  Future<void> _recordActivities(List<Map<String, dynamic>> results) async {
    for (final result in results) {
      final files = result['files'];
      if (files is List && files.isNotEmpty) {
        final entry = {
          'type': 'file_upload',
          'files': files,
          'success': result['success'] == true,
        };
        await _activityService.addActivity(entry);
      }
    }
  }

  Future<void> _cleanupTemporaryFiles(List<File> files) async {
    for (final file in files) {
      final path = file.path;
      if (!path.contains(
          '${Platform.pathSeparator}shared${Platform.pathSeparator}')) {
        continue;
      }

      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort cleanup; ignore failures.
      }
    }
  }

  @visibleForTesting
  Future<void> handleQueueEventForTest(Map<String, dynamic> event) async {
    await _handleQueueCompletion(event);
  }
}

class _PendingUpload {
  _PendingUpload(this.remainingTaskIds);

  final Set<String> remainingTaskIds;
  final List<Map<String, dynamic>> successResults = [];
  final List<String> errors = [];
}
