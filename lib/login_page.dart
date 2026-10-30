import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  String? errorMessage;

  Future<void> signInWithGoogle() async {
    if (!widget.firebaseReady) {
      setState(() => errorMessage =
          'O login ainda não foi ativado. Configure o Firebase seguindo as instruções do README.');
      return;
    }

    setState(() {
      busy = true;
      errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return;

      final googleAuthentication = googleUser.authentication;
      final idToken = googleAuthentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'O Google não retornou o token. Verifique o OAuth Client ID do tipo Web.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = switch (error.code) {
          'operation-not-allowed' =>
            'Ative o provedor Google em Authentication no Firebase.',
          'network-request-failed' =>
            'Sem conexão com a internet. Verifique sua rede e tente novamente.',
          _ => 'Não foi possível entrar: ' + (error.message ?? error.code),
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Não foi possível concluir o login com Google. Verifique a configuração do Firebase e tente novamente.';
      });
      debugPrint('Erro no Google Sign-In: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EFE9),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(Icons.home_work_rounded,
                          size: 48, color: Color(0xFF176B55)),
                    ),
                    const SizedBox(height: 24),
                    Text('App Casas',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Entre para anunciar imóveis, salvar opções e encontrar seu próximo lar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: busy ? null : signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD5DED9)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('G',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4285F4))),
                                  SizedBox(width: 12),
                                  Text('Continuar com Google',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF202124))),
                                ],
                              ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(errorMessage!,
                            style: const TextStyle(color: Color(0xFF8A4B08)),
                            textAlign: TextAlign.center),
                      ),
                    ],
                    if (!widget.firebaseReady) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Configuração necessária: conecte o aplicativo ao Firebase e ative o provedor Google para liberar o acesso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 30),
                    Text(
                      'Ao continuar, você concorda com os termos de uso e a política de privacidade do App Casas.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
