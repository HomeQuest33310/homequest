import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/realtime/gameplay_realtime_provider.dart';
import 'core/theme/app_theme.dart';

class HomeQuestApp extends ConsumerWidget {
  const HomeQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(gameplayRealtimeProvider);

    return MaterialApp.router(
      title: 'HomeQuest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
