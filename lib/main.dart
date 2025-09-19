// lib/main.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/dashboard_screen.dart';
import 'package:time_tracker_pro/settings_screen.dart';
import 'package:time_tracker_pro/settings_service.dart';

void main() {
  runApp(const TrialApp());
}

class TrialApp extends StatelessWidget {
  const TrialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UI Trial 2',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[350],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: SettingsService().hasSettings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!) {
            return const DashboardScreen();
          } else {
            return const SettingsScreen();
          }
        },
      ),
    );
  }
}