import 'package:flutter/material.dart';
import 'screens/updater_screen.dart';

void main(List<String> args) {
  final isAutoLaunch = args.contains('--auto-launch');
  String? channel;
  
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--channel' && i + 1 < args.length) {
      channel = args[i + 1];
      break;
    }
  }
  
  runApp(EdenUpdaterApp(
    isAutoLaunch: isAutoLaunch,
    channel: channel,
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: UpdaterScreen(
        isAutoLaunch: isAutoLaunch,
        channel: channel,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
