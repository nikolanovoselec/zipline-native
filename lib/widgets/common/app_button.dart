import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double? progress;
  final IconData? icon;
  final double height;
  
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.progress,
    this.icon,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          // Progress fill
          if (progress != null && progress! > 0)
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
                  minHeight: height,
                  backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF1976D2).withValues(alpha: 0.25),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isPrimary
                    ? const Color(0xFF1976D2).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isPrimary
                      ? const Color(0xFF1976D2).withValues(alpha: 0.78)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 0.85,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          // Content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(17),
              child: Center(
                child: isLoading && progress == null
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isPrimary
                              ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              color: isPrimary
                                  ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.7),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            progress != null
                                ? '${(progress! * 100).toStringAsFixed(0)}%'
                                : text,
                            style: TextStyle(
                              color: isPrimary
                                  ? const Color(0xFF1976D2).withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}