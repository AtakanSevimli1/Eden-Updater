import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import 'widgets/app_header.dart';
import 'widgets/channel_selector.dart';
import 'widgets/version_cards.dart';
import 'widgets/download_progress.dart';
import 'widgets/action_buttons.dart';

/// Main updater screen with improved modular structure
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
  String _releaseChannel = AppConstants.stableChannel;
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
    await _loadSettings();
    
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
    await Future.delayed(const Duration(milliseconds: 500));
    await _launchEden();
  }

  Future<void> _loadCurrentVersion() async {
    final current = await _updateService.getCurrentVersion();
    setState(() {
      _currentVersion = current;
    });
  }

  Future<void> _loadSettings() async {
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
      final latest = await _updateService.getLatestVersion(channel: _releaseChannel);
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

  Future<void> _changeReleaseChannel(String newChannel) async {
    await _updateService.setReleaseChannel(newChannel);
    setState(() {
      _releaseChannel = newChannel;
      _latestVersion = null;
      _statusMessage = 'Release channel changed to ${newChannel == AppConstants.nightlyChannel ? 'Nightly' : 'Stable'}';
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
        if (Platform.isAndroid) {
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

    // Show simplified UI during auto-launch
    if (widget.isAutoLaunch && _autoLaunchInProgress) {
      return _buildAutoLaunchUI(theme);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
              theme.colorScheme.primary.withValues(alpha: 0.1),
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
                          AppHeader(
                            releaseChannel: _releaseChannel,
                            onTestVersion: _setTestVersion,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          ChannelSelector(
                            selectedChannel: _releaseChannel,
                            isEnabled: !_isChecking && !_isDownloading,
                            onChannelChanged: (value) {
                              if (value != null) {
                                _changeReleaseChannel(value);
                              }
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          VersionCards(
                            currentVersion: _currentVersion,
                            latestVersion: _latestVersion,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                if (_isDownloading) ...[
                                  DownloadProgress(
                                    progress: _downloadProgress,
                                    statusMessage: _statusMessage,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                
                                ActionButtons(
                                  currentVersion: _currentVersion,
                                  latestVersion: _latestVersion,
                                  isChecking: _isChecking,
                                  isDownloading: _isDownloading,
                                  createShortcuts: _createShortcuts,
                                  onCheckForUpdates: _checkForUpdates,
                                  onDownloadUpdate: _downloadUpdate,
                                  onLaunchEden: _launchEden,
                                  onCreateShortcutsChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _createShortcuts = value;
                                      });
                                      _updateService.setCreateShortcutsPreference(value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          Text(
                            _statusMessage,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
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

  Widget _buildAutoLaunchUI(ThemeData theme) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
              theme.colorScheme.primary.withValues(alpha: 0.1),
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}