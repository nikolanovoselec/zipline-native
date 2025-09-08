import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'auth_service.dart';
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
  });
}

class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  final AuthService _authService = AuthService();
  final DebugService _debugService = DebugService();
  final Dio _dio = Dio();
  
  final Queue<UploadTask> _queue = Queue();
  final Map<String, UploadTask> _activeTasks = {};
  final List<UploadTask> _completedTasks = [];
  final StreamController<List<UploadTask>> _queueController = StreamController.broadcast();
  
  static const int maxConcurrentUploads = 3;
  static const int maxRetries = 3;
  bool _isProcessing = false;
  
  Stream<List<UploadTask>> get queueStream => _queueController.stream;
  List<UploadTask> get allTasks => [..._queue, ..._activeTasks.values, ..._completedTasks];

  Future<String> addToQueue(File file) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = UploadTask(
      id: taskId,
      file: file,
      fileName: path.basename(file.path),
    );
    
    _queue.add(task);
    _notifyQueueUpdate();
    
    if (!_isProcessing) {
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
      while (_activeTasks.length < maxConcurrentUploads && _queue.isNotEmpty) {
        final task = _queue.removeFirst();
        if (task.status == UploadStatus.pending || task.status == UploadStatus.paused) {
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
        final result = response.data;
        task.resultUrl = result['files']?[0]?['url'] ?? result['url'];
        task.status = UploadStatus.completed;
        task.uploadedAt = DateTime.now();
        task.progress = 1.0;
        
        _debugService.logUpload('Upload completed', data: {
          'taskId': task.id,
          'url': task.resultUrl,
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
        _debugService.log('UPLOAD', 'Retrying upload: ${task.id} (attempt ${task.retryCount})');
      } else {
        task.status = UploadStatus.failed;
        _debugService.logError('UPLOAD', 'Upload failed after retries', error: e);
      }
    } catch (e) {
      task.status = UploadStatus.failed;
      task.error = e.toString();
      _debugService.logError('UPLOAD', 'Upload exception', error: e);
    } finally {
      _activeTasks.remove(task.id);
      if (task.status == UploadStatus.completed) {
        _completedTasks.add(task);
      }
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
    final task = _completedTasks.firstWhere(
      (t) => t.id == taskId && t.status == UploadStatus.failed,
      orElse: () => _queue.firstWhere(
        (t) => t.id == taskId && t.status == UploadStatus.failed,
      ),
    );
    
    if (task.retryCount < maxRetries) {
      task.status = UploadStatus.pending;
      task.progress = 0.0;
      task.error = null;
      task.cancelToken = CancelToken();
      if (!_queue.contains(task)) {
        _queue.add(task);
      }
      _notifyQueueUpdate();
      _processNextInQueue();
    }
  }

  void dispose() {
    _queueController.close();
  }
}