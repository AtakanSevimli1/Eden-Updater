import 'dart:io' as io;

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime releaseDate;
  final int fileSize;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseDate,
    required this.fileSize,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    String downloadUrl = '';
    int fileSize = 0;
    
    final assets = json['assets'] as List<dynamic>? ?? [];
    final platformAsset = _findPlatformAsset(assets);
    
    if (platformAsset != null) {
      downloadUrl = platformAsset['browser_download_url'] as String? ?? '';
      fileSize = platformAsset['size'] as int? ?? 0;
      
      print('Selected asset: ${platformAsset['name']}');
      print('Asset size: ${platformAsset['size']} (${fileSize} bytes)');
      print('Download URL: $downloadUrl');
    }

    return UpdateInfo(
      version: json['tag_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      downloadUrl: downloadUrl,
      releaseNotes: json['body'] as String? ?? '',
      releaseDate: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      fileSize: fileSize,
    );
  }

  static Map<String, dynamic>? _findPlatformAsset(List<dynamic> assets) {
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
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      
      if (name.contains('windows') && name.contains('x86_64') && name.endsWith('.7z')) {
        print('Found nightly Windows build: ${asset['name']}');
        return asset;
      }
      
      if (name.contains('windows') && name.contains('amd64') && name.endsWith('.zip')) {
        print('Found official Windows build: ${asset['name']}');
        return asset;
      }
    }
    
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('windows') && 
          (name.contains('x86_64') || name.contains('amd64')) &&
          (name.endsWith('.7z') || name.endsWith('.zip'))) {
        print('Found Windows x86_64/amd64 build: ${asset['name']}');
        return asset;
      }
    }
    
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('windows') && 
          !name.contains('arm64') && !name.contains('aarch64') &&
          (name.endsWith('.7z') || name.endsWith('.zip'))) {
        print('Found generic Windows build: ${asset['name']}');
        return asset;
      }
    }
    
    print('No suitable Windows build found');
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

  String get formattedFileSize {
    if (fileSize == 0) return 'Unknown size';
    
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize.toDouble();
    int unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  String get formattedReleaseDate {
    final now = DateTime.now();
    final difference = now.difference(releaseDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Recently';
    }
  }
}