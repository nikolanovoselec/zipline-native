import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/upload_queue_service.dart';
import '../core/service_locator.dart';

class UploadQueueOverlay extends StatefulWidget {
  final Widget child;

  const UploadQueueOverlay({
    super.key,
    required this.child,
  });

  @override
  State<UploadQueueOverlay> createState() => _UploadQueueOverlayState();
}

class _UploadQueueOverlayState extends State<UploadQueueOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final UploadQueueService _queueService = locator.uploadQueue;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final hasFailedTasks = appState.uploadTasks
            .any((task) => task.status == UploadStatus.failed);
        // Show/hide animation based on state
        if ((appState.hasActiveUploads || hasFailedTasks) &&
            appState.uploadQueueVisible) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }

        return Stack(
          children: [
            widget.child,
            if (appState.uploadTasks.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildUploadQueue(appState),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUploadQueue(AppState appState) {
    final activeTasks = appState.uploadTasks
        .where((task) =>
            task.status == UploadStatus.uploading ||
            task.status == UploadStatus.pending ||
            task.status == UploadStatus.paused)
        .toList();
    final failedTasks = appState.uploadTasks
        .where((task) => task.status == UploadStatus.failed)
        .toList();
    final hasActive = activeTasks.isNotEmpty;
    final hasFailed = failedTasks.isNotEmpty;

    if (!hasActive && !hasFailed && !appState.uploadQueueVisible) {
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  hasActive
                      ? 'Uploading ${activeTasks.length} file${activeTasks.length > 1 ? 's' : ''}'
                      : hasFailed
                          ? 'Upload issues'
                          : 'Uploads',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasFailed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${failedTasks.length} failed',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Minimize button
                IconButton(
                  onPressed: () => appState.hideUploadQueue(),
                  icon: Icon(
                    Icons.minimize,
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
          ),
          if (hasActive) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount:
                    activeTasks.length > 2 ? 2 : activeTasks.length,
                itemBuilder: (context, index) {
                  return _buildTaskItem(activeTasks[index]);
                },
              ),
            ),
            if (activeTasks.length > 2)
              Container(
                padding: const EdgeInsets.all(8),
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${activeTasks.length - 2} more uploads',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          if (hasFailed) ...[
            if (hasActive)
              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 1,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Needs attention',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ...failedTasks.map(_buildFailedTaskItem),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(UploadTask task) {
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
                  style: const TextStyle(
                    color: Color(0xFF1976D2),
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
              // Control buttons
              if (task.status == UploadStatus.uploading)
                IconButton(
                  onPressed: () => _queueService.pauseTask(task.id),
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
                )
              else if (task.status == UploadStatus.paused)
                IconButton(
                  onPressed: () => _queueService.resumeTask(task.id),
                  icon: Icon(
                    Icons.play_arrow,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              IconButton(
                onPressed: () => _queueService.cancelTask(task.id),
                icon: Icon(
                  Icons.close,
                  color: Colors.red.withValues(alpha: 0.7),
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

  Widget _buildFailedTaskItem(UploadTask task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.4),
          width: 1,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => _queueService.retryUpload(task.id),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => _queueService.dismissTask(task.id),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.error!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Mini floating button to show queue when minimized
class UploadQueueFloatingButton extends StatelessWidget {
  const UploadQueueFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (((!appState.hasActiveUploads && !appState.hasFailedUploads) ||
                appState.uploadQueueVisible)) {
          return const SizedBox.shrink();
        }

        final outstandingCount = appState.uploadTasks
            .where((task) =>
                task.status == UploadStatus.uploading ||
                task.status == UploadStatus.pending ||
                task.status == UploadStatus.failed)
            .length;

        return Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: () => appState.showUploadQueue(),
            backgroundColor: const Color(0xFF1976D2),
            child: Stack(
              children: [
                const Icon(Icons.cloud_upload, size: 20),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '$outstandingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
