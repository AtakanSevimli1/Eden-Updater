import 'dart:io';
import 'package:path/path.dart' as path;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/file_utils.dart';
import '../models/update_info.dart';
import 'network/github_api_service.dart';
import 'storage/preferences_service.dart';
import 'download/download_service.dart';
import 'extraction/extraction_service.dart';
import 'installation/installation_service.dart';
import 'launcher/launcher_service.dart';

/// Main service for managing Eden updates
class UpdateService {
  final GitHubApiService _githubService;
  final PreferencesService _preferencesService;
  final DownloadService _downloadService;
  final ExtractionService _extractionService;
  final InstallationService _installationService;
  final LauncherService _launcherService;
  
  // Session cache for latest versions to avoid redundant API calls
  final Map<String, UpdateInfo> _sessionCache = {};
  
  /// Default constructor (creates all dependencies)
  UpdateService()
      : _githubService = GitHubApiService(),
        _preferencesService = PreferencesService(),
        _downloadService = DownloadService(),
        _extractionService = ExtractionService(),
        _installationService = InstallationService(PreferencesService()),
        _launcherService = LauncherService(PreferencesService(), InstallationService(PreferencesService()));
  
  /// Constructor with dependency injection (for better testing and service locator)
  UpdateService.withServices(
    this._githubService,
    this._preferencesService,
    this._downloadService,
    this._extractionService,
    this._installationService,
    this._launcherService,
  );

  // Channel management
  Future<String> getReleaseChannel() => _preferencesService.getReleaseChannel();
  Future<void> setReleaseChannel(String channel) => _preferencesService.setReleaseChannel(channel);
  
  // Shortcuts preference
  Future<bool> getCreateShortcutsPreference() => _preferencesService.getCreateShortcutsPreference();
  Future<void> setCreateShortcutsPreference(bool value) => _preferencesService.setCreateShortcutsPreference(value);
  
  // Portable mode preference
  Future<bool> getPortableModePreference() => _preferencesService.getPortableModePreference();
  Future<void> setPortableModePreference(bool value) => _preferencesService.setPortableModePreference(value);
  Future<void> clearPortableModePreference() => _preferencesService.clearPortableModePreference();
  
  // Cache management
  void clearSessionCache() => _sessionCache.clear();
  void clearChannelCache(String channel) => _sessionCache.remove(channel);

  /// Get the current installed version
  Future<UpdateInfo?> getCurrentVersion() async {
    final channel = await getReleaseChannel();
    final versionString = await _preferencesService.getCurrentVersion(channel);
    
    if (versionString != null) {
      final storedExecutablePath = await _preferencesService.getEdenExecutablePath(channel);
      if (storedExecutablePath != null && await File(storedExecutablePath).exists()) {
        return UpdateInfo(
          version: versionString,
          downloadUrl: '',
          releaseNotes: '',
          releaseDate: DateTime.now(),
          fileSize: 0,
        );
      } else {
        await _preferencesService.clearVersionInfo(channel);
      }
    }
    
    // Try to detect version from executable
    try {
      final installPath = await _installationService.getInstallPath();
      final edenExecutable = FileUtils.getEdenExecutablePath(installPath);
      
      if (await File(edenExecutable).exists()) {
        final result = await Process.run(edenExecutable, ['--version']);
        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          await _preferencesService.setCurrentVersion(channel, version);
          return UpdateInfo(
            version: version,
            downloadUrl: '',
            releaseNotes: '',
            releaseDate: DateTime.now(),
            fileSize: 0,
          );
        }
      }
    } catch (e) {
      // Continue to return 'Not installed'
    }
    
