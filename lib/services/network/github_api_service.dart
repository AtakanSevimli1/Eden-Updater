import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../models/update_info.dart';

/// Service for interacting with GitHub API
class GitHubApiService {
  /// Fetch the latest release information from GitHub
  Future<UpdateInfo> getLatestRelease(String channel) async {
    final apiUrl = channel == AppConstants.nightlyChannel 
        ? AppConstants.nightlyApiUrl 
        : AppConstants.stableApiUrl;
    
    Exception? lastException;
    
    for (int attempt = 1; attempt <= AppConstants.maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(apiUrl),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ).timeout(AppConstants.requestTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return UpdateInfo.fromJson(data);
        } else {
          throw NetworkException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
            'Failed to fetch release from $apiUrl'
          );
        }
      } catch (e) {
        lastException = NetworkException('Attempt $attempt failed', e.toString());
        
        if (attempt < AppConstants.maxRetries) {
          await Future.delayed(AppConstants.retryDelay);
        }
      }
    }
    
    throw NetworkException(
      'Failed to fetch latest release after ${AppConstants.maxRetries} attempts',
      lastException?.toString()
    );
  }
}