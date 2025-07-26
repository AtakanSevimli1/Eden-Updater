import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/command_line_parser.dart';
import 'core/services/service_locator.dart';
import 'screens/updater_screen.dart';

void main(List<String> args) {
  // Initialize services
  ServiceLocator.initialize();
  
  final parser = CommandLineParser(args);
  
  runApp(EdenUpdaterApp(
    isAutoLaunch: parser.isAutoLaunch,
    channel: parser.channel,
  ));
}

class EdenUpdaterApp extends StatelessWidget {
  final bool isAutoLaunch;
  final String? channel;
  
  const EdenUpdaterApp({
    super.key,
    this.isAutoLaunch = false,
    this.channel,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eden Updater',
      theme: AppTheme.darkTheme,
      home: UpdaterScreen(
        isAutoLaunch: isAutoLaunch,
        channel: channel,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