    return UpdateInfo(
      version: 'Not installed',
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
    );
  }

  /// Get the latest version from GitHub
  Future<UpdateInfo> getLatestVersion({String? channel, bool forceRefresh = false}) async {
    final releaseChannel = channel ?? await getReleaseChannel();
    
    // Check session cache first unless force refresh is requested
    if (!forceRefresh && _sessionCache.containsKey(releaseChannel)) {
      return _sessionCache[releaseChannel]!;
    }
    
    // Fetch from API and cache the result
    final updateInfo = await _githubService.getLatestRelease(releaseChannel);
    _sessionCache[releaseChannel] = updateInfo;
    
    return updateInfo;
  }

  /// Download and install an update
  Future<void> downloadUpdate(
    UpdateInfo updateInfo, {
    bool createShortcuts = true,
    bool portableMode = false,
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    Directory? tempDir;
    String? downloadedFilePath;
    
    try {
      final installPath = await _installationService.getInstallPath();
      
      // Create temporary directory for download
      tempDir = await Directory.systemTemp.createTemp('eden_updater_');
      onStatusUpdate('Preparing download...');

      // Download the file to temp directory
      onStatusUpdate('Starting download...');
      downloadedFilePath = await _downloadService.downloadFile(
        updateInfo,
        tempDir.path,
        onProgress: (progress) => onProgress(progress * 0.5),
        onStatusUpdate: onStatusUpdate,
      );

      // Extract the archive to temp directory first
      onStatusUpdate('Extracting archive...');
      final extractTempDir = await Directory.systemTemp.createTemp('eden_extract_');
      
      await _extractionService.extractArchive(
        downloadedFilePath,
        extractTempDir.path,
        onProgress: (progress) {
          onProgress(0.5 + (progress * 0.3));
          onStatusUpdate('Extracting... ${(progress * 100).toInt()}%');
        },
      );

      // Move extracted files to final location
      onStatusUpdate('Installing files...');
      await _moveExtractedFiles(extractTempDir.path, installPath);
      
      // Organize the installation
      onStatusUpdate('Organizing installation...');
      await _installationService.organizeInstallation(installPath);
      onProgress(0.9);

      // Update version info
      final channel = await getReleaseChannel();
      await _preferencesService.setCurrentVersion(channel, updateInfo.version);

      // Create user folder for portable mode in the channel-specific folder
      if (portableMode) {
        onStatusUpdate('Setting up portable mode...');
        final channelInstallPath = await _installationService.getChannelInstallPath();
        final userPath = path.join(channelInstallPath, 'user');
        await Directory(userPath).create(recursive: true);
      }

      // Create shortcut if requested
      if (createShortcuts) {
        try {
          await _launcherService.createDesktopShortcut();
        } catch (e) {
          // Don't fail the entire update if shortcut creation fails
        }
      }

      onProgress(1.0);
      onStatusUpdate('Installation complete!');
      
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw UpdateException('Update failed', e.toString());
    } finally {
      // Clean up temporary files and directories
      await _cleanupTempFiles(tempDir, downloadedFilePath);
    }
  }
  
  /// Move extracted files from temp directory to install directory
  Future<void> _moveExtractedFiles(String extractPath, String installPath) async {
    final extractDir = Directory(extractPath);
    
    await for (final entity in extractDir.list()) {
      final targetPath = path.join(installPath, path.basename(entity.path));
      
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await FileUtils.copyDirectory(entity.path, targetPath);
      }
    }
  }
  
  /// Clean up temporary files and directories
  Future<void> _cleanupTempFiles(Directory? tempDir, String? downloadedFilePath) async {
    try {
      // Delete downloaded file if it exists
      if (downloadedFilePath != null) {
        final file = File(downloadedFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Delete temporary directories
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      
      // Clean up any other temp directories we might have created
      final systemTempDir = Directory.systemTemp;
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = path.basename(entity.path);
          if (name.startsWith('eden_updater_') || name.startsWith('eden_extract_')) {
            try {
              await entity.delete(recursive: true);
            } catch (e) {
              // Ignore cleanup failures for other temp directories
            }
          }
        }
      }
    } catch (e) {
      // Don't fail the entire update if cleanup fails
      // Just log the error (in a real app, you might want to log this)
    }
  }

  /// Launch Eden emulator
  Future<void> launchEden() => _launcherService.launchEden();

  /// Get install path
  Future<String> getInstallPath() => _installationService.getInstallPath();
  
  /// Set install path
  Future<void> setInstallPath(String newPath) => _preferencesService.setInstallPath(newPath);

  /// Debug method to manually set version for testing
  Future<void> setCurrentVersionForTesting(String version) async {
    final channel = await getReleaseChannel();
    await _preferencesService.setCurrentVersion(channel, version);
  }

  // Constants for backward compatibility
  static const String stableChannel = AppConstants.stableChannel;
  static const String nightlyChannel = AppConstants.nightlyChannel;
}