import 'dart:io';
import 'file_upload_service.dart';

class SharingService {
  final FileUploadService _uploadService = FileUploadService();

  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  Function(List<File>)? onFilesShared;
  Function(String)? onError;
  Function(List<Map<String, dynamic>>)? onUploadComplete;
  Function()? onClipboardCopy;

  void initialize() {
    // Initialization complete - using platform channels for file sharing
  }

  Future<void> uploadFiles(List<File> files) async {
    try {
      onFilesShared?.call(files);
      final results = await _uploadService.uploadMultipleFiles(files);
      onUploadComplete?.call(results);
    } catch (e) {
      onError?.call('Upload failed: $e');
    }
  }

  void dispose() {
    // Cleanup when needed
  }
}
