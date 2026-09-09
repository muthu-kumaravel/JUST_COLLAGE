import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/apple_photos_theme.dart';
import 'ui/collage_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const JustCollageApp());
}

class JustCollageApp extends StatelessWidget {
  const JustCollageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Just Collage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ApplePhotosTheme.obsidianBlack,
        colorScheme: const ColorScheme.dark(
          primary: ApplePhotosTheme.appleGold,
          onPrimary: Colors.black,
          surface: Color(0xFF161618),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const CollageScreen(),
    );
  }
}
