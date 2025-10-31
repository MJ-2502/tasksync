import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'themes/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_navigation.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        // Provide AuthService as a regular Provider (not ChangeNotifier)
        Provider(create: (_) => AuthService()),
        
        // ThemeProvider as ChangeNotifier
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        // Stream provider for Firebase Auth state
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: const TaskSyncApp(),
    ),
  );
}

class TaskSyncApp extends StatelessWidget {
  const TaskSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'TaskSync',
          debugShowCheckedModeBanner: false,
          
          // Apply themes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();

    if (user != null) {
      // Logged in → go to MainNavigation (with Home, Calendar, Profile)
      return const MainNavigation();
    } else {
      // Not logged in → go to Login
      return const LoginScreen();
    }
  }
}