import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static const _buildSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _buildSupabaseKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _buildAppPublicUrl = String.fromEnvironment('APP_PUBLIC_URL');

  static String get supabaseUrl => _buildSupabaseUrl.isNotEmpty
      ? _buildSupabaseUrl
      : dotenv.maybeGet('SUPABASE_URL', fallback: '') ?? '';

  static String get supabaseAnonKey => _buildSupabaseKey.isNotEmpty
      ? _buildSupabaseKey
      : dotenv.maybeGet('SUPABASE_ANON_KEY', fallback: '') ?? '';

  /// Canonical HTTPS entry point used in invitations.
  /// The same URL can later be registered as an Android App Link and an iOS
  /// Universal Link without changing existing invitations.
  static String get appPublicUrl => _buildAppPublicUrl.isNotEmpty
      ? _buildAppPublicUrl
      : dotenv.maybeGet('APP_PUBLIC_URL', fallback: '') ?? '';

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
