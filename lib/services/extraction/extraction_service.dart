import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/file_utils.dart';

/// Service for extracting archive files
class ExtractionService {
  /// Extract an archive file to a destination directory
  Future<void> extractArchive(
    String archivePath,
    String destinationPath, {
    Function(double)? onProgress,
  }) async {
    final file = File(archivePath);
    final bytes = await file.readAsBytes();
    
    Archive archive;
    if (archivePath.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (archivePath.endsWith('.tar.gz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else if (archivePath.endsWith('.7z')) {
      await _extract7z(archivePath, destinationPath, onProgress: onProgress);
      return;
    } else {
      throw ExtractionException(
        'Unsupported archive format',
        path.extension(archivePath)
      );
    }

    int extractedFiles = 0;
    final totalFiles = archive.files.where((f) => f.isFile).length;
    
    for (final file in archive) {
      if (file.isFile) {
        final data = file.content as List<int>;
        final extractPath = path.join(destinationPath, file.name);
        
        await Directory(path.dirname(extractPath)).create(recursive: true);
        await File(extractPath).writeAsBytes(data);
        extractedFiles++;
        
        if (onProgress != null && totalFiles > 0) {
          onProgress(extractedFiles / totalFiles);
        }
        
        // Make executable if it's an Eden executable on Linux
        if (Platform.isLinux && FileUtils.isEdenExecutable(file.name)) {
          await Process.run('chmod', ['+x', extractPath]);
        }
      }
    }

    await file.delete();
  }

  /// Extract 7z archives using system 7z command
  Future<void> _extract7z(
    String archivePath,
    String destinationPath, {
    Function(double)? onProgress,
  }) async {
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
          try {
            result = await Process.run(szPath, ['--help'], runInShell: true);
            if (result.exitCode == 0) {
              workingPath = szPath;
              break;
            }
          } catch (e) {
            continue;
          }
        }
        
        if (workingPath != null) {
          result = await Process.run(
            workingPath,
            ['x', archivePath, '-o$destinationPath', '-y'],
            runInShell: true,
          );
          
          if (result.exitCode == 0) {
            onProgress?.call(1.0);
            return;
          }
        }
      } else {
        result = await Process.run('7z', ['x', archivePath, '-o$destinationPath', '-y']);
        if (result.exitCode == 0) {
          onProgress?.call(1.0);
          return;
        }
      }
    } catch (e) {
      // Fall through to throw exception
    }

    throw ExtractionException(
      '7z extraction failed',
      'Please install 7-Zip:\n'
      'Windows: Download from https://www.7-zip.org/\n'
      'Linux: sudo apt install p7zip-full'
    );
  }
}