import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.firebaseReady,
    required this.googleAuthReady,
  });

  final bool firebaseReady;
  final bool googleAuthReady;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool busy = false;
  String? errorMessage;

  Future<void> signInWithGoogle() async {
    if (!widget.googleAuthReady) return;
    setState(() {
      busy = true;
      errorMessage = null;
    });

    try {
      await const AuthService().signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = switch (error.code) {
          'operation-not-allowed' =>
            'Ative o acesso com Google nas configurações do Firebase.',
          'network-request-failed' =>
            'Sem conexão. Confira sua internet e tente novamente.',
          'popup-closed-by-user' => 'A entrada foi cancelada.',
          _ => 'Não foi possível entrar com Google. Tente novamente.',
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Não foi possível entrar. Confira a configuração do Firebase e tente novamente.';
      });
      debugPrint('Falha no login Google: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Acesse sua conta')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
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
                    const SizedBox(height: 22),
                    Text('Uma conta para tudo',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Entre para anunciar, salvar imóveis e conversar com quem anunciou. Você também pode continuar pesquisando sem entrar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: busy || !widget.googleAuthReady
                            ? null
                            : signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD5DED9)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
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
                    if (!widget.googleAuthReady) ...[
                      const SizedBox(height: 16),
                      _InfoCard(
                        text: widget.firebaseReady
                            ? 'O login Google ainda precisa ser configurado. Confira os passos no guia do projeto.'
                            : 'O login ainda não está conectado. Configure o Firebase para liberar essa função.',
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _InfoCard(text: errorMessage!, isError: true),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      'Usamos apenas os dados básicos da sua conta Google para identificar seus anúncios e preferências.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFF0ED) : const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? const Color(0xFF9D321F) : const Color(0xFF72500C),
          ),
        ),
      );
}
