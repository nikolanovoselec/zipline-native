import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/service_locator.dart';
import '../services/auth_service.dart';
import '../services/file_upload_service.dart';
import '../services/upload_queue_service.dart';
import '../services/sharing_service.dart';
import '../services/intent_service.dart';
import '../services/activity_service.dart';
import '../widgets/upload_queue_widget.dart';
import 'settings_screen.dart';
import '../widgets/common/minimal_text_field.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _readyToShareMessage = 'Ready for sharing!';
  static const Duration _shareSheetDelay = Duration(seconds: 2);
  static const double _shareChipSize = 32.0;
  static const String _shareChipLabel = 'Share link';
  static const String _shareLogTag = 'SHARE_FLOW';

  final AuthService _authService = locator.auth;
  final FileUploadService _uploadService = locator.fileUpload;
  final UploadQueueService _queueService = locator.uploadQueue;
  final SharingService _sharingService = locator.sharing;
  final IntentService _intentService = locator.intent;
  final ActivityService _activityService = locator.activity;
  final _urlController = TextEditingController();
  final _customSlugController = TextEditingController();

  bool _isUploading = false;
  bool _isUrlShortening = false;
  double _uploadProgress = 0.0;
  List<Map<String, dynamic>> _uploadHistory = [];
  String? _ziplineUrl;
  String? _username;
  bool _shareSheetActive = false;

  @override
  void initState() {
    super.initState();
    locator.debug.log('APP', 'HomeScreen initialized');
    _loadUserInfo();
    _setupSharingService();
    _loadActivities();
    _checkForSharedContent();
  }

  Future<void> _loadUserInfo() async {
    final credentials = await _authService.getCredentials();
    String? username = credentials['username'];

    locator.debug.log('HOME', 'Loading user info', data: {
      'hasStoredUsername': username != null && username.isNotEmpty,
      'storedUsername': username,
    });

    // If username is missing (OAuth user), fetch from API
    if (username == null || username.isEmpty) {
      final userInfo = await _authService.fetchUserInfo();
      if (userInfo != null) {
        // Try multiple possible username fields (same logic as auth service)
        username = userInfo['username'] ??
            userInfo['name'] ??
            userInfo['email'] ??
            userInfo['preferred_username'] ??
            userInfo['sub'] ??
            userInfo['displayName'] ??
            userInfo['display_name'];

        // If we found a username, save it
        if (username != null && username.isNotEmpty) {
          await _authService.saveOAuthUsername(username);
          locator.debug.log('HOME', 'Username found in user info', data: {
            'username': username,
          });
        } else {
          // Use fallback
          username = 'nerd';
          await _authService.saveOAuthUsername(username);
          locator.debug.log('HOME', 'Using fallback username', data: {
            'fallback': username,
            'availableKeys': userInfo.keys.toList(),
          });
        }
      } else {
        // If fetch fails, use fallback
        username = 'nerd';
        await _authService.saveOAuthUsername(username);
        locator.debug.log('HOME', 'User info fetch failed, using fallback');
      }
    }

    setState(() {
      _ziplineUrl = credentials['ziplineUrl'];
      _username = username ?? 'nerd';
    });

    locator.debug.log('HOME', 'User info loaded', data: {
      'finalUsername': _username,
      'ziplineUrl': _ziplineUrl,
    });
  }

  Future<void> _loadActivities() async {
    final activities = await _activityService.getActivities();

    locator.debug.log('ACTIVITIES', 'Loaded activities from storage', data: {
      'totalActivities': activities.length,
      'activityTypes': activities.map((a) => a['type']).toSet().toList(),
    });

    // Debug first few items to understand structure
    for (int i = 0; i < (activities.length > 3 ? 3 : activities.length); i++) {
      final item = activities[i];
      locator.debug.log('ACTIVITIES', 'Activity item $i structure', data: {
        'type': item['type'],
        'hasId': item['id'] != null,
        'id': item['id'],
        'hasFiles': item['files'] != null,
        'filesCount': item['files']?.length ?? 0,
        'fileIds': item['files']?.map((f) => f['id'] ?? 'no-id').toList() ?? [],
        'allKeys': item.keys.toList(),
        'timestamp': item['timestamp'],
      });

      // Check if files have proper IDs
      if (item['files'] != null) {
        for (int j = 0; j < item['files'].length; j++) {
          final file = item['files'][j];
          locator.debug.log('ACTIVITIES', 'File $j in activity $i', data: {
            'hasId': file['id'] != null,
            'id': file['id'],
            'name': file['name'],
            'url': file['url'],
            'allFileKeys': file.keys.toList(),
          });
        }
      }
    }

    setState(() {
      _uploadHistory = activities;
    });
  }

  void _setupSharingService() {
    // _sharingService.onFilesShared = (List<File> files) {
    //   setState(() {
    //     _isUploading = true;
    //   });
    //   _showSuccessSnackBar('Received ${files.length} file(s) to upload');
    // };

    _sharingService.onUploadComplete = (List<Map<String, dynamic>> results) {
      setState(() {
        _uploadHistory.insertAll(0, results);
        _isUploading = false;
      });
      HapticFeedback.lightImpact();
      unawaited(_processUploadResults(results));
    };

    _sharingService.onError = (String error) {
      setState(() {
        _isUploading = false;
        _isUrlShortening = false;
      });
      _showErrorSnackBar(error);
    };

  }

  Future<void> _pickAndUploadFiles() async {
    locator.debug.log('UPLOAD', 'Manual file picker triggered');
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      locator.debug.log('UPLOAD', 'File picker result', data: {
        'hasResult': result != null,
        'fileCount': result?.files.length ?? 0,
        'fileNames': result?.files.map((f) => f.name).toList() ?? [],
      });

      if (result != null) {
        setState(() {
          _isUploading = true;
        });

        final files = result.files.map((file) => File(file.path!)).toList();
        locator.debug.log('UPLOAD', 'Starting upload of picked files', data: {
          'fileCount': files.length,
          'filePaths': files.map((f) => f.path).toList(),
        });
        await _uploadFiles(files);
      } else {
        locator.debug.log('UPLOAD', 'File picker cancelled by user');
      }
    } catch (e) {
      locator.debug.logError('UPLOAD', 'File picker error', error: e);
      _showErrorSnackBar('File picker error: $e', onRetry: _pickAndUploadFiles);
    }
  }

  Future<void> _checkForSharedContent() async {
    // Check for shared files from Android intent
    final sharedFiles = await _intentService.getSharedFiles();
    final sharedText = await _intentService.getSharedText();

    if (sharedFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });
      await _uploadFiles(sharedFiles);
    } else if (sharedText != null) {
      // Handle shared URL
      _urlController.text = sharedText;
      final normalizedUrl = _normalizeUrl(sharedText);
      if (_isUrl(normalizedUrl)) {
        // Auto-shorten if it's a URL after normalization
        await _shortenUrl();
      }
    }
  }

  bool _isUrl(String text) {
    return Uri.tryParse(text)?.hasScheme == true;
  }

  String _normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    // If it already has a scheme, return as is
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Check if it looks like a domain or URL without scheme
    if (trimmed.contains('.') || trimmed.contains('/')) {
      return 'https://$trimmed';
    }

    // Return as is for other cases (might be internal URLs or special cases)
    return trimmed;
  }

  Future<void> _uploadFiles(List<File> files) async {
    locator.debug.log('UPLOAD', 'Starting batch file upload', data: {
      'fileCount': files.length,
      'totalFiles': files
          .map((f) => {'name': f.path.split('/').last, 'path': f.path})
          .toList(),
    });

    try {
      setState(() {
        _uploadProgress = 0.0;
      });

      final results = await _uploadService.uploadMultipleFiles(
        files,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      locator.debug.log('UPLOAD', 'Batch upload completed', data: {
        'resultCount': results.length,
        'successCount': results.where((r) => r['success'] == true).length,
        'results': results
            .map((r) => {
                  'success': r['success'],
                  'hasUrl': r['files']?[0]?['url'] != null
                })
            .toList(),
      });

      if (mounted) {
        // Save successful uploads to persistent storage
        for (final result in results) {
          if (result['success'] == true) {
            await _activityService.addActivity({
              'type': 'file_upload',
              'files': result['files'],
              'success': result['success'],
            });
          }
        }

        // Reload activities from storage to get the limited list
        await _loadActivities();

        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });

        final successCount = results.where((r) => r['success'] == true).length;
        if (successCount > 0) {
          HapticFeedback.lightImpact();
          locator.debug
              .log('UPLOAD', 'Upload success, preparing post actions');
          await _processUploadResults(results);
        } else {
          _showErrorSnackBar('Upload failed for all files');
          locator.debug.log('UPLOAD', 'All uploads failed', level: 'ERROR');
        }
      }
    } catch (e) {
      locator.debug.logError('UPLOAD', 'Batch upload exception', error: e);
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
        _showErrorSnackBar('Upload failed: $e');
      }
    }
  }

  Future<void> _shortenUrl() async {
    final rawUrl = _urlController.text.trim();
    final normalizedUrl = _normalizeUrl(rawUrl);

    locator.debug.log('URL', 'URL shortening requested', data: {
      'rawUrl': rawUrl,
      'normalizedUrl': normalizedUrl,
      'hasCustomSlug': _customSlugController.text.trim().isNotEmpty,
      'customSlug': _customSlugController.text.trim(),
    });

    if (rawUrl.isEmpty) {
      locator.debug
          .log('URL', 'URL shortening failed - empty URL', level: 'ERROR');
      _showErrorSnackBar('Please enter a URL to shorten');
      return;
    }

    setState(() {
      _isUrlShortening = true;
    });

    try {
      final result = await _uploadService.shortenUrl(
        normalizedUrl,
        customSlug: _customSlugController.text.trim().isEmpty
            ? null
            : _customSlugController.text.trim(),
      );

      locator.debug.log('URL', 'URL shortening result', data: {
        'hasResult': result != null,
        'resultKeys': result?.keys.toList(),
        'hasUrl': result?['url'] != null,
      });

      if (result != null && result['success'] == true && mounted) {
        // Save URL shortening to persistent storage with both URLs
        await _activityService.addActivity({
          'id': result['id'], // Add URL ID for server operations
          'type': 'url_shortening',
          'originalUrl': normalizedUrl,
          'url': result['short'] ?? result['url'],
          'vanity': _customSlugController.text.trim().isEmpty
              ? null
              : _customSlugController.text.trim(),
          'success': true,
        });

        // Reload activities from storage
        await _loadActivities();

        setState(() {
          _urlController.clear();
          _customSlugController.clear();
          _isUrlShortening = false;
        });

        final shareUrl =
            (result['short'] ?? result['url']) as String? ?? normalizedUrl;
        await _copyShareAndNotify(
          shareUrl,
          displayName: normalizedUrl,
        );
        locator.debug.log('URL', 'URL shortening success, share sheet invoked');
      } else if (result != null && result['success'] == false) {
        // Handle API error response
        locator.debug
            .log('URL', 'URL shortening failed', level: 'ERROR', data: result);
        if (mounted) {
          setState(() {
            _isUrlShortening = false;
          });
          final errorMsg =
              result['error']?.toString() ?? 'URL shortening failed';
          // Extract cleaner error message if it's a DioException string
          final cleanError = errorMsg.contains('status code of 400')
              ? 'Invalid URL format or server rejected the request'
              : errorMsg.split('\n').first;
          _showErrorSnackBar(cleanError, onRetry: _shortenUrl);
        }
      } else {
        locator.debug
            .log('URL', 'URL shortening returned null result', level: 'ERROR');
        if (mounted) {
          setState(() {
            _isUrlShortening = false;
          });
          _showErrorSnackBar('URL shortening failed: No result returned',
              onRetry: _shortenUrl);
        }
      }
    } catch (e) {
      locator.debug.logError('URL', 'URL shortening exception', error: e);
      if (mounted) {
        setState(() {
          _isUrlShortening = false;
        });
        _showErrorSnackBar('URL shortening failed: $e', onRetry: _shortenUrl);
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
  }

  Future<void> _openShareSheet(String url, {String? subject}) async {
    if (_shareSheetActive) {
      locator.debug.log(_shareLogTag, 'Share sheet already active, skipping');
      return;
    }
    _shareSheetActive = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: url,
          subject: subject,
        ),
      );
    } catch (e, stackTrace) {
      locator.debug.logError(_shareLogTag, 'Failed to open share sheet',
          error: e,
          stackTrace: stackTrace,
          data: {
            'url': url,
            'subject': subject,
          });
      if (mounted) {
        _showHeaderNotification(
          'Unable to open share sheet',
          Colors.red.shade600,
        );
      }
    } finally {
      _shareSheetActive = false;
      locator.debug.log(_shareLogTag, 'Share sheet state reset');
    }
  }

  Future<void> _copyShareAndNotify(
    String url, {
    String? displayName,
    bool openShareSheet = true,
  }) async {
    locator.debug.log(_shareLogTag, 'Copying link to clipboard', data: {
      'displayName': displayName,
      'url': url,
      'openShareSheet': openShareSheet,
    });
    await _copyToClipboard(url);

    if (mounted) {
      _showHeaderNotification(_readyToShareMessage, Colors.green.shade600);
    }

    if (openShareSheet) {
      await Future.delayed(_shareSheetDelay);
      if (mounted) {
        await _openShareSheet(url, subject: displayName);
        locator.debug.log(_shareLogTag, 'Share sheet presented');
      }
    } else {
      locator.debug.log(_shareLogTag, 'Share sheet suppressed for copy only');
    }
  }

  Future<void> _processUploadResults(List<Map<String, dynamic>> results) async {
    final successful =
        results.where((result) => result['success'] == true).toList();

    if (successful.isEmpty) {
      locator.debug
          .log(_shareLogTag, 'No successful uploads to process', level: 'DEBUG');
      return;
    }

    if (successful.length == 1) {
      final files = successful.first['files'];
      if (files is List && files.length == 1) {
        final file = files.first as Map<String, dynamic>?;
        final url = file?['url'] as String?;
        final name = file?['name'] as String?;
        if (url != null) {
          locator.debug.log(_shareLogTag, 'Processed single upload result', data: {
            'displayName': name,
            'url': url,
          });
          await _copyShareAndNotify(
            url,
            displayName: name,
          );
          return;
        }
      }
    }

    if (!mounted) return;

    locator.debug.log(_shareLogTag, 'Prepared multiple upload links', data: {
      'linkCount': successful.fold<int>(0, (count, entry) {
        final files = entry['files'];
        if (files is List) {
          return count + files.length;
        }
        return count;
      }),
    });

    _showHeaderNotification(_readyToShareMessage, Colors.green.shade600);
  }

  void _handleRecentItemShare(String url, {String? displayName}) {
    locator.debug.log(_shareLogTag, 'Sharing recent item', data: {
      'displayName': displayName,
      'url': url,
    });
    unawaited(_copyShareAndNotify(
      url,
      displayName: displayName,
    ));
  }

  Widget _buildShareActionChip() {
    return Container(
      width: _shareChipSize,
      height: _shareChipSize,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.ios_share,
        color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
        size: 16,
      ),
    );
  }

  Future<void> _openServerInBrowser() async {
    try {
      final credentials = await _authService.getCredentials();
      final ziplineUrl = credentials['ziplineUrl'];

      if (ziplineUrl == null || ziplineUrl.isEmpty) {
        _showHeaderNotification(
          'No server URL configured',
          Colors.orange.shade600,
        );
        return;
      }

      final uri = Uri.parse(ziplineUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showHeaderNotification(
          'Could not open browser',
          Colors.red.shade600,
        );
      }
    } catch (e) {
      locator.debug
          .logError('BROWSER', 'Failed to open server in browser', error: e);
      _showHeaderNotification(
        'Failed to open browser',
        Colors.red.shade600,
      );
    }
  }

  void _showHeaderNotification(String message, Color color) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _HeaderNotificationOverlay(
        message: message,
        color: color,
        onComplete: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _customSlugController.dispose();
    super.dispose();
  }

  // Swipe action methods for recent items
  Future<void> _deleteRecentItem(Map<String, dynamic> item) async {
    await HapticFeedback.mediumImpact();

    // Remove from local activity list immediately for responsive UI
    setState(() {
      _uploadHistory.remove(item);
    });

    // Save updated activity list
    await _activityService.saveActivities(_uploadHistory);

    // If item has an ID, try to delete from server
    // For file uploads, ID is nested in files[0]['id'], for URLs it's at top level
    String? itemId;
    if (item['type'] == 'file_upload') {
      itemId = item['files']?[0]?['id'] as String?;
    } else {
      itemId = item['id'] as String?;
    }

    locator.debug.log('DELETE', 'Attempting to delete item', data: {
      'itemId': itemId,
      'hasItemId': itemId != null,
      'itemType': item['type'],
      'itemKeys': item.keys.toList(),
    });

    if (itemId != null) {
      bool success;
      if (item['type'] == 'url_shortening') {
        // Use URL-specific delete function
        success = await _uploadService.deleteUrl(itemId);
      } else {
        // Use file-specific delete function
        success = await _uploadService.deleteFile(itemId);
      }
      locator.debug.log('DELETE', 'Delete operation result', data: {
        'itemId': itemId,
        'itemType': item['type'],
        'success': success,
      });
    } else {
      locator.debug.log('DELETE', 'Cannot delete - no ID available', data: {
        'item': item,
      });
    }

    _showHeaderNotification(
      'Item Deleted!',
      Colors.red.shade600,
    );
  }

  Future<void> _setRecentItemPassword(Map<String, dynamic> item) async {
    await HapticFeedback.selectionClick();

    if (!mounted) return;

    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Password Protection',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              MinimalTextField(
                controller: passwordController,
                placeholder: 'Enter password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              MinimalTextField(
                controller: confirmPasswordController,
                placeholder: 'Confirm password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: const Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      if (passwordController.text.isNotEmpty &&
                          passwordController.text ==
                              confirmPasswordController.text) {
                        Navigator.of(context).pop(passwordController.text);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red.shade600,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF1976D2).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFF1976D2),
                    ),
                    child: const Text('Set Password'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      // Extract ID based on item type
      String? itemId;
      if (item['type'] == 'file_upload') {
        itemId = item['files']?[0]?['id'] as String?;
      } else {
        itemId = item['id'] as String?;
      }

      if (itemId != null) {
        bool success;
        if (item['type'] == 'url_shortening') {
          // Use URL-specific password function
          success = await _uploadService.setUrlPassword(itemId, result);
        } else {
          // Use file-specific password function
          success = await _uploadService.setFilePassword(itemId, result);
        }

        if (success) {
          setState(() {
            item['hasPassword'] = true;
          });
        }
      }

      _showHeaderNotification(
        'Password Added!',
        Colors.blue.shade600,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title, server info and settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0), // Aligns title with button center
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zipline Sharing',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.94),
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_ziplineUrl != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                Uri.tryParse(_ziplineUrl!)?.host ??
                                    _ziplineUrl!,
                                style: TextStyle(
                                  color: const Color(0xFF94A3B8)
                                      .withValues(alpha: 0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (_username != null)
                              Text(
                                'Welcome, $_username',
                                style: TextStyle(
                                  color: const Color(0xFF94A3B8)
                                      .withValues(alpha: 0.77),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Open in browser button with improved touch handling
                          GestureDetector(
                            behavior: HitTestBehavior.opaque, // Ensures all taps are captured
                            onTap: _openServerInBrowser,
                            child: Container(
                              padding: const EdgeInsets.all(10), // Increased from 6px to 10px for better touch area
                              child: Container(
                                width: 40, // Increased from 36px to 40px
                                height: 40, // Increased from 36px to 40px
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08), // Slightly more visible
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2), // More visible border
                                    width: 0.5, // Slightly thicker border
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.open_in_browser_outlined,
                                  color: const Color(0xFF94A3B8)
                                      .withValues(alpha: 0.9), // More visible icon
                                  size: 20, // Increased from 16px to 20px
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4), // Reduced from 8px to 4px to account for increased padding
                          // Settings button with improved touch handling
                          GestureDetector(
                            behavior: HitTestBehavior.opaque, // Ensures all taps are captured
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10), // Increased from 6px to 10px for better touch area
                              child: Container(
                                width: 40, // Increased from 36px to 40px
                                height: 40, // Increased from 36px to 40px
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08), // Slightly more visible
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2), // More visible border
                                    width: 0.5, // Slightly thicker border
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.settings_outlined,
                                  color: const Color(0xFF94A3B8)
                                      .withValues(alpha: 0.9), // More visible icon
                                  size: 20, // Increased from 16px to 20px
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Upload Files Card
                  _buildCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildIcon(
                              isUploading: _isUploading,
                              uploadingIcon: Icons.cloud_sync,
                              defaultIcon: Icons.file_present,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upload Files',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.91),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isUploading
                                        ? 'Processing files...'
                                        : 'Share files from your device',
                                    style: TextStyle(
                                      color: const Color(0xFF94A3B8)
                                          .withValues(alpha: 0.72),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 33),
                        _buildButton(
                          text: _isUploading ? 'Uploading...' : 'Select Files',
                          onPressed: _isUploading ? null : _pickAndUploadFiles,
                          isLoading: _isUploading,
                          progress: _isUploading ? _uploadProgress : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Shorten URL Card
                  _buildCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildIcon(
                              isUploading: false,
                              defaultIcon: Icons.link_rounded,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shorten URL',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.91),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create short links for sharing',
                                    style: TextStyle(
                                      color: const Color(0xFF94A3B8)
                                          .withValues(alpha: 0.72),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        MinimalTextField(
                          controller: _urlController,
                          placeholder: 'Enter or paste your URL',
                          icon: Icons.link,
                          showLabel: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _shortenUrl(),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 20),
                        MinimalTextField(
                          controller: _customSlugController,
                          placeholder: 'Enter custom slug (optional)',
                          icon: Icons.tag,
                          showLabel: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _shortenUrl(),
                        ),
                        const SizedBox(height: 31),
                        _buildButton(
                          text: _isUrlShortening
                              ? 'Creating short link...'
                              : 'Shorten URL',
                          onPressed: _isUrlShortening ? null : _shortenUrl,
                          isLoading: _isUrlShortening,
                        ),
                      ],
                    ),
                  ),

                  // History section with max 2 items
                  if (_uploadHistory.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await _activityService.clearActivities();
                            await _loadActivities();
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              color: const Color(0xFF1976D2)
                                  .withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Show max 100 recent items
                    ...List.generate(
                      _uploadHistory.length > 100 ? 100 : _uploadHistory.length,
                      (index) {
                        final item = _uploadHistory[index];
                        final isFile = item['type'] == 'file_upload';
                        final isUrlShortening =
                            item['type'] == 'url_shortening';

                        String displayUrl;
                        String displayName;

                        if (isFile) {
                          displayUrl = item['files']?[0]?['url'] ?? 'Unknown';
                          displayName = item['files']?[0]?['name'] ?? 'File';
                        } else if (isUrlShortening) {
                          displayUrl = item['url'] ?? 'Unknown';
                          displayName =
                              item['originalUrl'] ?? item['vanity'] ?? 'URL';
                        } else {
                          // Legacy format fallback
                          displayUrl = item['files']?[0]?['url'] ??
                              item['url'] ??
                              'Unknown';
                          displayName = item['files']?[0]?['name'] ??
                              item['vanity'] ??
                              'URL';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Slidable(
                            startActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) =>
                                      _setRecentItemPassword(item),
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  icon: Icons.lock_outline,
                                  label: 'Protect',
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteRecentItem(item),
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Delete',
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _handleRecentItemShare(
                                    displayUrl,
                                    displayName: displayName,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: _shareChipSize,
                                          height: _shareChipSize,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1976D2)
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF1976D2)
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            isFile
                                                ? Icons.file_present
                                                : Icons.link,
                                            color: const Color(0xFF1976D2)
                                                .withValues(alpha: 0.8),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  if (!isFile) ...[
                                                    Icon(
                                                      Icons.link,
                                                      size: 12,
                                                      color: const Color(
                                                              0xFF94A3B8)
                                                          .withValues(
                                                              alpha: 0.6),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      displayUrl,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: const Color(
                                                                0xFF94A3B8)
                                                            .withValues(
                                                                alpha: 0.7),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w300,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Semantics(
                                          button: true,
                                          label: _shareChipLabel,
                                          child: _buildShareActionChip(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24), // Minimal bottom padding
                ],
              ),
            ),
          ),
          // Upload queue overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: UploadQueueWidget(
              queueService: _queueService,
            ),
          ),
        ],
      ),
      // FAB removed - Library screen disabled
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.041),
            Colors.white.withValues(alpha: 0.019),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.29,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildIcon({
    required bool isUploading,
    IconData? uploadingIcon,
    required IconData defaultIcon,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withValues(alpha: 0.18),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.81),
          width: 1.1,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUploading && uploadingIcon != null ? uploadingIcon : defaultIcon,
        color: const Color(0xFF1976D2).withValues(alpha: 0.86),
        size: 16,
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
    bool isLoading = false,
    double? progress,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        children: [
          // Progress fill
          if (progress != null && progress > 0)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.78),
                  width: 0.85,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 44,
                  backgroundColor:
                      const Color(0xFF1976D2).withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF1976D2).withValues(alpha: 0.25),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.78),
                  width: 0.85,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          // Content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(17),
              child: Center(
                child: isLoading && progress == null
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              const Color(0xFF1976D2).withValues(alpha: 0.88),
                        ),
                      )
                    : Text(
                        progress != null
                            ? '${(progress * 100).toStringAsFixed(0)}%'
                            : text,
                        style: TextStyle(
                          color:
                              const Color(0xFF1976D2).withValues(alpha: 0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderNotificationOverlay extends StatefulWidget {
  final String message;
  final Color color;
  final VoidCallback onComplete;

  const _HeaderNotificationOverlay({
    required this.message,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_HeaderNotificationOverlay> createState() =>
      _HeaderNotificationOverlayState();
}

class _HeaderNotificationOverlayState extends State<_HeaderNotificationOverlay>
    with SingleTickerProviderStateMixin {
  static const double _bannerSecondaryAlpha = 0.85;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Start the animation
    _controller.forward();

    // Auto-dismiss after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final overlayHeight =
        (screenHeight * 0.15).clamp(100.0, screenHeight * 0.35).toDouble();
    final topInset = mediaQuery.padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: overlayHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Semantics(
                liveRegion: true,
                label: widget.message,
                child: Container(
                  width: double.infinity,
                  height: overlayHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color,
                        widget.color.withValues(
                          alpha: _bannerSecondaryAlpha,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 32.0,
                      right: 32.0,
                      top: topInset + 12.0,
                      bottom: 16.0,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ) ??
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
