import 'package:flutter/material.dart';
import 'app_drawer.dart';

class FieldShellScaffold extends StatelessWidget {
  final Widget child;

  const FieldShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),          // your role-aware drawer
      body: Row(
        children: [
          // For wide screens, you might want AppDrawer-as-rail instead.
          Expanded(child: child),
        ],
      ),
    );
  }
}

class AdminShellScaffold extends StatelessWidget {
  final Widget child;

  const AdminShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // You can either reuse AppDrawer, or make a special AdminDrawer.
      drawer: const AppDrawer(
        companySubtitle: 'Admin Console',
      ),
      body: Row(
        children: [
          Expanded(child: child),
        ],
      ),
    );
  }
}
