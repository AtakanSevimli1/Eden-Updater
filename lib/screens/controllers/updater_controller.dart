import 'dart:io';
import 'package:flutter/services.dart';
import '../../services/update_service.dart';
import '../state/updater_state.dart';

/// Controller for managing updater operations and business logic
class UpdaterController {
  final UpdateService _updateService = UpdateService();
  final VoidCallback onStateChanged;
  
  UpdaterState _state = UpdaterState();
  UpdaterState get state => _state;
  
  UpdaterController({required this.onStateChanged});
  
  /// Initialize the controller with optional channel
  Future<void> initialize({String? channel}) async {
    if (channel != null) {
      await _updateService.setReleaseChannel(channel);
    }
    
    await _loadCurrentVersion();
    await _loadSettings();
  }
  
  /// Load current version information
  Future<void> _loadCurrentVersion() async {
    final current = await _updateService.getCurrentVersion();
    _updateState(_state.copyWith(currentVersion: current));
  }
  
  /// Load user settings
  Future<void> _loadSettings() async {
    final channel = await _updateService.getReleaseChannel();
    final createShortcuts = await _updateService.getCreateShortcutsPreference();
    // Always set portable mode to false on startup (don't persist this setting)
    
    _updateState(_state.copyWith(
      releaseChannel: channel,
      createShortcuts: createShortcuts,
      portableMode: false, // Always unchecked on boot
    ));
  }
  
  /// Check for updates
  Future<void> checkForUpdates({bool forceRefresh = false}) async {
    _updateState(_state.copyWith(isChecking: true));
    
    try {
      final latest = await _updateService.getLatestVersion(
        channel: _state.releaseChannel,
        forceRefresh: forceRefresh,
      );
      _updateState(_state.copyWith(
        latestVersion: latest,
        isChecking: false,
      ));
    } catch (e) {
      _updateState(_state.copyWith(isChecking: false));
      rethrow; // Let the UI handle the error display
    }
  }
  
  /// Change release channel
  Future<void> changeReleaseChannel(String newChannel) async {
    await _updateService.setReleaseChannel(newChannel);
    _updateState(_state.copyWith(
      releaseChannel: newChannel,
      latestVersion: null,
    ));
    
    await _loadCurrentVersion();
    await checkForUpdates(forceRefresh: false);
  }
  
  /// Download and install update
  Future<void> downloadUpdate() async {
    if (_state.latestVersion == null) return;
    
    _updateState(_state.copyWith(
      isDownloading: true,
      downloadProgress: 0.0,
    ));
    
    try {
      await _updateService.downloadUpdate(
        _state.latestVersion!,
        createShortcuts: _state.createShortcuts,
        portableMode: _state.portableMode,
        onProgress: (progress) {
          _updateState(_state.copyWith(downloadProgress: progress));
        },
        onStatusUpdate: (status) {
          // Status updates can be handled by the UI if needed
        },
      );
      
      _updateState(_state.copyWith(
        isDownloading: false,
        currentVersion: _state.latestVersion,
      ));
    } catch (e) {
      _updateState(_state.copyWith(isDownloading: false));
      rethrow;
    }
  }
  
  /// Launch Eden emulator
  Future<void> launchEden() async {
    await _updateService.launchEden();
    
    // Exit the app after launching Eden
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }
  
  /// Update create shortcuts preference
  Future<void> updateCreateShortcuts(bool value) async {
    await _updateService.setCreateShortcutsPreference(value);
    _updateState(_state.copyWith(createShortcuts: value));
  }
  
  /// Update portable mode preference (session-only, not persisted)
  Future<void> updatePortableMode(bool value) async {
    // Don't persist portable mode setting - it should always be unchecked on boot
    // await _updateService.setPortableModePreference(value);
    _updateState(_state.copyWith(portableMode: value));
  }
  
  /// Set test version (for debugging)
  Future<void> setTestVersion(String version) async {
    await _updateService.setCurrentVersionForTesting(version);
    await _loadCurrentVersion();
  }
  
  /// Perform auto-launch sequence
  Future<void> performAutoLaunchSequence() async {
    _updateState(_state.copyWith(autoLaunchInProgress: true));
    
    // Check for updates
    await checkForUpdates(forceRefresh: false);
    
    // Download update if available
    if (_state.hasUpdate) {
      await downloadUpdate();
    }
    
    // Launch Eden after a brief delay
    await Future.delayed(const Duration(milliseconds: 500));
    await launchEden();
  }
  
  /// Update state and notify listeners
  void _updateState(UpdaterState newState) {
    _state = newState;
    onStateChanged();
  }
}