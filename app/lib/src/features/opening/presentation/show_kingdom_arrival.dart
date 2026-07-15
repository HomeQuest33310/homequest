import 'package:flutter/material.dart';

import '../data/opening_preferences.dart';
import '../domain/opening_experience.dart';
import 'opening_page.dart';

Future<void> showKingdomArrivalIfNeeded({
  required BuildContext context,
  required String kingdomId,
}) async {
  final shouldShow =
      await OpeningPreferences.shouldShowKingdomArrival(kingdomId);
  if (!context.mounted || !shouldShow) return;

  final completed = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (routeContext, animation, secondaryAnimation) => OpeningPage(
        experience: OpeningExperience.kingdomArrival,
        onFinished: () => Navigator.of(routeContext).pop(true),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  if (completed == true) {
    await OpeningPreferences.markKingdomArrivalSeen(kingdomId);
  }
}
