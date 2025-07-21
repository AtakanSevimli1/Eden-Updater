import 'package:flutter/material.dart';
import '../../models/update_info.dart';

/// Widget displaying current and latest version information
class VersionCards extends StatelessWidget {
  final UpdateInfo? currentVersion;
  final UpdateInfo? latestVersion;
  
  const VersionCards({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = latestVersion != null && 
        currentVersion != null && 
        latestVersion!.version != currentVersion!.version;
    
    return Row(
      children: [
        Expanded(
          child: _VersionCard(
            title: 'Current',
            version: currentVersion?.version ?? 'Unknown',
            icon: Icons.phone_android,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _VersionCard(
            title: 'Latest',
            version: latestVersion?.version ?? 'Checking...',
            icon: hasUpdate ? Icons.new_releases : Icons.check_circle,
            color: hasUpdate 
                ? theme.colorScheme.secondary
                : theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String title;
  final String version;
  final IconData icon;
  final Color color;
  
  const _VersionCard({
    required this.title,
    required this.version,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            version,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}