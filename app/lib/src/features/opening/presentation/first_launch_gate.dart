import 'package:flutter/material.dart';

import '../data/opening_preferences.dart';
import '../domain/opening_experience.dart';
import 'opening_page.dart';

class FirstLaunchGate extends StatefulWidget {
  const FirstLaunchGate({required this.child, super.key});

  final Widget child;

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  bool? _showOpening;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shouldShow = await OpeningPreferences.shouldShowFirstAwakening();
    if (mounted) setState(() => _showOpening = shouldShow);
  }

  Future<void> _finishOpening() async {
    await OpeningPreferences.markFirstAwakeningSeen();
    if (mounted) setState(() => _showOpening = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOpening == null) {
      return const ColoredBox(
        color: Color(0xFF070817),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFE5C77A)),
        ),
      );
    }

    if (_showOpening!) {
      return OpeningPage(
        experience: OpeningExperience.firstAwakening,
        onFinished: _finishOpening,
      );
    }

    return widget.child;
  }
}
