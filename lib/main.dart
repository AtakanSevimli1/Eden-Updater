import 'package:flutter/material.dart';
import 'screens/updater_screen.dart';

void main() {
  runApp(const EdenUpdaterApp());
}

class EdenUpdaterApp extends StatelessWidget {
  const EdenUpdaterApp({super.key});

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
      home: const UpdaterScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
