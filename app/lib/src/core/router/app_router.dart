import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_page.dart';
import '../../features/family/presentation/create_family_page.dart';
import '../../features/family/presentation/family_dashboard_page.dart';
import 'home_gate.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeGate(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/create-family',
        builder: (context, state) => const CreateFamilyPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const FamilyDashboardPage(),
      ),
    ],
  );
});
