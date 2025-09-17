import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import '../services/debug_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugService _debugService = DebugService();
  String? _selectedCategory;
  String? _selectedLevel;
  List<DebugLog> _filteredLogs = [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _filteredLogs = _debugService.getLogs(
        category: _selectedCategory,
        level: _selectedLevel,
      );
    });
  }

  Future<void> _exportLogs() async {
    try {
      final file = await _debugService.exportLogsToFile(
        category: _selectedCategory,
        level: _selectedLevel,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Export Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Debug logs exported successfully!'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File: ${file.path.split('/').last}'),
                      FutureBuilder<int>(
                        future: file.length(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                                'Size: ${(snapshot.data! / 1024).toStringAsFixed(1)} KB');
                          }
                          return const Text('Size: calculating...');
                        },
                      ),
                      Text('Logs: ${_filteredLogs.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can share this file to troubleshoot authentication issues.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Share the file
                  await _shareLogFile(file);
                },
                child: const Text('Share JSON File'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareLogFile(File file) async {
    try {
      // Share the actual JSON file using Android share system
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject:
              'Zipline Debug Logs - ${DateTime.now().toString().split(' ')[0]}',
          text:
              'Debug logs exported from Zipline Native App for authentication troubleshooting.',
        ),
      );

      if (mounted) {
        if (result.status == ShareResultStatus.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Debug logs shared successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Fallback: copy to clipboard if sharing failed
          final content = await file.readAsString();
          await Clipboard.setData(ClipboardData(text: content));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Share failed - debug logs copied to clipboard as fallback'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Fallback: copy to clipboard on any error
        try {
          final content = await file.readAsString();
          await Clipboard.setData(ClipboardData(text: content));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Share failed: $e\nCopied to clipboard as fallback'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Share and clipboard failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange),
        title: const Text('Clear Debug Logs'),
        content: const Text(
            'Are you sure you want to clear all debug logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _debugService.clearLogs();
              Navigator.of(context).pop();
              _refreshLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debug logs cleared'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARN':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      case 'DEBUG':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _debugService.getLogStats();
    final categories = _debugService.getUniqueCategories();
    final levels = _debugService.getUniqueLevels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: 12),
                    Text('Export & Share JSON (${_filteredLogs.length} logs)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear All Logs'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'export') {
                _exportLogs();
              } else if (value == 'clear') {
                _clearLogs();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log Statistics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: stats.entries.map((entry) {
                      return Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        labelStyle: const TextStyle(fontSize: 12),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category Filter',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...categories.map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                      _refreshLogs();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Level Filter',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Levels'),
                      ),
                      ...levels.map((level) => DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value;
                      });
                      _refreshLogs();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Log list
          Expanded(
            child: _filteredLogs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bug_report, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No debug logs available'),
                        Text('Use the app and logs will appear here'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[
                          _filteredLogs.length - 1 - index]; // Reverse order
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ExpansionTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getLevelColor(log.level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            '${log.category}: ${log.message}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '${log.timestamp.split('T')[1].split('.')[0]} • ${log.level}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          children: [
                            if (log.data != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    _formatLogData(log.data!),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatLogData(Map<String, dynamic> data) {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}
