import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/update_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(ExpenseTrackerApp(showOnboarding: !onboardingDone));
}

class ExpenseTrackerApp extends StatelessWidget {
  final bool showOnboarding;
  const ExpenseTrackerApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF30437A);
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.light,
        ),
        textTheme: baseTextTheme.copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold, color: brandColor),
          headlineLarge: baseTextTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold, color: brandColor),
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold, color: brandColor),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold, color: brandColor),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600, color: brandColor),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            elevation: 2,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.horizontal(right: Radius.circular(20)),
          ),
        ),
      ),
      // Show onboarding only on first launch; otherwise go straight to
      // the update gate (which handles force-update + backup restore).
      home: showOnboarding
          ? const OnboardingScreen()
          : const UpdateGateScreen(),
    );
  }
}
