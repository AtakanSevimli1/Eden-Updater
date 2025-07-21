import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../models/update_info.dart';

class UpdaterScreen extends StatefulWidget {
  final bool isAutoLaunch;
  final String? channel;
  
  const UpdaterScreen({
    super.key,
    this.isAutoLaunch = false,
    this.channel,
  });

  @override
  State<UpdaterScreen> createState() => _UpdaterScreenState();
}

class _UpdaterScreenState extends State<UpdaterScreen> {
  final UpdateService _updateService = UpdateService();
  UpdateInfo? _currentVersion;
  UpdateInfo? _latestVersion;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Ready to check for updates';
  String _releaseChannel = UpdateService.stableChannel;
  bool _autoLaunchInProgress = false;
  bool _createShortcuts = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Set channel if provided via command line
    if (widget.channel != null) {
      await _updateService.setReleaseChannel(widget.channel!);
    }
    
    await _loadCurrentVersion();
    await _loadReleaseChannel();
    
    if (widget.isAutoLaunch) {
      _autoLaunchInProgress = true;
      await _autoLaunchSequence();
    } else {
      _checkForUpdates();
    }
  }

  Future<void> _autoLaunchSequence() async {
    setState(() {
      _statusMessage = 'Auto-launching Eden...';
    });
    
    // Check for updates
    await _checkForUpdates();
    
    // If update is available, download it automatically
    if (_latestVersion != null && 
        _currentVersion != null && 
        _latestVersion!.version != _currentVersion!.version) {
      setState(() {
        _statusMessage = 'Update found, downloading automatically...';
      });
      await _downloadUpdate();
    }
    
    // Launch Eden
    await Future.delayed(Duration(milliseconds: 500));
    await _launchEden();
  }

  Future<void> _loadCurrentVersion() async {
    final current = await _updateService.getCurrentVersion();
    setState(() {
      _currentVersion = current;
    });
  }

  Future<void> _loadReleaseChannel() async {
    final channel = await _updateService.getReleaseChannel();
    final createShortcuts = await _updateService.getCreateShortcutsPreference();
    setState(() {
      _releaseChannel = channel;
      _createShortcuts = createShortcuts;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking for updates...';
    });

    try {
      final latest = await _checkForUpdatesWithRetry();
      setState(() {
        _latestVersion = latest;
        _isChecking = false;
        if (_currentVersion?.version == 'Not installed') {
          _statusMessage = 'Ready to install Eden ${latest.version}';
        } else if (_currentVersion != null && latest.version != _currentVersion!.version) {
          _statusMessage = 'Update available: ${latest.version}';
        } else {
          _statusMessage = 'Eden is up to date';
        }
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
        _statusMessage = 'Failed to check for updates: $e';
      });
    }
  }

  Future<UpdateInfo> _checkForUpdatesWithRetry() async {
    const int maxRetries = 10;
    const Duration retryDelay = Duration(seconds: 3);
    
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        setState(() {
          _statusMessage = 'Checking for updates (attempt $attempt/$maxRetries)...';
        });
        
        final latest = await _updateService.getLatestVersion(channel: _releaseChannel);
        return latest;
      } catch (e) {
        lastException = Exception('Attempt $attempt failed: $e');
        print('Update check failed (attempt $attempt/$maxRetries): $e');
        
        if (attempt < maxRetries) {
          setState(() {
            _statusMessage = 'Update check failed, retrying in ${retryDelay.inSeconds} seconds... ($attempt/$maxRetries)';
          });
          await Future.delayed(retryDelay);
        }
      }
    }
    
    throw Exception('Failed to check for updates after $maxRetries attempts. Last error: $lastException');
  }

  Future<void> _changeReleaseChannel(String newChannel) async {
    await _updateService.setReleaseChannel(newChannel);
    setState(() {
      _releaseChannel = newChannel;
      _latestVersion = null;
      _statusMessage = 'Release channel changed to ${newChannel == UpdateService.nightlyChannel ? 'Nightly' : 'Stable'}';
    });
    
    await _loadCurrentVersion();
  }

  Future<void> _downloadUpdate() async {
    if (_latestVersion == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
    });

    try {
      await _updateService.downloadUpdate(
        _latestVersion!,
        createShortcuts: _createShortcuts,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onStatusUpdate: (status) {
          setState(() {
            _statusMessage = status;
          });
        },
      );

      setState(() {
        _isDownloading = false;
        _statusMessage = 'Installation complete!';
        _currentVersion = _latestVersion;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Installation failed: $e';
      });
    }
  }

  Future<void> _launchEden() async {
    try {
      await _updateService.launchEden();
      if (mounted) {
        if (Platform.isAndroid || Platform.isIOS) {
          SystemNavigator.pop();
        } else {
          exit(0);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to launch Eden: $e';
      });
    }
  }

  Future<void> _openGitHub() async {
    final channel = await _updateService.getReleaseChannel();
    final uri = Uri.parse(channel == UpdateService.nightlyChannel 
        ? 'https://github.com/pflyly/eden-nightly/releases'
        : 'https://github.com/eden-emulator/Releases/releases');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _setTestVersion() async {
    await _updateService.setCurrentVersionForTesting('v1.0.0-test');
    await _loadCurrentVersion();
    setState(() {
      _statusMessage = 'Set test version v1.0.0-test';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotInstalled = _currentVersion?.version == 'Not installed';
    final hasUpdate = _latestVersion != null && 
        _currentVersion != null && 
        _latestVersion!.version != _currentVersion!.version;

    // Show simplified UI during auto-launch
    if (widget.isAutoLaunch && _autoLaunchInProgress) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.background,
                theme.colorScheme.surface,
                theme.colorScheme.primary.withOpacity(0.1),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videogame_asset,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Eden Launcher',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isDownloading) ...[
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(_downloadProgress * 100).toInt()}% Complete',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface,
              theme.colorScheme.primary.withOpacity(0.1),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                Container(
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
                          if (kDebugMode)
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: _setTestVersion,
                                icon: Icon(
                                  Icons.bug_report,
                                  color: theme.colorScheme.tertiary,
                                ),
                                tooltip: 'Set Test Version',
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _openGitHub,
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
                ),
                
                const SizedBox(height: 24),
                
                // Release Channel Selector
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Release Channel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              theme.colorScheme.secondary.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _releaseChannel,
                            isDense: true,
                            items: [
                              DropdownMenuItem(
                                value: UpdateService.stableChannel,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Stable',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: UpdateService.nightlyChannel,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.science,
                                      size: 18,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Nightly',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: _isChecking || _isDownloading 
                                ? null 
                                : (value) {
                                    if (value != null) {
                                      _changeReleaseChannel(value);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.1),
                              theme.colorScheme.primary.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_android,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Current',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentVersion?.version ?? 'Unknown',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              hasUpdate 
                                  ? theme.colorScheme.secondary.withOpacity(0.1)
                                  : theme.colorScheme.tertiary.withOpacity(0.1),
                              hasUpdate 
                                  ? theme.colorScheme.secondary.withOpacity(0.05)
                                  : theme.colorScheme.tertiary.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasUpdate 
                                ? theme.colorScheme.secondary.withOpacity(0.3)
                                : theme.colorScheme.tertiary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasUpdate ? Icons.new_releases : Icons.check_circle,
                                  color: hasUpdate 
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.tertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Latest',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: hasUpdate 
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.tertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _latestVersion?.version ?? 'Checking...',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isDownloading) ...[
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
                              value: _downloadProgress,
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
                          '${(_downloadProgress * 100).toInt()}% Complete',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isChecking)
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          else if (hasUpdate)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.new_releases,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                            )
                          else if (_latestVersion != null)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.tertiary,
                                size: 20,
                              ),
                            ),
                          
                          Flexible(
                            child: Text(
                              _statusMessage,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Expanded(child: SizedBox()),
                
                // Installation Options
                if (isNotInstalled || hasUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Installation Options',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _createShortcuts,
                              onChanged: _isDownloading ? null : (value) async {
                                setState(() {
                                  _createShortcuts = value ?? true;
                                });
                                await _updateService.setCreateShortcutsPreference(_createShortcuts);
                              },
                              activeColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Create desktop shortcut',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Action Buttons - Nintendo Switch Joy-Con style
                if (!_isDownloading) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isChecking
                                    ? [
                                        theme.colorScheme.outline.withOpacity(0.3),
                                        theme.colorScheme.outline.withOpacity(0.2),
                                      ]
                                    : [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.primary.withOpacity(0.8),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _isChecking
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _isChecking ? null : _checkForUpdates,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isChecking)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.refresh,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isChecking ? 'Checking...' : 'Check Updates',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.secondary,
                                  theme.colorScheme.secondary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.secondary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: (isNotInstalled || hasUpdate) 
                                    ? _downloadUpdate 
                                    : _launchEden,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        (isNotInstalled || hasUpdate) 
                                            ? Icons.download 
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isNotInstalled 
                                            ? 'Install Eden'
                                            : hasUpdate 
                                                ? 'Update Eden' 
                                                : 'Launch Eden',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}