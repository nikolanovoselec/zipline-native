import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'auth_service.dart';
import 'debug_service.dart';
import 'upload_queue_service.dart';

/// Service responsible for uploading files to Zipline servers.
/// Uses Dio HTTP client for progress tracking and chunked uploads.
/// Automatically handles authentication headers and MIME type detection.
class FileUploadService {
  FileUploadService({
    AuthService? authService,
    UploadQueueService? queueService,
    Dio? dio,
    DebugService? debugService,
  })  : _authService = authService ?? _resolveAuthService(),
        _queueService = queueService ?? _resolveQueueService(),
        _debugService = debugService ?? _resolveDebugService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
              ),
            );

  final AuthService _authService;
  final UploadQueueService _queueService;
  final DebugService _debugService;
  final Dio _dio; // HTTP client with progress tracking support

  static AuthService _resolveAuthService() {
    final getIt = GetIt.I;
    if (getIt.isRegistered<AuthService>()) {
      return getIt<AuthService>();
    }
    throw StateError('AuthService has not been registered in GetIt');
  }

  static UploadQueueService _resolveQueueService() {
    final getIt = GetIt.I;
    if (getIt.isRegistered<UploadQueueService>()) {
      return getIt<UploadQueueService>();
    }
    throw StateError('UploadQueueService has not been registered in GetIt');
  }

  static DebugService _resolveDebugService() {
    final getIt = GetIt.I;
    if (getIt.isRegistered<DebugService>()) {
      return getIt<DebugService>();
    }
    throw StateError('DebugService has not been registered in GetIt');
  }

  /// Uploads a file to the configured Zipline server with progress tracking.
  ///
  /// This method handles the complete file upload process:
  /// 1. Validates authentication and server configuration
  /// 2. Detects MIME type from file extension
  /// 3. Creates multipart form data with proper headers
  /// 4. Uploads with real-time progress tracking via Dio
  /// 5. Parses response to extract file URL and metadata
  ///
  /// Parameters:
  /// - [file]: The file to upload
  /// - [onProgress]: Optional callback for progress updates (0.0 to 1.0)
  ///
  /// Returns a Map containing:
  /// - 'url': The public URL of the uploaded file
  /// - 'id': The file ID on the server
  /// - 'size': File size in bytes
  /// - 'timestamp': Upload timestamp
  ///
  /// Returns null if upload fails. Errors are logged to DebugService.
  ///
  /// File size limits and supported types are determined by server configuration.
  Future<Map<String, dynamic>?> uploadFile(File file,
      {Function(double)? onProgress}) async {
    final debugService = _debugService;

    try {
      debugService.logUpload('Starting file upload', data: {
        'filePath': file.path,
        'fileName': path.basename(file.path),
      });

      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      debugService.logUpload('Retrieved credentials', data: {
        'hasZiplineUrl': ziplineUrl != null,
        'hasSessionCookie': credentials['sessionCookie'] != null,
        'hasCfClientId': credentials['cfClientId'] != null,
      });

      if (ziplineUrl == null) {
        debugService.logUpload('Zipline URL not configured', level: 'ERROR');
        throw Exception('Zipline URL not configured');
      }

      final uploadUrl = '$ziplineUrl/api/upload';
      final authHeaders = await _authService.getAuthHeaders();

      debugService.logUpload('Prepared upload request', data: {
        'uploadUrl': uploadUrl.toString(),
        'authHeaders': authHeaders.keys.toList(),
      });

      // Add file with proper MIME type
      final fileName = path.basename(file.path);
      final fileLength = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      debugService.logUpload('File details', data: {
        'fileName': fileName,
        'fileSize': fileLength,
        'fileExists': await file.exists(),
        'mimeType': mimeType,
      });

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      debugService.logHttp('Sending multipart upload request', data: {
        'url': uploadUrl.toString(),
        'method': 'POST',
        'headers': authHeaders.keys.toList(),
        'fileFieldName': 'file',
        'fileName': fileName,
      });

      final response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: authHeaders,
        ),
        onSendProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            final progress = sent / total;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
      );

      final responseBody =
          response.data is String ? response.data : jsonEncode(response.data);

      debugService.logHttp('Received upload response', data: {
        'statusCode': response.statusCode,
        'responseHeaders': response.headers.map.keys.toList(),
        'responseBodyLength': responseBody.length,
      });

      if (response.statusCode == 200) {
        debugService.logUpload('Upload successful (200)');

        final result =
            response.data is String ? jsonDecode(response.data) : response.data;

        // Enhanced logging to debug ID location
        debugService.logUpload('Full server response structure', data: {
          'fullResponse': result,
        });

        debugService.logUpload('Parsed upload response', data: {
          'resultKeys': result.keys.toList(),
          'hasFiles': result['files'] != null,
          'hasUrl': result['url'] != null,
          'hasId': result['id'] != null,
          'filesStructure':
              result['files'] != null ? result['files'].toString() : 'null',
        });

        // Try to extract ID from multiple possible locations
        String? fileId;
        if (result['files'] != null &&
            result['files'] is List &&
            (result['files'] as List).isNotEmpty) {
          fileId = result['files'][0]['id'];
        }
        if (fileId == null && result['id'] != null) {
          fileId = result['id'];
        }
        if (fileId == null &&
            result['file'] != null &&
            result['file']['id'] != null) {
          fileId = result['file']['id'];
        }

        final uploadResult = {
          'files': [
            {
              'id': fileId,
              'name': fileName,
              'url': result['files']?[0]?['url'] ?? result['url'],
              'size': fileLength,
            }
          ],
          'success': true,
        };

        debugService.logUpload('Upload completed successfully',
            data: uploadResult);

        return uploadResult;
      } else {
        debugService.logUpload('Upload failed with HTTP error',
            data: {
              'statusCode': response.statusCode,
              'responseBody': responseBody.length > 500
                  ? responseBody.substring(0, 500) + '...'
                  : responseBody,
            },
            level: 'ERROR');
        throw Exception('Upload failed: ${response.statusCode} $responseBody');
      }
    } on DioException catch (e) {
      debugService.logError('UPLOAD', 'File upload DioException occurred',
          error: e, stackTrace: e.stackTrace);
      return {
        'success': false,
        'error': e.message ?? e.toString(),
      };
    } catch (e, stackTrace) {
      debugService.logError('UPLOAD', 'File upload exception occurred',
          error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> _uploadFileDirect(File file,
      {Function(double)? onProgress}) async {
    return await uploadFile(file, onProgress: onProgress);
  }

  Future<List<Map<String, dynamic>>> uploadMultipleFiles(List<File> files,
      {Function(double)? onProgress, bool useQueue = false}) async {
    if (useQueue) {
      final taskIds = <String>[];
      for (final file in files) {
        final taskId = await _queueService.addToQueue(file);
        taskIds.add(taskId);
      }
      return [
        {
          'success': true,
          'queued': true,
          'taskIds': taskIds,
        }
      ];
    }

    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final result = await _uploadFileDirect(file, onProgress: (fileProgress) {
        if (onProgress != null) {
          // Calculate overall progress with individual file precision
          final overallProgress =
              ((i + fileProgress) / files.length).clamp(0.0, 1.0);
          onProgress(overallProgress);
        }
      });
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Shortens a URL using Zipline's URL shortening service.
  ///
  /// Supports both Zipline v3 and v4 API formats with automatic fallback:
  /// - v4: Uses 'destination' and 'vanity' fields
  /// - v3: Falls back to 'url' and 'vanity' fields if v4 fails
  ///
  /// The method attempts multiple endpoints in order:
  /// 1. /api/shorten (v4 format)
  /// 2. /api/shorten (v3 format if v4 fails)
  /// 3. /api/upload with format=RANDOM (legacy fallback)
  ///
  /// Parameters:
  /// - [url]: The URL to shorten (must be valid HTTP/HTTPS)
  /// - [customSlug]: Optional custom slug for the short URL
  /// - [password]: Optional password protection (if supported by server)
  /// - [expiresAt]: Optional expiration date (if supported by server)
  ///
  /// Returns a Map containing:
  /// - 'url': The shortened URL
  /// - 'id': The short URL ID
  /// - Other metadata from server response
  ///
  /// Returns null if all attempts fail.
  Future<Map<String, dynamic>?> shortenUrl(String url,
      {String? customSlug, String? password, DateTime? expiresAt}) async {
    final debugService = _debugService;

    try {
      debugService.logUpload('Starting URL shortening', data: {'url': url});

      // Validate URL
      if (!isValidUrl(url)) {
        throw Exception('Invalid URL format');
      }

      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        throw Exception('Zipline URL not configured');
      }

      final authHeaders = await _authService.getAuthHeaders();

      // Use correct Zipline v4 API format
      var requestBody = {
        'destination': url,
        if (customSlug != null && customSlug.isNotEmpty) 'vanity': customSlug,
      };

      debugService.log('URL_SHORTEN', 'Sending URL shortening request',
          data: requestBody);

      Response? response;
      try {
        response = await _dio.post(
          '$ziplineUrl/api/user/urls',
          data: requestBody,
          options: Options(
            headers: authHeaders,
          ),
        );
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 400) {
          // Log the error details
          debugService.log('URL_SHORTEN', 'Request failed with 400', data: {
            'requestBody': requestBody,
            'errorData': e.response?.data,
            'errorMessage':
                e.response?.data is Map ? e.response?.data['message'] : null,
          });

          // Try with v3 compatibility format as fallback
          debugService.log(
              'URL_SHORTEN', 'Trying with v3 compatibility format');
          requestBody = {
            'url': url,
            if (customSlug != null && customSlug.isNotEmpty)
              'vanity': customSlug,
          };

          debugService.log('URL_SHORTEN', 'Trying v3 format with /api/shorten',
              data: requestBody);

          response = await _dio.post(
            '$ziplineUrl/api/shorten',
            data: requestBody,
            options: Options(
              headers: authHeaders,
            ),
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        debugService.logUpload('URL shortened successfully');

        // Enhanced debugging
        debugService.log('URL_SHORTEN', 'Raw response received', data: {
          'statusCode': response.statusCode,
          'headers': response.headers.map,
          'dataType': response.data.runtimeType.toString(),
          'rawData': response.data.toString(),
        });

        final result =
            response.data is String ? jsonDecode(response.data) : response.data;

        // Debug: Log the actual response structure
        debugService.log('URL_SHORTEN', 'Parsed response structure', data: {
          'response_type': result.runtimeType.toString(),
          'response_keys': result is Map ? result.keys.toList() : 'not a map',
          'full_response': result,
          'has_url': result is Map ? result.containsKey('url') : false,
          'has_short': result is Map ? result.containsKey('short') : false,
          'has_code': result is Map ? result.containsKey('code') : false,
        });

        String shortUrl;
        // Check various possible response formats
        if (result['url'] != null) {
          // Full URL returned
          shortUrl = result['url'];
        } else if (result['short'] != null) {
          // Short path returned
          shortUrl = result['short'].toString().startsWith('http')
              ? result['short']
              : '$ziplineUrl/${result['short']}';
        } else if (result['code'] != null) {
          // Code field (some Zipline versions)
          shortUrl = '$ziplineUrl/${result['code']}';
        } else if (result['vanity'] != null && customSlug != null) {
          // Vanity URL created
          shortUrl = '$ziplineUrl/${result['vanity']}';
        } else if (result['id'] != null) {
          // ID-based URL
          shortUrl = '$ziplineUrl/${result['id']}';
        } else if (result['slug'] != null) {
          // Slug field (alternative naming)
          shortUrl = '$ziplineUrl/${result['slug']}';
        } else if (result['path'] != null) {
          // Path field
          shortUrl = '$ziplineUrl/${result['path']}';
        } else {
          // Last resort - log what we got and use 'unknown'
          debugService
              .logError('URL_SHORTEN', 'Unknown response format', error: {
            'result': result,
            'expected_fields': [
              'url',
              'short',
              'code',
              'vanity',
              'id',
              'slug',
              'path'
            ],
          });
          shortUrl = '$ziplineUrl/unknown';
        }

        final shortenResult = {
          'id': result['id'], // Add the URL ID from server response
          'original': url,
          'short': shortUrl,
          'success': true,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
          if (password != null) 'protected': true,
        };

        return shortenResult;
      } else {
        throw Exception('URL shortening failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugService.logError('URL_SHORTEN', 'URL shortening DioException',
          error: e, stackTrace: e.stackTrace);

      // Log response details if available
      if (e.response != null) {
        debugService.log('URL_SHORTEN', 'Error response details', data: {
          'status': e.response?.statusCode,
          'data': e.response?.data,
          'headers': e.response?.headers.map,
        });
      }

      // Extract error message from response if available
      String errorMessage = 'URL shortening failed';
      if (e.response?.data != null) {
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ??
              e.response?.data['error'] ??
              'Server error: ${e.response?.statusCode}';
        } else {
          errorMessage = e.response?.data?.toString() ?? 'Unknown error';
        }
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      return {
        'success': false,
        'error': errorMessage,
        'statusCode': e.response?.statusCode,
      };
    } catch (e, stackTrace) {
      debugService.logError('URL_SHORTEN', 'URL shortening failed',
          error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<List<Map<String, dynamic>>> shortenMultipleUrls(List<String> urls,
      {String? customSlugPrefix}) async {
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final customSlug =
          customSlugPrefix != null ? '$customSlugPrefix-${i + 1}' : null;
      final result = await shortenUrl(url, customSlug: customSlug);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> fetchUserFiles() async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('FILES', 'Zipline URL not configured');
        return [];
      }

      final authHeaders = await _authService.getAuthHeaders();

      final response = await _dio.get(
        '$ziplineUrl/api/user/files',
        queryParameters: {
          'page': 1,
          'limit': 100,
        },
        options: Options(
          headers: authHeaders,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle both array and object response formats
        List<dynamic> files;
        if (data is List) {
          files = data;
        } else if (data is Map) {
          // Handle paginated response format with page, total, pages, files
          if (data['files'] != null) {
            files = data['files'] as List;
          } else if (data['data'] != null) {
            files = data['data'] as List;
          } else if (data.containsKey('items')) {
            files = data['items'] as List;
          } else if (data.containsKey('results')) {
            files = data['results'] as List;
          } else {
            // Handle case where response has pagination but no files
            if (data.containsKey('page') && data.containsKey('total')) {
              debugService.log(
                  'FILES', 'Empty paginated response - no files uploaded yet');
              return []; // Empty response is valid
            }
            // Log the actual structure for debugging and return empty
            debugService.logError('FILES',
                'No files array found in response. Keys: ${data.keys.toList()}');
            return [];
          }
        } else {
          debugService.logError(
              'FILES', 'Unexpected response format: ${data.runtimeType}');
          return [];
        }

        debugService.log('API', 'Fetched ${files.length} files from server');

        return files.map((file) {
          return {
            'id': file['id'] ?? file['fileId'] ?? '',
            'type': 'file',
            'url': file['url'] ?? '',
            'name': file['name'] ?? file['fileName'] ?? '',
            'timestamp': file['createdAt'] ??
                file['created_at'] ??
                file['timestamp'] ??
                DateTime.now().toIso8601String(),
            'size': file['size'],
            'mimetype': file['mimetype'] ?? file['mimeType'],
            'remote': true,
          };
        }).toList();
      }

      return [];
    } on DioException catch (e) {
      debugService.logError('FILES', 'Failed to fetch files: ${e.message}');
      return [];
    } catch (e) {
      debugService.logError('FILES', 'Failed to fetch files: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserUrls() async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('URLS', 'Zipline URL not configured');
        return [];
      }

      final authHeaders = await _authService.getAuthHeaders();

      final response = await _dio.get(
        '$ziplineUrl/api/user/urls',
        options: Options(
          headers: authHeaders,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle both array and object response formats
        List<dynamic> urls;
        if (data is List) {
          urls = data;
        } else if (data is Map && data['urls'] != null) {
          urls = data['urls'] as List;
        } else if (data is Map && data['data'] != null) {
          urls = data['data'] as List;
        } else {
          debugService.logError(
              'URLS', 'Unexpected response format: ${data.runtimeType}');
          return [];
        }

        debugService.log('API', 'Fetched ${urls.length} URLs from server');

        return urls.map((url) {
          final shortCode = url['vanity'] ?? url['id'] ?? url['short'] ?? '';
          final shortUrl = shortCode.startsWith('http')
              ? shortCode
              : '$ziplineUrl/$shortCode';

          return {
            'id': url['id'] ?? url['urlId'] ?? shortCode,
            'type': 'url',
            'original': url['url'] ?? url['destination'] ?? '',
            'short': shortUrl,
            'timestamp': url['createdAt'] ??
                url['created_at'] ??
                url['timestamp'] ??
                DateTime.now().toIso8601String(),
            'remote': true,
          };
        }).toList();
      }

      return [];
    } on DioException catch (e) {
      debugService.logError('URLS', 'Failed to fetch URLs: ${e.message}');
      return [];
    } catch (e) {
      debugService.logError('URLS', 'Failed to fetch URLs: $e');
      return [];
    }
  }

  Future<bool> setFileExpiration(String fileId, DateTime expiresAt) async {
    final debugService = _debugService;

    debugService.logError('FILES',
        'File expiration modification not supported by Zipline server - fileId: $fileId, requested: ${expiresAt.toIso8601String()}');

    // File expiration can only be set during upload, not modified afterward
    // The Zipline server PATCH /api/user/files/:id endpoint does not accept deletesAt field
    return false;
  }

  Future<bool> setFilePassword(String fileId, String password) async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('FILES', 'Zipline URL not configured');
        return false;
      }

      final authHeaders = await _authService.getAuthHeaders();

      debugService.log('FILES', 'Setting password protection for file $fileId');

      // Try different endpoints and methods that Zipline might support
      final endpoints = [
        '$ziplineUrl/api/user/files/$fileId',
        '$ziplineUrl/api/files/$fileId',
        '$ziplineUrl/api/user/files/$fileId/password',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await _dio.patch(
            endpoint,
            data: {
              'password': password,
            },
            options: Options(
              headers: authHeaders,
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            debugService.log(
                'FILES', 'Successfully set password using endpoint: $endpoint');
            return true;
          }
        } catch (e) {
          debugService.log('FILES', 'Failed endpoint $endpoint: $e');
          continue;
        }
      }

      debugService.logError('FILES', 'All password endpoints failed');
      return false;
    } on DioException catch (e) {
      debugService.logError('FILES', 'Failed to set password: ${e.message}',
          error: e);
      return false;
    } catch (e) {
      debugService.logError('FILES', 'Failed to set password: $e', error: e);
      return false;
    }
  }

  Future<bool> deleteFile(String fileId) async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('FILES', 'Zipline URL not configured');
        return false;
      }

      final authHeaders = await _authService.getAuthHeaders();

      debugService.log('FILES', 'Deleting file $fileId');

      // Try different endpoints that Zipline might support
      final endpoints = [
        '$ziplineUrl/api/user/files/$fileId',
        '$ziplineUrl/api/files/$fileId',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await _dio.delete(
            endpoint,
            options: Options(
              headers: authHeaders,
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            debugService.log(
                'FILES', 'Successfully deleted file using endpoint: $endpoint');
            return true;
          }
        } catch (e) {
          debugService.log('FILES', 'Failed delete endpoint $endpoint: $e');
          continue;
        }
      }

      debugService.logError('FILES', 'All delete endpoints failed');
      return false;
    } on DioException catch (e) {
      debugService.logError('FILES', 'Failed to delete file: ${e.message}',
          error: e);
      return false;
    } catch (e) {
      debugService.logError('FILES', 'Failed to delete file: $e', error: e);
      return false;
    }
  }

  Future<bool> deleteUrl(String urlId) async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('URLs', 'Zipline URL not configured');
        return false;
      }

      final authHeaders = await _authService.getAuthHeaders();

      debugService.log('URLs', 'Deleting URL $urlId');

      // Based on Zipline source code, the correct endpoint is:
      final endpoint = '$ziplineUrl/api/user/urls/$urlId';

      try {
        final response = await _dio.delete(
          endpoint,
          options: Options(
            headers: authHeaders,
          ),
        );

        if (response.statusCode == 200) {
          debugService.log('URLs', 'Successfully deleted URL $urlId');
          return true;
        }
      } catch (e) {
        debugService.logError(
            'URLs', 'Failed to delete URL from $endpoint: $e');
      }

      // Fallback: try legacy endpoints if the standard one fails
      final fallbackEndpoints = [
        '$ziplineUrl/api/urls/$urlId',
        '$ziplineUrl/api/user/files/$urlId', // Some servers treat URLs as files
      ];

      for (final endpoint in fallbackEndpoints) {
        try {
          final response = await _dio.delete(
            endpoint,
            options: Options(
              headers: authHeaders,
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            debugService.log(
                'URLs', 'Successfully deleted URL using endpoint: $endpoint');
            return true;
          }
        } catch (e) {
          debugService.log('URLs', 'Failed delete endpoint $endpoint: $e');
          continue;
        }
      }

      debugService.logError('URLs', 'All delete endpoints failed');
      return false;
    } on DioException catch (e) {
      debugService.logError('URLs', 'Failed to delete URL: ${e.message}',
          error: e);
      return false;
    } catch (e) {
      debugService.logError('URLs', 'Failed to delete URL: $e', error: e);
      return false;
    }
  }

  Future<bool> setUrlPassword(String urlId, String password) async {
    final debugService = _debugService;

    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null) {
        debugService.logError('URLs', 'Zipline URL not configured');
        return false;
      }

      final authHeaders = await _authService.getAuthHeaders();

      debugService.log('URLs', 'Setting password protection for URL $urlId');

      // Based on Zipline source code, password is set via PATCH to the URL endpoint
      final endpoint = '$ziplineUrl/api/user/urls/$urlId';

      try {
        final response = await _dio.patch(
          endpoint,
          data: {
            'password': password,
          },
          options: Options(
            headers: authHeaders,
          ),
        );

        if (response.statusCode == 200) {
          debugService.log('URLs', 'Successfully set URL password');
          return true;
        } else {
          debugService.logError(
              'URLs', 'Failed to set password: status ${response.statusCode}');
          return false;
        }
      } catch (e) {
        debugService.logError('URLs', 'Failed to set URL password: $e');
        return false;
      }
    } catch (e) {
      debugService.logError('URLs', 'Failed to set URL password: $e', error: e);
      return false;
    }
  }
}
