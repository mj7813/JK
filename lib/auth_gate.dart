import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/Screens/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // This StreamBuilder listens to Supabase's internal session state
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // 1. If there is a session, the user is already logged in
        if (session != null) {
          return const RedirectLogic(); // We will create this below
        }

        // 2. If there is no session, show the Login Page
        return const LoginPage();
      },
    );
  }
}