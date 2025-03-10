import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_flutter_web_app/AdminDashboard.dart';
import 'package:my_flutter_web_app/ConsumptionChartPage.dart';
import 'package:my_flutter_web_app/DashboardPage.dart';
import 'package:my_flutter_web_app/LoginPage.dart';
import 'package:my_flutter_web_app/ProfilePage.dart';
import 'package:my_flutter_web_app/RegisterPage.dart';
import 'firebase_options.dart';
import 'package:my_flutter_web_app/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElecTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/profile': (context) => const ProfilePage(),
        '/Chart': (context) => const ConsumptionCalendarPage(),
        '/adminDashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}
