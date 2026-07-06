import 'package:go_router/go_router.dart';

import '../../features/auth/sign_in_screen.dart';
import '../../features/families/create_family_screen.dart';
import '../../features/families/family_dashboard_screen.dart';
import '../../features/profile/profile_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/sign-in',
  routes: [
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/create-family',
      builder: (context, state) => const CreateFamilyScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const FamilyDashboardScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
