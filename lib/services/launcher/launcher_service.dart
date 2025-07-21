import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:process_run/process_run.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/file_utils.dart';
import '../storage/preferences_service.dart';
import '../installation/installation_service.dart';

/// Service for launching Eden emulator
class LauncherService {
  final PreferencesService _preferencesService;
  final InstallationService _installationService;
  
  LauncherService(this._preferencesService, this._installationService);
  
  /// Launch the Eden emulator
  Future<void> launchEden() async {
    final channel = await _preferencesService.getReleaseChannel();
    String? edenExecutable = await _preferencesService.getEdenExecutablePath(channel);
    
    if (edenExecutable == null || !await File(edenExecutable).exists()) {
      final installPath = await _installationService.getInstallPath();
      edenExecutable = FileUtils.getEdenExecutablePath(installPath);
    }
    
    if (!await File(edenExecutable).exists()) {
      throw LauncherException(
        'Eden is not installed',
        'Please download Eden first before launching'
      );
    }

    try {
      final workingDirectory = path.dirname(edenExecutable);
      
      await Process.start(
        edenExecutable, 
        [], 
        mode: ProcessStartMode.detached,
        workingDirectory: workingDirectory,
      );
    } catch (e) {
      throw LauncherException('Failed to launch Eden', e.toString());
    }
  }
  
  /// Create a desktop shortcut for Eden (Windows only)
  Future<void> createDesktopShortcut() async {
    if (!Platform.isWindows) return;
    
    try {
      final channel = await _preferencesService.getReleaseChannel();
      final channelName = channel == 'nightly' ? 'Nightly' : 'Stable';
      final shortcutName = 'Eden $channelName.lnk';
      
      final edenExecutable = await _preferencesService.getEdenExecutablePath(channel);
      if (edenExecutable == null || !await File(edenExecutable).exists()) {
        throw LauncherException(
          'Eden executable not found',
          'Cannot create shortcut without valid executable'
        );
      }
      
      // Get desktop path
      final result = await Process.run('powershell', [
        '-Command',
        '[Environment]::GetFolderPath("Desktop")'
      ]);
      
      if (result.exitCode != 0) {
        throw LauncherException('Failed to get desktop path', result.stderr.toString());
      }
      
      final desktopPath = result.stdout.toString().trim();
      final shortcutPath = path.join(desktopPath, shortcutName);
      
      // Create PowerShell script to create shortcut
      final powershellScript = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$shortcutPath")
\$Shortcut.TargetPath = "$edenExecutable"
\$Shortcut.WorkingDirectory = "${path.dirname(edenExecutable)}"
\$Shortcut.IconLocation = "$edenExecutable"
\$Shortcut.Description = "Eden $channelName Emulator"
\$Shortcut.Save()
''';
      
      final scriptResult = await Process.run('powershell', [
        '-Command',
        powershellScript
      ]);
      
      if (scriptResult.exitCode != 0) {
        throw LauncherException(
          'Failed to create shortcut',
          scriptResult.stderr.toString()
        );
      }
      
    } catch (e) {
      if (e is LauncherException) rethrow;
      throw LauncherException('Error creating shortcut', e.toString());
    }
  }
}