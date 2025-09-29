// lib/analytics_screen.dart

import 'package:flutter/material.dart';
// NOTE: AppDrawer import is now unnecessary since the drawer is removed from this screen
// import 'package:time_tracker_pro/dashboard_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // DELETED: appBar property (removes title)
      // DELETED: drawer property (removes the Hamburger Menu icon that linked to the drawer)

      body: Center(
        child: Text('Analytics Content Here'),
      ),
    );
  }
}