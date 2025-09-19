import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/upload_queue_service.dart';
import '../core/service_locator.dart';

// App-wide state management using Provider
class AppState extends ChangeNotifier {
  // User state
  String? _username;
  String? _ziplineUrl;
  bool _isAuthenticated = false;

  // Upload state
  List<UploadTask> _uploadTasks = [];
  bool _uploadQueueVisible = false;

  // UI state
  bool _isLoading = false;
  String? _errorMessage;

  // Stream subscription for proper disposal
  StreamSubscription<List<UploadTask>>? _queueSubscription;

  // Getters
  String? get username => _username;
  String? get ziplineUrl => _ziplineUrl;
  bool get isAuthenticated => _isAuthenticated;
  List<UploadTask> get uploadTasks => _uploadTasks;
  bool get uploadQueueVisible => _uploadQueueVisible;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasFailedUploads =>
      _uploadTasks.any((task) => task.status == UploadStatus.failed);

  // Check if there are active uploads
  bool get hasActiveUploads => _uploadTasks.any((task) =>
      task.status == UploadStatus.uploading ||
      task.status == UploadStatus.pending);

  AppState() {
    _initializeState();
  }

  void _initializeState() {
    // Subscribe to upload queue changes with proper stream management
    final queueService = locator.uploadQueue;
    _queueSubscription = queueService.queueStream.listen((tasks) {
      _uploadTasks = tasks;

      // Auto-show queue when uploads are active
      if ((hasActiveUploads || hasFailedUploads) && !_uploadQueueVisible) {
        _uploadQueueVisible = true;
      }

      notifyListeners();
    });
  }

  // User actions
  void setUser(String? username, String? ziplineUrl) {
    _username = username;
    _ziplineUrl = ziplineUrl;
    _isAuthenticated = username != null;
    notifyListeners();
  }

  void logout() {
    _username = null;
    _ziplineUrl = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // Upload queue visibility
  void toggleUploadQueue() {
    _uploadQueueVisible = !_uploadQueueVisible;
    notifyListeners();
  }

  void showUploadQueue() {
    _uploadQueueVisible = true;
    notifyListeners();
  }

  void hideUploadQueue() {
    _uploadQueueVisible = false;
    notifyListeners();
  }

  // Loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Error handling
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Properly dispose of stream subscription to prevent memory leaks
    _queueSubscription?.cancel();
    super.dispose();
  }
}
