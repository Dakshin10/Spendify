import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/state/app_state.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/onboarding_wizard_screen.dart';
import '../screens/profile/personal_details_screen.dart';
import '../screens/main/main_navigation_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // USER LOGGED IN
        if (snapshot.hasData) {
          return AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) {
              if (!AppState.instance.isProfileSetup) {
                return const PersonalDetailsScreen();
              } else if (!AppState.instance.isOnboarded) {
                return const OnboardingWizardScreen();
              } else {
                return const MainNavigationScreen();
              }
            },
          );
        }

        // USER NOT LOGGED IN - Show onboarding
        return const OnboardingScreen();
      },
    );
  }
}