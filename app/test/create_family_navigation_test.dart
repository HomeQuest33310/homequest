import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homequestoria/src/features/family/presentation/create_family_page.dart';

void main() {
  Widget appWithRouter(GoRouter router) {
    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('revient sur la page précédente avant de créer un royaume',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/previous',
      routes: [
        GoRoute(
          path: '/previous',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/create-family'),
              child: const Text('Ouvrir la création'),
            ),
          ),
        ),
        GoRoute(
          path: '/create-family',
          builder: (context, state) => const CreateFamilyPage(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const Text('Connexion'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.tap(find.text('Ouvrir la création'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revenir à la page précédente'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir la création'), findsOneWidget);
    expect(find.text('Créer mon Royaume'), findsNothing);
  });

  testWidgets('revient à la connexion sans historique de navigation',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/create-family',
      routes: [
        GoRoute(
          path: '/create-family',
          builder: (context, state) => const CreateFamilyPage(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Connexion')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.tap(find.text('Revenir à la page précédente'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Créer mon Royaume'), findsNothing);
  });
}
