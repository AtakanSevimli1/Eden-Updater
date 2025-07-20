import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:process_run/process_run.dart';
import 'package:archive/archive.dart';
import '../models/update_info.dart';

class UpdateService {
  static const String _stableApiUrl = 'https://api.github.com/repos/eden-emulator/Releases/releases/latest';
  static const String _nightlyApiUrl = 'https://api.github.com/repos/pflyly/eden-nightly/releases/latest';
  
  static const String _currentVersionKey = 'current_version';
  static const String _installPathKey = 'install_path';
  static const String _releaseChannelKey = 'release_channel';
  static const String _edenExecutableKey = 'eden_executable_path';
  
  static const String stableChannel = 'stable';
  static const String nightlyChannel = 'nightly';

  Future<UpdateInfo?> getCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final channel = await getReleaseChannel();
    final channelVersionKey = '${_currentVersionKey}_$channel';
    final versionString = prefs.getString(channelVersionKey);
    
    if (versionString != null) {
      final storedExecutablePath = await getStoredEdenExecutablePath();
      if (storedExecutablePath != null && await File(storedExecutablePath).exists()) {
        return UpdateInfo(
          version: versionString,
          downloadUrl: '',
          releaseNotes: '',
          releaseDate: DateTime.now(),
          fileSize: 0,
        );
      } else {
        print('Eden executable not found at stored path, clearing version info');
        await _clearStoredVersionInfo();
      }
    }
    
    try {
      final installPath = await getInstallPath();
      final edenExecutable = _getEdenExecutablePath(installPath);
      
      if (await File(edenExecutable).exists()) {
        final result = await Process.run(edenExecutable, ['--version']);
        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          await prefs.setString(_currentVersionKey, version);
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
      print('Error detecting current version: $e');
    }
    
    return UpdateInfo(
      version: 'Not installed',
      downloadUrl: '',
      releaseNotes: '',
      releaseDate: DateTime.now(),
      fileSize: 0,
    );
  }

  Future<UpdateInfo> getLatestVersion({String? channel}) async {
    final releaseChannel = channel ?? await getReleaseChannel();
    final apiUrl = releaseChannel == nightlyChannel ? _nightlyApiUrl : _stableApiUrl;
    
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UpdateInfo.fromJson(data);
      } else {
        throw Exception('Failed to fetch latest version: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String> getReleaseChannel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_releaseChannelKey) ?? stableChannel;
  }

  Future<void> setReleaseChannel(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_releaseChannelKey, channel);
  }

  Future<void> downloadUpdate(
    UpdateInfo updateInfo, {
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    final installPath = await getInstallPath();
    final downloadPath = path.join(installPath, 'downloads');
    await Directory(downloadPath).create(recursive: true);

    final fileName = path.basename(Uri.parse(updateInfo.downloadUrl).path);
    final filePath = path.join(downloadPath, fileName);

    final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Failed to download: ${response.statusCode}');
    }

    final file = File(filePath);
    final sink = file.openWrite();
    
    int downloaded = 0;
    final total = response.contentLength ?? 0;

    try {
      onStatusUpdate('Downloading...');
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          final downloadProgress = downloaded / total;
          onProgress(downloadProgress * 0.5);
          onStatusUpdate('Downloading... ${(downloadProgress * 100).toInt()}%');
        }
      }
      
      await sink.close();
      await Future.delayed(Duration(milliseconds: 100));
      
      print('Download complete, starting extraction...');
      onStatusUpdate('Extracting...');
      
      await _extractAndInstall(
        filePath, 
        installPath,
        onProgress: (extractProgress) {
          onProgress(0.5 + (extractProgress * 0.5));
          onStatusUpdate('Extracting... ${(extractProgress * 100).toInt()}%');
        },
      );
      
