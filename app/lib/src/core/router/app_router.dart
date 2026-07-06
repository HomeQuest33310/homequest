import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/boss/presentation/boss_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/quests/presentation/quests_screen.dart';
import '../widgets/home_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/family', builder: (context, state) => const FamilyScreen()),
        GoRoute(path: '/quests', builder: (context, state) => const QuestsScreen()),
        GoRoute(path: '/boss', builder: (context, state) => const BossScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      ],
    ),
  ],
);
