import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/family/presentation/create_family_page.dart';
import '../../features/family/presentation/family_dashboard_page.dart';
import '../../features/family/presentation/accept_invitation_page.dart';
import '../../features/family/presentation/members_management_page.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/devtools/presentation/devtools_page.dart';
import '../../features/completions/presentation/my_missions_page.dart';
import '../../features/completions/presentation/validations_page.dart';
import '../../features/notifications/presentation/guardian_notifications_page.dart';
import '../../features/profile/presentation/rpg_profile_page.dart';
import '../../features/profile/presentation/heroes_hall_page.dart';
import '../../features/boss/presentation/boss_screen.dart';
import '../../features/rewards/presentation/reward_suggestions_page.dart';
import '../../features/chronicles/presentation/kingdom_legend_page.dart';
import '../../features/kingdom/presentation/kingdom_progress_page.dart';
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
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersManagementPage(),
      ),
      GoRoute(
        path: '/missions',
        builder: (context, state) => const MyMissionsPage(),
      ),
      GoRoute(
        path: '/validations',
        builder: (context, state) => const ValidationsPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const GuardianNotificationsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const RpgProfilePage(),
      ),
      GoRoute(
        path: '/heroes',
        builder: (context, state) => const HeroesHallPage(),
      ),
      GoRoute(
        path: '/bosses',
        builder: (context, state) => const BossScreen(),
      ),
      GoRoute(
        path: '/reward-suggestions',
        builder: (context, state) => const RewardSuggestionsPage(),
      ),
      GoRoute(
        path: '/kingdom-legend',
        builder: (context, state) => const KingdomLegendPage(),
      ),
      GoRoute(
        path: '/kingdom-progress',
        builder: (context, state) => const KingdomProgressPage(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => AcceptInvitationPage(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/devtools',
        builder: (context, state) => const DevToolsPage(),
      ),
    ],
  );
});