      await _updateCurrentVersion(updateInfo.version);
      onStatusUpdate('Installation complete!');
      
    } catch (error) {
      await sink.close();
      throw Exception('Download failed: $error');
    }
  }

  Future<void> _extractAndInstall(
    String archivePath, 
    String installPath, {
    Function(double)? onProgress,
  }) async {
    print('Starting extraction of: $archivePath');
    print('Extracting to: $installPath');
    
    final file = File(archivePath);
    final bytes = await file.readAsBytes();
    print('Archive file size: ${bytes.length} bytes');
    
    Archive archive;
    if (archivePath.endsWith('.zip')) {
      print('Extracting ZIP archive...');
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (archivePath.endsWith('.tar.gz')) {
      print('Extracting TAR.GZ archive...');
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else if (archivePath.endsWith('.7z')) {
      print('Extracting 7Z archive...');
      await _extract7z(archivePath, installPath, onProgress: onProgress);
      return;
    } else {
      throw Exception('Unsupported archive format: ${path.extension(archivePath)}');
    }

    print('Archive contains ${archive.files.length} files');
    int extractedFiles = 0;
    final totalFiles = archive.files.where((f) => f.isFile).length;
    
    for (final file in archive) {
      final filename = file.name;
      print('Processing: $filename (${file.isFile ? 'file' : 'directory'})');
      
      if (file.isFile) {
        final data = file.content as List<int>;
        final extractPath = path.join(installPath, filename);
        
        print('Extracting to: $extractPath');
        
        await Directory(path.dirname(extractPath)).create(recursive: true);
        await File(extractPath).writeAsBytes(data);
        extractedFiles++;
        
        if (onProgress != null && totalFiles > 0) {
          onProgress(extractedFiles / totalFiles);
        }
        
        print('Extracted file: $filename (${data.length} bytes)');
        
        if (_isEdenExecutable(filename)) {
          await _storeEdenExecutablePath(extractPath);
          if (Platform.isLinux || Platform.isMacOS) {
            await Process.run('chmod', ['+x', extractPath]);
            print('Made executable: $extractPath');
          }
        }
      }
    }

    print('Extraction complete: $extractedFiles files extracted');
    await _renameExtractedFolder(installPath);
    await file.delete();
    print('Cleaned up archive file: $archivePath');
  }

  Future<void> _extract7z(String archivePath, String installPath, {Function(double)? onProgress}) async {
    print('Attempting 7z extraction...');
    print('Archive: $archivePath');
    print('Target: $installPath');
    
    try {
      ProcessResult result;
      if (Platform.isWindows) {
        final sevenZipPaths = [
          'C:\\Program Files\\7-Zip\\7z.exe',
          'C:\\Program Files (x86)\\7-Zip\\7z.exe',
          '7z',
        ];
        
        String? workingPath;
        for (final szPath in sevenZipPaths) {
          print('Trying 7z path: $szPath');
          try {
            result = await Process.run(szPath, ['--help'], runInShell: true);
            if (result.exitCode == 0) {
              workingPath = szPath;
              print('Found working 7z at: $szPath');
              break;
            }
          } catch (e) {
            print('Failed to find 7z at $szPath: $e');
            continue;
          }
        }
        
        if (workingPath != null) {
          print('Extracting with command: $workingPath x $archivePath -o$installPath -y');
          result = await Process.run(
            workingPath,
            ['x', archivePath, '-o$installPath', '-y'],
            runInShell: true,
          );
          print('7z extraction result: exit code ${result.exitCode}');
          print('7z stdout: ${result.stdout}');
          print('7z stderr: ${result.stderr}');
          
          if (result.exitCode == 0) {
            print('7z extraction successful!');
            if (onProgress != null) {
              onProgress(1.0);
            }
            await _renameExtractedFolder(installPath);
            return;
          }
        } else {
          print('No working 7z installation found');
        }
      } else {
        print('Trying p7zip extraction...');
        result = await Process.run('7z', ['x', archivePath, '-o$installPath', '-y']);
        print('p7zip result: exit code ${result.exitCode}');
        if (result.exitCode == 0) {
          print('p7zip extraction successful!');
          return;
        }
      }
    } catch (e) {
      print('7z extraction failed with exception: $e');
    }

    throw Exception(
      '7z extraction failed. Please install 7-Zip:\n'
      'Windows: Download from https://www.7-zip.org/\n'
      'Linux: sudo apt install p7zip-full\n'
      'macOS: brew install p7zip'
    );
  }

  Future<void> _updateCurrentVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final channel = await getReleaseChannel();
    final channelVersionKey = '${_currentVersionKey}_$channel';
    await prefs.setString(channelVersionKey, version);
  }

  Future<String> getInstallPath() async {
    final prefs = await SharedPreferences.getInstance();
    String? installPath = prefs.getString(_installPathKey);
    
    if (installPath == null) {
      final appDir = await getApplicationDocumentsDirectory();
      installPath = path.join(appDir.path, 'Eden');
      await prefs.setString(_installPathKey, installPath);
    }
    
    await Directory(installPath).create(recursive: true);
    return installPath;
  }

  Future<String> getChannelInstallPath() async {
    final installPath = await getInstallPath();
    final channel = await getReleaseChannel();
    final channelFolderName = channel == nightlyChannel ? 'Eden-Nightly' : 'Eden-Release';
    return path.join(installPath, channelFolderName);
  }

  String _getEdenExecutablePath(String installPath) {
    if (Platform.isWindows) {
      return path.join(installPath, 'eden.exe');
    } else {
      return path.join(installPath, 'eden');
    }
  }

  Future<void> launchEden() async {
    String? edenExecutable = await getStoredEdenExecutablePath();
    
    if (edenExecutable == null || !await File(edenExecutable).exists()) {
      final installPath = await getInstallPath();
      edenExecutable = _getEdenExecutablePath(installPath);
    }
    
    if (!await File(edenExecutable).exists()) {
      throw Exception('Eden is not installed. Please download it first.');
    }

    try {
      print('Launching Eden from: $edenExecutable');
      await Process.start(edenExecutable, [], mode: ProcessStartMode.detached);
      print('Eden launched successfully');
    } catch (e) {
      throw Exception('Failed to launch Eden: $e');
    }
  }

  Future<void> setInstallPath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installPathKey, newPath);
  }

  bool _isEdenExecutable(String filename) {
    final name = filename.toLowerCase();
    if (Platform.isWindows) {
      return name.endsWith('eden.exe') || (name.contains('eden') && name.endsWith('.exe'));
    } else {
      return name == 'eden' || (name.contains('eden') && !name.contains('.'));
    }
  }

  Future<void> _storeEdenExecutablePath(String executablePath) async {
    final prefs = await SharedPreferences.getInstance();
    final channel = await getReleaseChannel();
    final channelExecKey = '${_edenExecutableKey}_$channel';
    await prefs.setString(channelExecKey, executablePath);
    print('Stored Eden executable path: $executablePath');
  }

  Future<String?> getStoredEdenExecutablePath() async {
    final prefs = await SharedPreferences.getInstance();
    final channel = await getReleaseChannel();
    final channelExecKey = '${_edenExecutableKey}_$channel';
    return prefs.getString(channelExecKey);
  }

  Future<void> _scanAndStoreEdenExecutable(String installPath) async {
    print('Scanning for Eden executable in: $installPath');
    
    await for (final entity in Directory(installPath).list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path);
        if (_isEdenExecutable(filename)) {
          await _storeEdenExecutablePath(entity.path);
          if (Platform.isLinux || Platform.isMacOS) {
            await Process.run('chmod', ['+x', entity.path]);
            print('Made executable: ${entity.path}');
          }
          return;
        }
      }
    }
    
    print('No Eden executable found in extracted files');
  }

  Future<void> _clearStoredVersionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final channel = await getReleaseChannel();
    final channelVersionKey = '${_currentVersionKey}_$channel';
    final channelExecKey = '${_edenExecutableKey}_$channel';
    
    await prefs.remove(channelVersionKey);
    await prefs.remove(channelExecKey);
    
    print('Cleared stored version info for $channel channel');
  }

  Future<void> _renameExtractedFolder(String installPath) async {
    final channel = await getReleaseChannel();
    final targetFolderName = channel == nightlyChannel ? 'Eden-Nightly' : 'Eden-Release';
    final targetPath = path.join(installPath, targetFolderName);
    
    print('Looking for extracted folder to rename to: $targetFolderName');
    
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      print('Removing existing $targetFolderName folder');
      await targetDir.delete(recursive: true);
    }
    
    final installDir = Directory(installPath);
    await for (final entity in installDir.list()) {
      if (entity is Directory) {
        final folderName = path.basename(entity.path);
        
        if (folderName == 'downloads' || 
            folderName == 'Eden-Release' || 
            folderName == 'Eden-Nightly') {
          continue;
        }
        
        if (await _containsEdenFiles(entity.path)) {
          print('Found Eden folder: $folderName, renaming to: $targetFolderName');
          await entity.rename(targetPath);
          await _scanAndStoreEdenExecutable(targetPath);
          return;
        }
      }
    }
    
    print('No suitable folder found to rename to $targetFolderName');
  }

  Future<bool> _containsEdenFiles(String folderPath) async {
    final dir = Directory(folderPath);
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final filename = path.basename(entity.path).toLowerCase();
        
        if (_isEdenExecutable(filename)) {
          return true;
        }
        
        if (filename.contains('eden') || 
            filename.contains('yuzu') ||
            filename.endsWith('.nro') ||
            filename.endsWith('.nsp') ||
            filename.endsWith('.xci')) {
          return true;
        }
      }
    }
    
    return false;
  }
}