import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'shared/routing/app_router.dart';
import 'shared/theme/homequest_theme.dart';

class HomeQuestApp extends StatelessWidget {
  const HomeQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HomeQuest',
      debugShowCheckedModeBanner: false,
      theme: HomeQuestTheme.light,
      routerConfig: appRouter,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
