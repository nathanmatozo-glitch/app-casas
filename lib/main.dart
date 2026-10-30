import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  var googleAuthReady = false;

  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;

      if (kIsWeb) {
        googleAuthReady = DefaultFirebaseOptions.authDomain.isNotEmpty;
      } else if (DefaultFirebaseOptions.googleServerClientId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(
          serverClientId: DefaultFirebaseOptions.googleServerClientId,
        );
        googleAuthReady = true;
      }
    }
  } catch (error, stackTrace) {
    debugPrint('Não foi possível conectar ao Firebase: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(AppCasasApp(
    firebaseReady: firebaseReady,
    googleAuthReady: googleAuthReady,
  ));
}

class AppCasasApp extends StatelessWidget {
  const AppCasasApp({
    super.key,
    required this.firebaseReady,
    required this.googleAuthReady,
  });

  final bool firebaseReady;
  final bool googleAuthReady;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'App Casas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF176B55),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F8F7),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE5E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE5E0)),
            ),
          ),
        ),
        home: firebaseReady
            ? StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return HomePage(
                    firebaseReady: firebaseReady,
                    googleAuthReady: googleAuthReady,
                    user: snapshot.data,
                  );
                },
              )
            : const HomePage(
                firebaseReady: false,
                googleAuthReady: false,
                user: null,
              ),
      );
}

