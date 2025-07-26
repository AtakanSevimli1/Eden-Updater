import 'dart:io' as io;
import 'dart:developer' as developer;
import '../core/utils/file_utils.dart';
import '../core/utils/date_utils.dart';

/// Represents information about an Eden update/release
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;
  final int fileSize;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
    required this.fileSize,
  });

  /// Create UpdateInfo from GitHub API response
  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>? ?? [];
    final platformAsset = PlatformAssetFinder.findAsset(assets);
    
    return UpdateInfo(
      version: _extractVersion(json),
      downloadUrl: platformAsset?['browser_download_url'] as String? ?? '',
      releaseNotes: json['body'] as String? ?? '',
      releaseDate: _parseReleaseDate(json['published_at'] as String?),
      fileSize: platformAsset?['size'] as int? ?? 0,
    );
  }
  
  /// Create a placeholder UpdateInfo for "not installed" state
  factory UpdateInfo.notInstalled() {
    return UpdateInfo(
      version: 'Not installed',
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
    );
  }
  
  /// Create UpdateInfo from stored version data
  factory UpdateInfo.fromStoredVersion(String version) {
    return UpdateInfo(
      version: version,
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
    );
  }
  
  static String _extractVersion(Map<String, dynamic> json) {
    return json['tag_name'] as String? ?? 
           json['name'] as String? ?? 
           'Unknown';
  }
  
  static DateTime _parseReleaseDate(String? dateString) {
    if (dateString == null) return DateTime.now();
    return DateTime.tryParse(dateString) ?? DateTime.now();
  }

  /// Check if this represents an installed version
  bool get isInstalled => version != 'Not installed';
  
  /// Check if this has a valid download URL
  bool get hasDownloadUrl => downloadUrl.isNotEmpty;
  
  /// Check if versions are different (for update comparison)
  bool isDifferentFrom(UpdateInfo? other) {
    if (other == null) return true;
    return version != other.version;
  }

  String get formattedFileSize => FileUtils.formatFileSize(fileSize);

  String get formattedReleaseDate => DateUtils.formatRelativeTime(releaseDate);
}

/// Helper class for finding platform-specific assets
class PlatformAssetFinder {
  static Map<String, dynamic>? findAsset(List<dynamic> assets) {
    if (io.Platform.isWindows) {
      return _findWindowsAsset(assets);
    } else if (io.Platform.isLinux) {
      return _findLinuxAsset(assets);
    } else if (io.Platform.isAndroid) {
      return _findAndroidAsset(assets);
    }
    return null;
  }

  static Map<String, dynamic>? _findWindowsAsset(List<dynamic> assets) {
    // Priority order for Windows assets
    final searchPatterns = [
      (String name) => name.contains('windows') && name.contains('x86_64') && name.endsWith('.7z'),
      (String name) => name.contains('windows') && name.contains('amd64') && name.endsWith('.zip'),
      (String name) => name.contains('windows') && 
                      (name.contains('x86_64') || name.contains('amd64')) &&
                      (name.endsWith('.7z') || name.endsWith('.zip')),
      (String name) => name.contains('windows') && 
                      !name.contains('arm64') && !name.contains('aarch64') &&
                      (name.endsWith('.7z') || name.endsWith('.zip')),
    ];
    
    for (final pattern in searchPatterns) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (pattern(name)) {
          developer.log('Found Windows build: ${asset['name']}', name: 'PlatformAssetFinder');
          return asset;
        }
      }
    }
    
    developer.log('No suitable Windows build found', name: 'PlatformAssetFinder');
    return null;
  }

  static Map<String, dynamic>? _findLinuxAsset(List<dynamic> assets) {
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('appimage') && !name.contains('zsync')) {
        return asset;
      }
      if (name.contains('linux') || name.endsWith('.tar.gz')) {
        return asset;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _findAndroidAsset(List<dynamic> assets) {
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('android') || name.endsWith('.apk')) {
        return asset;
      }
    }
    return null;
  }
}