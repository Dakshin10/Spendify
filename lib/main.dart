import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'wrappers/auth_wrapper.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("Failed to warm up SharedPreferences: $e");
  }

  runApp(const SpendifyApp());
}

class SpendifyApp extends StatelessWidget {
  const SpendifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Spendify',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: AppState.instance.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
