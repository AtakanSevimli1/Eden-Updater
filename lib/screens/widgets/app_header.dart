import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

/// Header widget for the updater screen
class AppHeader extends StatelessWidget {
  final String releaseChannel;
  final VoidCallback? onTestVersion;
  
  const AppHeader({
    super.key,
    required this.releaseChannel,
    this.onTestVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.videogame_asset,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eden Updater',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep your Eden emulator up to date',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (kDebugMode && onTestVersion != null)
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: onTestVersion,
                    icon: Icon(
                      Icons.bug_report,
                      color: theme.colorScheme.tertiary,
                    ),
                    tooltip: 'Set Test Version',
                  ),
                ),
              if (kDebugMode && onTestVersion != null) const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _openGitHub(releaseChannel),
                  icon: Icon(
                    Icons.open_in_new,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Open GitHub',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _openGitHub(String channel) async {
    final uri = Uri.parse(channel == AppConstants.nightlyChannel 
        ? 'https://github.com/pflyly/eden-nightly/releases'
        : 'https://github.com/eden-emulator/Releases/releases');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}