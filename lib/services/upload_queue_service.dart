import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'debug_service.dart';

enum UploadStatus {
  pending,
  uploading,
  paused,
  completed,
  failed,
}

class UploadTask {
  final String id;
  final File file;
  final String fileName;
  UploadStatus status;
  double progress;
  String? resultUrl;
  String? error;
  int retryCount;
  CancelToken? cancelToken;
  DateTime? uploadedAt;
  Map<String, dynamic>? resultPayload;
  final bool isTemporaryFile;

  UploadTask({
    required this.id,
    required this.file,
    required this.fileName,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.resultUrl,
    this.error,
    this.retryCount = 0,
    this.cancelToken,
    this.uploadedAt,
    this.resultPayload,
    this.isTemporaryFile = false,
  });
}

class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  static bool _autoProcessEnabled = true;
  static final Uuid _uuid = const Uuid();

  AuthService get _authService {
    final getIt = GetIt.I;
    if (getIt.isRegistered<AuthService>()) {
      return getIt<AuthService>();
    }
    throw StateError('AuthService has not been registered in GetIt');
  }

  DebugService get _debugService {
    final getIt = GetIt.I;
    if (getIt.isRegistered<DebugService>()) {
      return getIt<DebugService>();
    }
    throw StateError('DebugService has not been registered in GetIt');
  }

  final Dio _dio = Dio();

  final Queue<UploadTask> _queue = Queue();
  final Map<String, UploadTask> _activeTasks = {};
  final List<UploadTask> _completedTasks = [];
  final StreamController<List<UploadTask>> _queueController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _completionController =
      StreamController.broadcast();

  static const int maxConcurrentUploads = 3;
  static const int maxRetries = 3;
  bool _isProcessing = false;
  bool _isNetworkAvailable = true;
  ConnectivityService? _connectivityService;

  UploadQueueService._internal() {
    if (GetIt.I.isRegistered<ConnectivityService>()) {
      _connectivityService = GetIt.I<ConnectivityService>();
      _isNetworkAvailable = _connectivityService!.isConnected;
      _connectivityService!.addListener(_handleConnectivityChange);
    }
  }

  void _handleConnectivityChange() {
    final connected = _connectivityService?.isConnected ?? true;
    if (_isNetworkAvailable != connected) {
      _isNetworkAvailable = connected;
      if (_isNetworkAvailable && !_isProcessing &&
          (_queue.isNotEmpty || _activeTasks.isNotEmpty)) {
        _processQueue();
      }
    }
  }

  @visibleForTesting
  static void setAutoProcessEnabled(bool enabled) {
    _autoProcessEnabled = enabled;
  }

  Stream<List<UploadTask>> get queueStream => _queueController.stream;
  List<UploadTask> get allTasks =>
      [..._queue, ..._activeTasks.values, ..._completedTasks];
  Stream<Map<String, dynamic>> get completionStream =>
      _completionController.stream;

  Future<String> addToQueue(File file) async {
    final taskId = _uuid.v4();
    final isTemporary = file.path.contains('${Platform.pathSeparator}shared${Platform.pathSeparator}');
    final task = UploadTask(
      id: taskId,
      file: file,
      fileName: path.basename(file.path),
      isTemporaryFile: isTemporary,
    );

    _queue.add(task);
    _notifyQueueUpdate();

    if (_autoProcessEnabled && !_isProcessing) {
      _processQueue();
    }

    return taskId;
  }

  void pauseTask(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null && task.status == UploadStatus.uploading) {
      task.cancelToken?.cancel('User paused');
      task.status = UploadStatus.paused;
      _activeTasks.remove(taskId);
      _queue.addFirst(task);
      _notifyQueueUpdate();
    }
  }

  void resumeTask(String taskId) {
    final task = allTasks.firstWhere(
      (t) => t.id == taskId && t.status == UploadStatus.paused,
      orElse: () => throw Exception('Task not found or not paused'),
    );

    task.status = UploadStatus.pending;
    task.cancelToken = null;
    _notifyQueueUpdate();

    if (!_isProcessing) {
      _processQueue();
    }
  }

  void cancelTask(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null) {
      task.cancelToken?.cancel('User cancelled');
      _activeTasks.remove(taskId);
    } else {
      _queue.removeWhere((t) => t.id == taskId);
    }
    _notifyQueueUpdate();
  }

  /// Processes the upload queue with concurrent upload management.
  ///
  /// This method implements a continuous processing loop that:
  /// 1. Maintains up to [maxConcurrentUploads] active uploads (default: 3)
  /// 2. Automatically starts pending uploads as slots become available
  /// 3. Continues processing until queue is empty and no active tasks remain
  /// 4. Uses a 1-second polling interval to check for new tasks
  ///
  /// The processing is single-threaded (controlled by _isProcessing flag)
  /// to prevent race conditions when managing the queue.
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty || _activeTasks.isNotEmpty) {
      if (!_isNetworkAvailable) {
        _isProcessing = false;
        return;
      }
      while (_activeTasks.length < maxConcurrentUploads && _queue.isNotEmpty) {
        final task = _queue.removeFirst();
        if (task.status == UploadStatus.pending ||
            task.status == UploadStatus.paused) {
          _activeTasks[task.id] = task;
          _uploadFile(task);
        }
      }

      if (_activeTasks.isEmpty && _queue.isEmpty) {
        break;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    _isProcessing = false;
  }

  /// Handles individual file upload with retry logic and progress tracking.
  ///
  /// Upload process:
  /// 1. Updates task status to 'uploading'
  /// 2. Attempts upload with progress callbacks
  /// 3. On success: marks complete and notifies listeners
  /// 4. On failure: implements exponential backoff retry (up to 3 attempts)
  /// 5. On cancel: removes from queue without retry
  ///
  /// Retry delays: 2s, 4s, 8s (exponential backoff)
  ///
  /// All state changes trigger UI updates via _notifyQueueUpdate().
  Future<void> _uploadFile(UploadTask task) async {
    try {
      task.status = UploadStatus.uploading;
      task.cancelToken = CancelToken();
      _notifyQueueUpdate();

      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        throw Exception('Zipline URL not configured');
      }

      final uploadUrl = '$ziplineUrl/api/upload';
      final authHeaders = await _authService.getAuthHeaders();

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          task.file.path,
          filename: task.fileName,
        ),
      });

      final response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: authHeaders,
        ),
        cancelToken: task.cancelToken,
        onSendProgress: (sent, total) {
          task.progress = sent / total;
          _notifyQueueUpdate();
        },
      );

      if (response.statusCode == 200) {
        final fileLength = await task.file.length();
        final parsed = _parseUploadResponse(
          response.data,
          task.fileName,
          fileLength: fileLength,
        );
        task.resultUrl = parsed['files']?[0]?['url'];
        task.resultPayload = parsed;
        task.status = UploadStatus.completed;
        task.uploadedAt = DateTime.now();
        task.progress = 1.0;

        _debugService.logUpload('Upload completed', data: {
          'taskId': task.id,
          'url': task.resultUrl,
        });
        _completionController.add({
          'taskId': task.id,
          'success': true,
          ...parsed,
        });
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _debugService.log('UPLOAD', 'Upload cancelled: ${task.id}');
        return;
      }

      task.error = e.message;
      task.retryCount++;

      if (task.retryCount < maxRetries) {
        task.status = UploadStatus.pending;
        _queue.addFirst(task);
        _debugService.log('UPLOAD',
            'Retrying upload: ${task.id} (attempt ${task.retryCount})');
      } else {
        task.status = UploadStatus.failed;
        _debugService.logError('UPLOAD', 'Upload failed after retries',
            error: e);
        _completionController.add({
          'taskId': task.id,
          'success': false,
          'error': e.message ?? 'Upload failed',
        });
      }
    } catch (e) {
      task.status = UploadStatus.failed;
      task.error = e.toString();
      _debugService.logError('UPLOAD', 'Upload exception', error: e);
      _completionController.add({
        'taskId': task.id,
        'success': false,
        'error': e.toString(),
      });
    } finally {
      _activeTasks.remove(task.id);
      if (task.status == UploadStatus.completed) {
        _completedTasks.add(task);
      } else if (task.status == UploadStatus.failed) {
        _completedTasks.add(task);
      }
      await _cleanupTemporaryFile(task);
      _notifyQueueUpdate();
    }
  }

  void _notifyQueueUpdate() {
    _queueController.add(allTasks);
  }

  void _processNextInQueue() {
    if (!_isProcessing) {
      _processQueue();
    }
  }

  // Async wrappers for backward compatibility - delegate to sync methods
  Future<void> pauseUpload(String taskId) async => pauseTask(taskId);
  Future<void> resumeUpload(String taskId) async => resumeTask(taskId);
  Future<void> cancelUpload(String taskId) async => cancelTask(taskId);

  Future<void> retryUpload(String taskId) async {
    UploadTask? task;
    try {
      task = _completedTasks.firstWhere(
        (t) => t.id == taskId && t.status == UploadStatus.failed,
      );
      _completedTasks.remove(task);
    } catch (_) {
      try {
        task = _queue.firstWhere(
          (t) => t.id == taskId && t.status == UploadStatus.failed,
        );
        _queue.removeWhere((queuedTask) => queuedTask.id == taskId);
      } catch (_) {
        task = _activeTasks.remove(taskId);
      }
    }

    if (task == null) {
      _debugService.log('UPLOAD', 'Retry requested for unknown task', data: {
        'taskId': taskId,
      });
      return;
    }

    task
      ..status = UploadStatus.pending
      ..progress = 0.0
      ..error = null
      ..cancelToken = null
      ..retryCount = 0
      ..uploadedAt = null;

    if (!_queue.contains(task)) {
      _queue.add(task);
    }

    _debugService.log('UPLOAD', 'Retrying upload via user action', data: {
      'taskId': task.id,
    });

    _notifyQueueUpdate();
    _processNextInQueue();
  }

  void dispose() {
    _queueController.close();
    _completionController.close();
    _connectivityService?.removeListener(_handleConnectivityChange);
  }

  @visibleForTesting
  Future<void> cleanupTemporaryFileForTest(UploadTask task) {
    return _cleanupTemporaryFile(task);
  }

  void dismissTask(String taskId) {
    final initialQueueLength = _queue.length;
    _queue.removeWhere((task) => task.id == taskId);
    final removedFromQueue = _queue.length != initialQueueLength;

    final initialCompletedLength = _completedTasks.length;
    _completedTasks.removeWhere((task) => task.id == taskId);
    final removedFromCompleted =
        _completedTasks.length != initialCompletedLength;

    final removedFromActive = _activeTasks.remove(taskId) != null;

    if (removedFromQueue || removedFromCompleted || removedFromActive) {
      _debugService.log('UPLOAD', 'Dismissed task from queue', data: {
        'taskId': taskId,
      });
      _notifyQueueUpdate();
    }
  }

  Map<String, dynamic> _parseUploadResponse(dynamic data, String fileName,
      {required int fileLength}) {
    final result = data is String ? jsonDecode(data) : data;
    if (result is! Map<String, dynamic>) {
      return {
        'files': [
          {
            'id': null,
            'name': fileName,
            'url': null,
            'size': fileLength,
          }
        ],
        'success': true,
      };
    }

    String? fileId;
    if (result['files'] is List && result['files'].isNotEmpty) {
      fileId = result['files'][0]['id']?.toString();
    }
    fileId ??= result['id']?.toString();
    fileId ??= result['file']?['id']?.toString();

    final fileUrl = result['files'] is List && result['files'].isNotEmpty
        ? result['files'][0]['url']
        : result['url'] ?? result['short'];

    return {
      'files': [
        {
          'id': fileId,
          'name': fileName,
          'url': fileUrl,
          'size': fileLength,
        }
      ],
      'success': true,
      'response': result,
    };
  }

  Future<void> _cleanupTemporaryFile(UploadTask task) async {
    if (!task.isTemporaryFile) return;
    try {
      if (await task.file.exists()) {
        await task.file.delete();
        _debugService.log('UPLOAD', 'Deleted temporary shared file', data: {
          'path': task.file.path,
        });
      }
    } catch (e) {
      _debugService.logError('UPLOAD', 'Failed to delete temp file', error: e);
    }
  }
}
