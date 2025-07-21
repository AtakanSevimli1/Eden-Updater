import 'package:flutter/material.dart';

/// Widget for displaying download progress
class DownloadProgress extends StatelessWidget {
  final double progress;
  final String statusMessage;
  
  const DownloadProgress({
    super.key,
    required this.progress,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.download,
              color: theme.colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Downloading Update',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                theme.colorScheme.secondary.withOpacity(0.1),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.secondary,
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${(progress * 100).toInt()}% Complete',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}