import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/env.dart';

class HomeQuestBootstrap extends StatefulWidget {
  const HomeQuestBootstrap({super.key});

  static Widget buildFatalError(FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF171426),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 50,
                      color: Color(0xFFFFD77A),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Le Royaume a rencontré un obstacle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFF8EE),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD9D3E8),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<HomeQuestBootstrap> createState() => _HomeQuestBootstrapState();
}

class _HomeQuestBootstrapState extends State<HomeQuestBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeServices();
  }

  Future<void> _initializeServices() async {
    await dotenv.load(fileName: '.env');

    if (!Env.hasSupabaseConfig) {
      throw StateError(
        'Configuration Supabase absente. Vérifiez SUPABASE_URL et '
        'SUPABASE_ANON_KEY dans la publication GitHub Actions.',
      );
    }

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  void _retry() {
    setState(() {
      _initialization = _initializeServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupPage(
            child: _StartupCard(
              icon: Icons.auto_awesome,
              title: 'Le Royaume prend vie',
              message: 'Connexion aux Chroniques de HomeQuest…',
              showProgress: true,
            ),
          );
        }

        if (snapshot.hasError) {
          return _StartupPage(
            child: _StartupCard(
              icon: Icons.cloud_off_rounded,
              title: 'Le portail ne répond pas',
              message: snapshot.error.toString(),
              actionLabel: 'Réessayer',
              onAction: _retry,
            ),
          );
        }

        return const HomeQuestApp();
      },
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF171426),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  const _StartupCard({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF25203A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x506B4EFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x406B4EFF),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50, color: const Color(0xFFFFD77A)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFF8EE),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9D3E8),
                  height: 1.45,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: Color(0xFFFFD77A),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
