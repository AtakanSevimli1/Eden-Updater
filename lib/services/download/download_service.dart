import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../core/errors/app_exceptions.dart';
import '../../models/update_info.dart';

/// Service for downloading files
class DownloadService {
  /// Download a file with progress tracking
  Future<String> downloadFile(
    UpdateInfo updateInfo,
    String downloadPath, {
    required Function(double) onProgress,
    required Function(String) onStatusUpdate,
  }) async {
    final fileName = path.basename(Uri.parse(updateInfo.downloadUrl).path);
    final filePath = path.join(downloadPath, fileName);

    final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw NetworkException(
        'Failed to download file',
        'HTTP ${response.statusCode} from ${updateInfo.downloadUrl}'
      );
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
          onProgress(downloadProgress);
          onStatusUpdate('Downloading... ${(downloadProgress * 100).toInt()}%');
        }
      }
      
      await sink.close();
      return filePath;
      
    } catch (error) {
      await sink.close();
      throw FileException('Download failed', error.toString());
    }
  }
}