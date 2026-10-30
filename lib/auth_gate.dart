import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.firebaseReady, required this.authenticatedBuilder});

  final bool firebaseReady;
  final Widget Function(BuildContext context, User user) authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) return const LoginPage(firebaseReady: false);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage(firebaseReady: true);
        return authenticatedBuilder(context, user);
      },
    );
  }
}
