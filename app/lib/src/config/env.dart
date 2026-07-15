import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');

  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  /// Canonical HTTPS entry point used in invitations.
  /// The same URL can later be registered as an Android App Link and an iOS
  /// Universal Link without changing existing invitations.
  static String get appPublicUrl => dotenv.get('APP_PUBLIC_URL', fallback: '');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
