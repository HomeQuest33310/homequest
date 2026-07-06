import 'package:flutter/material.dart';

class HqPage extends StatelessWidget {
  const HqPage({super.key, required this.title, required this.child, this.actions});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [child],
        ),
      ),
    );
  }
}
