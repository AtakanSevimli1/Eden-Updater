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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0099FF),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF0066CC),
          onPrimaryContainer: Color(0xFFCCE7FF),
          
          secondary: Color(0xFFFF6B6B),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFCC4444),
          onSecondaryContainer: Color(0xFFFFE6E6),
          
          surface: Color(0xFF1A1A2E),
          onSurface: Color(0xFFEEEEFF),
          surfaceVariant: Color(0xFF16213E),
          onSurfaceVariant: Color(0xFFD4D4FF),
          
          tertiary: Color(0xFF00D4AA),
          onTertiary: Colors.white,
          
          error: Color(0xFFFF5555),
          onError: Colors.white,
          
          background: Color(0xFF0F0F23),
          onBackground: Color(0xFFEEEEFF),
          
          outline: Color(0xFF4A4A6A),
          outlineVariant: Color(0xFF2A2A4A),
        ),
        useMaterial3: true,
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0099FF),
            foregroundColor: Colors.white,
            elevation: 6,
            shadowColor: const Color(0xFF0099FF).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
            elevation: 6,
            shadowColor: const Color(0xFFFF6B6B).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0099FF),
            side: const BorderSide(color: Color(0xFF0099FF), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        cardTheme: const CardThemeData(
          color: Color(0xFF16213E),
          elevation: 8,
          shadowColor: Color(0xFF000033),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          margin: EdgeInsets.all(8),
        ),
        
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF0099FF),
          linearTrackColor: Color(0xFF2A2A4A),
          circularTrackColor: Color(0xFF2A2A4A),
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F23),
          foregroundColor: Color(0xFFEEEEFF),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: UpdaterScreen(
        isAutoLaunch: isAutoLaunch,
        channel: channel,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
