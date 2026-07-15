import 'package:flutter/material.dart';

import '../domain/opening_experience.dart';
import 'opening_page.dart';

Future<void> showOpeningReplay({
  required BuildContext context,
  required OpeningExperience experience,
}) async {
  final replayExperience = OpeningExperience(
    kind: experience.kind,
    eyebrow: experience.eyebrow,
    title: experience.title,
    phrases: experience.phrases,
    startLabel: 'Rejouer le prologue',
    finishLabel: 'Revenir au Carnet',
  );

  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (routeContext, animation, secondaryAnimation) => OpeningPage(
        experience: replayExperience,
        onFinished: () => Navigator.of(routeContext).pop(),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
