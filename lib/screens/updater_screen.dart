import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../models/update_info.dart';

class UpdaterScreen extends StatefulWidget {
  const UpdaterScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadReleaseChannel();
  }

  Future<void> _loadCurrentVersion() async {
    final current = await _updateService.getCurrentVersion();
    setState(() {
      _currentVersion = current;
    });
    
    if (current?.version == 'Not installed') {
      _checkForUpdates();
    }
  }

  Future<void> _loadReleaseChannel() async {
    final channel = await _updateService.getReleaseChannel();
    setState(() {
      _releaseChannel = channel;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotInstalled = _currentVersion?.version == 'Not installed';
    final hasUpdate = _latestVersion != null && 
        _currentVersion != null && 
        _latestVersion!.version != _currentVersion!.version;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.videogame_asset,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eden Updater',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Keep your Eden emulator up to date',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openGitHub,
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Open GitHub',
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Release Channel',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
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
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 6),
                                          Text('Stable'),
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
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 6),
                                          Text('Nightly'),
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
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Version',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  _currentVersion?.version ?? 'Unknown',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_latestVersion != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Latest Version',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  Text(
                                    _latestVersion!.version,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: hasUpdate ? theme.colorScheme.primary : null,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        
                        if (hasUpdate) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.new_releases,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'New update available!',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
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
                
                const SizedBox(height: 24),
                
                if (_isDownloading) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(_downloadProgress * 100).toInt()}% Complete',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const Spacer(),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isChecking || _isDownloading ? null : _checkForUpdates,
                        icon: _isChecking 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isDownloading 
                            ? null 
                            : (isNotInstalled || hasUpdate) 
                                ? _downloadUpdate 
                                : _launchEden,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isDownloading 
                                    ? Icons.download 
                                    : (isNotInstalled || hasUpdate) 
                                        ? Icons.download 
                                        : Icons.play_arrow
                              ),
                        label: Text(
                          _isDownloading 
                              ? 'Downloading...' 
                              : isNotInstalled 
                                  ? 'Install Eden'
                                  : hasUpdate 
                                      ? 'Update Eden' 
                                      : 'Launch Eden'
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}