import 'package:flutter/material.dart';
import 'package:flutter_application_1/Screens/home_page.dart';
import 'package:flutter_application_1/Screens/login_page.dart';
import 'package:flutter_application_1/screens/signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/Screens/user_page.dart';
import 'package:flutter_application_1/env.dart';
import 'package:flutter_application_1/global/app_state.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState.instance;
  await appState.loadInitialData();

  await Supabase.initialize(
    url: Env.baseUrl,
    anonKey: Env.apiKey,
  );

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const RentalManagerApp(),
      )
  );
}

class RentalManagerApp extends StatelessWidget {
  const RentalManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JK Properties',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
        brightness: Brightness.light,
      ),
      // We remove initialRoute and use 'home' to handle the Auth logic
      home: const AuthGate(), 
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/user': (context) => const UserPage(),
      },
    );
  }
}

// 2. New AuthGate Widget (The Brain)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // This listener reacts whenever the user logs in or out
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // If there is an active session, skip login and go to role-check logic
        if (session != null) {
          return const SessionRedirector();
        }

        // If no session exists, show the original Welcome Screen
        return const WelcomeScreen();
      },
    );
  }
}

// 3. New Helper to handle Admin/User redirection for persisted sessions
class SessionRedirector extends StatefulWidget {
  const SessionRedirector({super.key});

  @override
  State<SessionRedirector> createState() => _SessionRedirectorState();
}

class _SessionRedirectorState extends State<SessionRedirector> {
  @override
  void initState() {
    super.initState();
    _handleRedirect();
  }

  Future<void> _handleRedirect() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Reuse your role-check logic here
    final data = await Supabase.instance.client
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    if (data != null && data['is_admin'] == true) {
      // You might need to update your AppState here too
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/user');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Making the UI responsive using LayoutBuilder or Mediaquery
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Colors.blue.shade800, Colors.blue.shade400],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment_rounded, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "JK Properties",
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Property Rental Management App",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: size.height * 0.1),
            // Login Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            // Signup Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text("SIGN UP", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}