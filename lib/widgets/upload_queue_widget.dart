import 'package:flutter/material.dart';
import '../services/upload_queue_service.dart';

class UploadQueueWidget extends StatelessWidget {
  final UploadQueueService queueService;

  const UploadQueueWidget({
    super.key,
    required this.queueService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UploadTask>>(
      stream: queueService.queueStream,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final activeTasks = tasks
            .where((t) =>
                t.status == UploadStatus.uploading ||
                t.status == UploadStatus.pending)
            .toList();

        if (activeTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.95),
            border: Border.all(
              color: const Color(0xFF1976D2).withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: const Color(0xFF1976D2),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Uploading ${activeTasks.length} file${activeTasks.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showQueueDetails(context, tasks),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...activeTasks
                  .take(2)
                  .map((task) => _buildTaskItem(context, task)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, UploadTask task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.fileName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (task.status == UploadStatus.uploading)
                Text(
                  '${(task.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: const Color(0xFF1976D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (task.status == UploadStatus.pending)
                Text(
                  'Waiting...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              const SizedBox(width: 8),
              if (task.status == UploadStatus.uploading)
                IconButton(
                  onPressed: () => queueService.pauseUpload(task.id),
                  icon: Icon(
                    Icons.pause,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                task.status == UploadStatus.paused
                    ? Colors.orange
                    : const Color(0xFF1976D2),
              ),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueDetails(BuildContext context, List<UploadTask> tasks) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Upload Queue',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _buildDetailedTaskItem(context, task);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTaskItem(BuildContext context, UploadTask task) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (task.status) {
      case UploadStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case UploadStatus.uploading:
        statusColor = const Color(0xFF1976D2);
        statusIcon = Icons.upload;
        statusText = 'Uploading';
        break;
      case UploadStatus.paused:
        statusColor = Colors.orange;
        statusIcon = Icons.pause;
        statusText = 'Paused';
        break;
      case UploadStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case UploadStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = task.error ?? 'Failed';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.fileName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.paused) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                Row(
                  children: [
                    if (task.status == UploadStatus.uploading)
                      IconButton(
                        onPressed: () => queueService.pauseUpload(task.id),
                        icon: const Icon(Icons.pause, size: 16),
                        color: Colors.white.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    if (task.status == UploadStatus.paused)
                      IconButton(
                        onPressed: () => queueService.resumeUpload(task.id),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        color: Colors.white.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    IconButton(
                      onPressed: () => queueService.cancelUpload(task.id),
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.red.withValues(alpha: 0.7),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (task.status == UploadStatus.failed && task.retryCount < 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => queueService.retryUpload(task.id),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                ),
                child: Text(
                  'Retry (${3 - task.retryCount} attempts left)',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
