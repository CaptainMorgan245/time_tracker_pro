// lib/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:time_tracker_pro/dashboard_screen.dart'; // Import AppDrawer helper

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      drawer: const AppDrawer(), // ADDED: Use reusable AppDrawer
      body: const Center(
        child: Text('Analytics Content Here'),
      ),
    );
  }
}
