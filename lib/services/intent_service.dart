import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'debug_service.dart';

class IntentService {
  static const platform =
      MethodChannel('com.example.zipline_native_app/intent');

  /// Get shared files from Android intent
  Future<List<File>> getSharedFiles() async {
    final debugService = DebugService();

    try {
      debugService.logIntent('Requesting shared files from Android');

      final List<dynamic>? filePaths =
          await platform.invokeMethod('getSharedFiles');

      debugService.logIntent('Received shared file paths', data: {
        'pathCount': filePaths?.length ?? 0,
        'paths': filePaths?.map((p) => p.toString()).toList(),
      });

      if (filePaths == null || filePaths.isEmpty) {
        debugService.logIntent('No shared files received');
        return [];
      }

      final List<File> files = [];

      for (final filePath in filePaths) {
        if (filePath is String) {
          debugService
              .logIntent('Processing file path', data: {'path': filePath});

          // Check if it's a content:// URI that needs copying
          if (filePath.startsWith('content://')) {
            debugService.logIntent('Detected content URI, attempting to copy',
                data: {'contentUri': filePath});

            // Try to get the actual filename first
            String? originalFileName = await getContentUriFileName(filePath);
            
            String fileName;
            if (originalFileName != null && originalFileName.isNotEmpty) {
              // Use the original filename
              fileName = originalFileName;
              debugService.logIntent('Using original filename', data: {
                'originalFileName': originalFileName,
              });
            } else {
              // Fallback to generated filename with proper extension
              final extension = _getFileExtensionFromUri(filePath);
              fileName = 'shared_file_${DateTime.now().millisecondsSinceEpoch}$extension';
              debugService.logIntent('Using generated filename (original not available)', data: {
                'generatedFileName': fileName,
              });
            }

            final copiedFile = await copyContentUriFile(filePath, fileName);
            if (copiedFile != null) {
              debugService.logIntent('Content URI copied successfully', data: {
                'originalUri': filePath,
                'copiedPath': copiedFile.path,
                'fileSize': await copiedFile.length(),
              });
              files.add(copiedFile);
            } else {
              debugService.logIntent('Failed to copy content URI',
                  data: {'contentUri': filePath}, level: 'ERROR');
            }
          } else {
            // Regular file path
            final file = File(filePath);
            final exists = await file.exists();

            debugService.logIntent('File existence check', data: {
              'path': filePath,
              'exists': exists,
            });

            if (exists) {
              files.add(file);
            }
          }
        }
      }

      debugService.logIntent('Shared files processed successfully', data: {
        'totalFiles': files.length,
        'fileNames': files.map((f) => path.basename(f.path)).toList(),
      });

      return files;
    } on PlatformException catch (e, stackTrace) {
      debugService.logError('INTENT', 'Platform exception getting shared files',
          error: e, stackTrace: stackTrace);
      return [];
    } catch (e, stackTrace) {
      debugService.logError('INTENT', 'Unexpected error getting shared files',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get shared text/URL from Android intent
  Future<String?> getSharedText() async {
    final debugService = DebugService();

    try {
      debugService.logIntent('Requesting shared text from Android');

      final text = await platform.invokeMethod('getSharedText');

      debugService.logIntent('Received shared text', data: {
        'hasText': text != null,
        'textLength': text?.length,
        'isUrl': text != null && Uri.tryParse(text)?.hasScheme == true,
      });

      return text;
    } on PlatformException catch (e, stackTrace) {
      debugService.logError('INTENT', 'Platform exception getting shared text',
          error: e, stackTrace: stackTrace);
      return null;
    } catch (e, stackTrace) {
      debugService.logError('INTENT', 'Unexpected error getting shared text',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get the actual filename from content URI  
  Future<String?> getContentUriFileName(String contentUri) async {
    final debugService = DebugService();
    
    try {
      debugService.logIntent('Getting filename from content URI', data: {
        'contentUri': contentUri,
      });
      
      final String? fileName = await platform.invokeMethod('getContentUriFileName', {
        'contentUri': contentUri,
      });
      
      debugService.logIntent('Retrieved filename from content URI', data: {
        'contentUri': contentUri,
        'fileName': fileName,
        'hasFileName': fileName != null && fileName.isNotEmpty,
      });
      
      return fileName;
    } on PlatformException catch (e, stackTrace) {
      debugService.logError('INTENT', 'Platform exception getting content URI filename',
          error: e, stackTrace: stackTrace);
      return null;
    } catch (e, stackTrace) {
      debugService.logError('INTENT', 'Unexpected error getting content URI filename',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Copy content URI file to app directory for access
  Future<File?> copyContentUriFile(String contentUri, String fileName) async {
    final debugService = DebugService();

    try {
      debugService.logIntent('Starting content URI copy', data: {
        'contentUri': contentUri,
        'fileName': fileName,
      });

      final appDir = await getApplicationDocumentsDirectory();
      final targetPath = path.join(appDir.path, 'shared', fileName);

      debugService.logIntent('Prepared copy target path', data: {
        'targetPath': targetPath,
      });

      // Ensure directory exists
      final targetDir = Directory(path.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
        debugService.logIntent('Created shared directory',
            data: {'dirPath': targetDir.path});
      }

      final bool success = await platform.invokeMethod('copyContentUriFile', {
        'contentUri': contentUri,
        'targetPath': targetPath,
      });

      debugService.logIntent('Content URI copy result', data: {
        'success': success,
        'targetPath': targetPath,
      });

      if (success) {
        final file = File(targetPath);
        if (await file.exists()) {
          debugService.logIntent('Content URI file copied and verified', data: {
            'filePath': file.path,
            'fileSize': await file.length(),
          });
          return file;
        }
      }

      debugService.logIntent('Content URI copy failed or file not found',
          level: 'ERROR');
      return null;
    } on PlatformException catch (e, stackTrace) {
      debugService.logError(
          'INTENT', 'Platform exception copying content URI file',
          error: e, stackTrace: stackTrace);
      return null;
    } catch (e, stackTrace) {
      debugService.logError(
          'INTENT', 'Unexpected error copying content URI file',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Extracts file extension from Android content URI using multiple detection strategies.
  /// 
  /// This method employs a comprehensive approach to determine file extensions:
  /// 1. Checks for MIME type patterns in the URI (e.g., image%2Fjpeg)
  /// 2. Looks for file extensions in URI segments
  /// 3. Maps MIME types to extensions for common formats
  /// 4. Handles special cases for various apps (Chrome, Photos, etc.)
  /// 5. Falls back to .tmp if no extension can be determined
  /// 
  /// The method is necessary because Android content URIs often don't include
  /// file extensions directly, requiring inference from MIME types or URI patterns.
  /// 
  /// Returns: File extension with dot prefix (e.g., '.jpg', '.pdf', '.tmp')
  String _getFileExtensionFromUri(String uri) {
    final debugService = DebugService();

    try {
      debugService.logIntent('Analyzing URI for file extension', data: {
        'uri': uri,
        'uriLength': uri.length,
      });

      // Decode URL-encoded MIME types and check for patterns
      final decodedUri = Uri.decodeFull(uri).toLowerCase();

      debugService.logIntent('Decoded URI for analysis', data: {
        'decodedUri': decodedUri,
        'containsImageJpeg': decodedUri.contains('image/jpeg'),
        'containsImagePng': decodedUri.contains('image/png'),
      });

      // Check for JPEG patterns
      if (decodedUri.contains('image/jpeg') ||
          decodedUri.contains('jpeg') ||
          decodedUri.contains('.jpg') ||
          decodedUri.contains('.jpeg')) {
        debugService
            .logIntent('Detected JPEG file type', data: {'extension': '.jpg'});
        return '.jpg';
      }

      // Check for PNG patterns
      if (decodedUri.contains('image/png') || decodedUri.contains('.png')) {
        debugService
            .logIntent('Detected PNG file type', data: {'extension': '.png'});
        return '.png';
      }

      // Check for WebP patterns
      if (decodedUri.contains('image/webp') || decodedUri.contains('.webp')) {
        debugService
            .logIntent('Detected WebP file type', data: {'extension': '.webp'});
        return '.webp';
      }

      // Check for MP4 video patterns
      if (decodedUri.contains('video/mp4') || decodedUri.contains('.mp4')) {
        debugService
            .logIntent('Detected MP4 file type', data: {'extension': '.mp4'});
        return '.mp4';
      }

      // Check for other video patterns
      if (decodedUri.contains('video/quicktime') ||
          decodedUri.contains('.mov')) {
        debugService
            .logIntent('Detected MOV file type', data: {'extension': '.mov'});
        return '.mov';
      }

      // Check for PDF patterns
      if (decodedUri.contains('application/pdf') ||
          decodedUri.contains('.pdf') ||
          decodedUri.contains('pdf')) {
        debugService
            .logIntent('Detected PDF file type', data: {'extension': '.pdf'});
        return '.pdf';
      }

      // Check for APK patterns (Android Package)
      if (decodedUri.contains('application/vnd.android.package-archive') ||
          decodedUri.contains('application/apk') ||
          decodedUri.contains('.apk') ||
          decodedUri.contains('apk')) {
        debugService
            .logIntent('Detected APK file type', data: {'extension': '.apk'});
        return '.apk';
      }

      // Check for ZIP patterns
      if (decodedUri.contains('application/zip') ||
          decodedUri.contains('application/x-zip') ||
          decodedUri.contains('zip') ||
          decodedUri.contains('.zip')) {
        debugService
            .logIntent('Detected ZIP file type', data: {'extension': '.zip'});
        return '.zip';
      }

      // Check for other Android app formats
      if (decodedUri.contains('.aab') || decodedUri.contains('aab')) {
        debugService
            .logIntent('Detected AAB file type', data: {'extension': '.aab'});
        return '.aab';
      }

      // Check for other common archive formats
      if (decodedUri.contains('.rar') || decodedUri.contains('rar')) {
        debugService
            .logIntent('Detected RAR file type', data: {'extension': '.rar'});
        return '.rar';
      }

      if (decodedUri.contains('.7z') || decodedUri.contains('7z')) {
        debugService
            .logIntent('Detected 7Z file type', data: {'extension': '.7z'});
        return '.7z';
      }

      // Check for Microsoft Office document formats
      if (decodedUri.contains('application/msword') ||
          decodedUri.contains('.doc') ||
          decodedUri.contains('doc')) {
        debugService
            .logIntent('Detected DOC file type', data: {'extension': '.doc'});
        return '.doc';
      }

      if (decodedUri.contains(
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document') ||
          decodedUri.contains('.docx') ||
          decodedUri.contains('docx')) {
        debugService
            .logIntent('Detected DOCX file type', data: {'extension': '.docx'});
        return '.docx';
      }

      // PowerPoint formats
      if (decodedUri.contains('application/vnd.ms-powerpoint') ||
          decodedUri.contains('.ppt') ||
          decodedUri.contains('ppt')) {
        debugService
            .logIntent('Detected PPT file type', data: {'extension': '.ppt'});
        return '.ppt';
      }

      if (decodedUri.contains(
              'application/vnd.openxmlformats-officedocument.presentationml.presentation') ||
          decodedUri.contains('.pptx') ||
          decodedUri.contains('pptx')) {
        debugService
            .logIntent('Detected PPTX file type', data: {'extension': '.pptx'});
        return '.pptx';
      }

      // Excel formats
      if (decodedUri.contains('application/vnd.ms-excel') ||
          decodedUri.contains('.xls') ||
          decodedUri.contains('xls')) {
        debugService
            .logIntent('Detected XLS file type', data: {'extension': '.xls'});
        return '.xls';
      }

      if (decodedUri.contains(
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') ||
          decodedUri.contains('.xlsx') ||
          decodedUri.contains('xlsx')) {
        debugService
            .logIntent('Detected XLSX file type', data: {'extension': '.xlsx'});
        return '.xlsx';
      }

      // Text formats
      if (decodedUri.contains('text/plain') ||
          decodedUri.contains('.txt') ||
          decodedUri.contains('txt')) {
        debugService
            .logIntent('Detected TXT file type', data: {'extension': '.txt'});
        return '.txt';
      }

      if (decodedUri.contains('text/rtf') ||
          decodedUri.contains('.rtf') ||
          decodedUri.contains('rtf')) {
        debugService
            .logIntent('Detected RTF file type', data: {'extension': '.rtf'});
        return '.rtf';
      }

      // Audio formats
      if (decodedUri.contains('audio/mpeg') ||
          decodedUri.contains('.mp3') ||
          decodedUri.contains('mp3')) {
        debugService
            .logIntent('Detected MP3 file type', data: {'extension': '.mp3'});
        return '.mp3';
      }

      if (decodedUri.contains('audio/wav') ||
          decodedUri.contains('.wav') ||
          decodedUri.contains('wav')) {
        debugService
            .logIntent('Detected WAV file type', data: {'extension': '.wav'});
        return '.wav';
      }

      if (decodedUri.contains('audio/flac') ||
          decodedUri.contains('.flac') ||
          decodedUri.contains('flac')) {
        debugService
            .logIntent('Detected FLAC file type', data: {'extension': '.flac'});
        return '.flac';
      }

      // Additional video formats
      if (decodedUri.contains('video/x-msvideo') ||
          decodedUri.contains('.avi') ||
          decodedUri.contains('avi')) {
        debugService
            .logIntent('Detected AVI file type', data: {'extension': '.avi'});
        return '.avi';
      }

      if (decodedUri.contains('video/x-matroska') ||
          decodedUri.contains('.mkv') ||
          decodedUri.contains('mkv')) {
        debugService
            .logIntent('Detected MKV file type', data: {'extension': '.mkv'});
        return '.mkv';
      }

      // Additional image formats
      if (decodedUri.contains('image/gif') ||
          decodedUri.contains('.gif') ||
          decodedUri.contains('gif')) {
        debugService
            .logIntent('Detected GIF file type', data: {'extension': '.gif'});
        return '.gif';
      }

      if (decodedUri.contains('image/bmp') ||
          decodedUri.contains('.bmp') ||
          decodedUri.contains('bmp')) {
        debugService
            .logIntent('Detected BMP file type', data: {'extension': '.bmp'});
        return '.bmp';
      }

      if (decodedUri.contains('image/tiff') ||
          decodedUri.contains('.tiff') ||
          decodedUri.contains('.tif') ||
          decodedUri.contains('tiff')) {
        debugService
            .logIntent('Detected TIFF file type', data: {'extension': '.tiff'});
        return '.tiff';
      }

      if (decodedUri.contains('image/svg+xml') ||
          decodedUri.contains('.svg') ||
          decodedUri.contains('svg')) {
        debugService
            .logIntent('Detected SVG file type', data: {'extension': '.svg'});
        return '.svg';
      }

      // Check for general image pattern
      if (decodedUri.contains('image/')) {
        debugService.logIntent(
            'Detected generic image type, defaulting to .jpg',
            data: {'extension': '.jpg'});
        return '.jpg';
      }

      debugService.logIntent('No file type detected, using .tmp fallback',
          data: {'extension': '.tmp'});
      return '.tmp';
    } catch (e) {
      debugService.logIntent('Exception in file extension detection',
          data: {'error': e.toString(), 'fallbackExtension': '.tmp'},
          level: 'ERROR');
      return '.tmp';
    }
  }
}
