import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardHomeButton extends StatelessWidget {
  const DashboardHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Retour à la page principale',
      onPressed: () => context.go('/dashboard'),
      icon: const Icon(Icons.home_outlined),
    );
  }
}
