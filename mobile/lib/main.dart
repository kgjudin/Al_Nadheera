import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'core/widgets/main_layout.dart';
import 'features/chat/services/presence_service.dart';
import 'services/location_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: "assets/config.env");
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      debugPrint('Missing Supabase credentials in .env file');
    } else {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
  } catch (e) {
    debugPrint('Error initializing app: $e');
  }

  runApp(const AlNadheeraApp());
}

class AlNadheeraApp extends StatefulWidget {
  const AlNadheeraApp({super.key});

  @override
  State<AlNadheeraApp> createState() => _AlNadheeraAppState();
}

class _AlNadheeraAppState extends State<AlNadheeraApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // If already authenticated on launch, initialize tracking
    if (Supabase.instance.client.auth.currentSession != null) {
      PresenceService.instance.initialize();
      LocationService.instance.initialize();
    }

    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          PresenceService.instance.initialize();
          LocationService.instance.initialize();
        } else if (data.event == AuthChangeEvent.signedOut) {
          LocationService.instance.onAppClosed();
          LocationService.instance.dispose();
          PresenceService.instance.dispose();
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Employee returned to the app -> update current location & mark online
      LocationService.instance.recordCurrentLocation();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Employee closed, minimized, or exited the app -> save latest location & mark offline
      LocationService.instance.onAppClosed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    LocationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ANCC',
      theme: AppTheme.lightTheme,
      home: const InitialAuthCheck(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InitialAuthCheck extends StatefulWidget {
  const InitialAuthCheck({super.key});

  @override
  State<InitialAuthCheck> createState() => _InitialAuthCheckState();
}

class _InitialAuthCheckState extends State<InitialAuthCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  Future<void> _redirect() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          try {
            final empRes = await Supabase.instance.client
                .from('employees')
                .select('id, name, role, status')
                .eq('id', user.id)
                .maybeSingle();

            if (empRes != null) {
              final role = empRes['role']?.toString().toLowerCase() ?? '';
              final status = empRes['status']?.toString().toLowerCase() ?? 'active';
              final isSuperAdmin = role == 'super admin';

              if (!isSuperAdmin && status != 'active') {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  String message = 'Your account is pending Super Admin approval. You can access it once admitted.';
                  if (status == 'declined' || status == 'rejected') {
                    message = 'Your registration request was declined by the administrator.';
                  } else if (status == 'inactive') {
                    message = 'Your account is inactive. Please contact the administrator.';
                  }
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(initialMessage: message),
                    ),
                  );
                }
                return;
              }
            }
          } catch (e) {
            debugPrint('Error verifying employee status in InitialAuthCheck: $e');
          }
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainLayout()),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during auth redirect: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
