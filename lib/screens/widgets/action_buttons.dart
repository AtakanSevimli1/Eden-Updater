import 'package:flutter/material.dart';
import '../../models/update_info.dart';

/// Widget containing action buttons for the updater
class ActionButtons extends StatelessWidget {
  final UpdateInfo? currentVersion;
  final UpdateInfo? latestVersion;
  final bool isChecking;
  final bool isDownloading;
  final bool createShortcuts;
  final bool portableMode;
  final Function(bool forceRefresh) onCheckForUpdates;
  final VoidCallback onDownloadUpdate;
  final VoidCallback onLaunchEden;
  final ValueChanged<bool?> onCreateShortcutsChanged;
  final ValueChanged<bool?> onPortableModeChanged;
  
  const ActionButtons({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.isChecking,
    required this.isDownloading,
    required this.createShortcuts,
    required this.portableMode,
    required this.onCheckForUpdates,
    required this.onDownloadUpdate,
    required this.onLaunchEden,
    required this.onCreateShortcutsChanged,
    required this.onPortableModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotInstalled = currentVersion?.version == 'Not installed';
    final hasUpdate = latestVersion != null && 
        currentVersion != null && 
        latestVersion!.version != currentVersion!.version;
    
    return Column(
      children: [
        // Shortcut checkbox
        Row(
          children: [
            Checkbox(
              value: createShortcuts,
              onChanged: isDownloading ? null : onCreateShortcutsChanged,
              activeColor: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Create desktop shortcut',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Portable mode checkbox
        Row(
          children: [
            Checkbox(
              value: portableMode,
              onChanged: isDownloading ? null : onPortableModeChanged,
              activeColor: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Portable mode (keep user data in installation folder)',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Action buttons - hide during installation
        if (!isDownloading) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isChecking ? null : () => onCheckForUpdates(true),
                  icon: isChecking 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isChecking ? 'Checking...' : 'Check for Updates'),
                ),
              ),
              const SizedBox(width: 12),
              if (isNotInstalled || hasUpdate) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isChecking || latestVersion == null 
                        ? null 
                        : onDownloadUpdate,
                    icon: const Icon(Icons.download),
                    label: Text(isNotInstalled ? 'Install Eden' : 'Update Eden'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isChecking ? null : onLaunchEden,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Launch Eden'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}