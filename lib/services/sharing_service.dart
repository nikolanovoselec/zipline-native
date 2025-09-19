import 'dart:io';
import 'package:get_it/get_it.dart';
import 'file_upload_service.dart';

class SharingService {
  FileUploadService get _uploadService => GetIt.I<FileUploadService>();

  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  Function(List<File>)? onFilesShared;
  Function(String)? onError;
  Function(List<Map<String, dynamic>>)? onUploadComplete;

  void initialize() {
    // Initialization complete - using platform channels for file sharing
  }

  Future<void> uploadFiles(List<File> files) async {
    try {
      onFilesShared?.call(files);
      final results = await _uploadService.uploadMultipleFiles(
        files,
        useQueue: true,
      );
      onUploadComplete?.call(results);
    } catch (e) {
      onError?.call('Upload failed: $e');
    }
  }

  void dispose() {
    // Cleanup when needed
  }
}
