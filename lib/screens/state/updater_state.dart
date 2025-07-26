import '../../core/constants/app_constants.dart';
import '../../models/update_info.dart';

/// Manages the state of the updater screen
class UpdaterState {
  // Version information
  UpdateInfo? currentVersion;
  UpdateInfo? latestVersion;
  
  // Operation states
  bool isChecking = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  
  // Settings
  String releaseChannel = AppConstants.stableChannel;
  bool createShortcuts = true;
  bool portableMode = false;
  
  // Auto-launch state
  bool autoLaunchInProgress = false;
  
  /// Check if an update is available
  bool get hasUpdate {
    return latestVersion != null && 
           currentVersion != null && 
           latestVersion!.version != currentVersion!.version;
  }
  
  /// Check if Eden is not installed
  bool get isNotInstalled {
    return currentVersion?.version == 'Not installed';
  }
  
  /// Check if any operation is in progress
  bool get isOperationInProgress {
    return isChecking || isDownloading;
  }
  
  /// Create a copy of the state with updated values
  UpdaterState copyWith({
    UpdateInfo? currentVersion,
    UpdateInfo? latestVersion,
    bool? isChecking,
    bool? isDownloading,
    double? downloadProgress,
    String? releaseChannel,
    bool? createShortcuts,
    bool? portableMode,
    bool? autoLaunchInProgress,
  }) {
    return UpdaterState()
      ..currentVersion = currentVersion ?? this.currentVersion
      ..latestVersion = latestVersion ?? this.latestVersion
      ..isChecking = isChecking ?? this.isChecking
      ..isDownloading = isDownloading ?? this.isDownloading
      ..downloadProgress = downloadProgress ?? this.downloadProgress
      ..releaseChannel = releaseChannel ?? this.releaseChannel
      ..createShortcuts = createShortcuts ?? this.createShortcuts
      ..portableMode = portableMode ?? this.portableMode
      ..autoLaunchInProgress = autoLaunchInProgress ?? this.autoLaunchInProgress;
  }
}