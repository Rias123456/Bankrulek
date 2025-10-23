import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_success_screen.dart';
import 'screens/register_tutor_screen.dart';
import 'screens/tutor_login_screen.dart';
import 'services/tutor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final TutorService tutorService = TutorService();
  runApp(
    MultiProvider(
      providers: [
        Provider<TutorService>.value(value: tutorService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(tutorService: tutorService),
        ),
      ],
      child: const BankrulekApp(),
    ),
  );
}

/// แอปหลักของโครงการ / Root widget of the project
class BankrulekApp extends StatelessWidget {
  const BankrulekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bankrulek Tutor Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFFFE4E1),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => const HomeScreen(),
        '/tutor-login': (BuildContext context) => const TutorLoginScreen(),
        '/register-tutor': (BuildContext context) => const RegisterTutorScreen(),
        '/admin-login': (BuildContext context) => const AdminLoginScreen(),
        '/admin-dashboard': (BuildContext context) => const AdminDashboardScreen(),
        '/login-success': (BuildContext context) => const LoginSuccessScreen(),
      },
    );
  }
}
