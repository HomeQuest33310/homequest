import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/bootstrap/homequest_bootstrap.dart';
import 'src/core/notifications/firebase_messaging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseMessagingService.initialize();
  ErrorWidget.builder = HomeQuestBootstrap.buildFatalError;
  runApp(const ProviderScope(child: HomeQuestBootstrap()));
}
