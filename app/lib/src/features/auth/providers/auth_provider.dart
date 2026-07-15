import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/password_reset_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

final passwordResetServiceProvider = Provider<PasswordResetService>((ref) {
  return PasswordResetService(ref.watch(supabaseProvider));
});

/// Remains true after Supabase emits [AuthChangeEvent.passwordRecovery],
/// until the user saves or cancels the new password.
final passwordRecoveryProvider = StateProvider<bool>((ref) {
  return Uri.base.queryParameters['password-recovery'] == '1';
});
