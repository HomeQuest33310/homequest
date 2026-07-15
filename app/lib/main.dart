import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap/homequest_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = HomeQuestBootstrap.buildFatalError;
  runApp(const ProviderScope(child: HomeQuestBootstrap()));
}
