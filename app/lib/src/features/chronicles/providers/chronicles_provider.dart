import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/chronicles_repository.dart';
import '../data/chronicles_repository_impl.dart';
import '../domain/chronicle.dart';

final chroniclesRepositoryProvider = Provider<ChroniclesRepository>((ref) {
  return SupabaseChroniclesRepository(ref.watch(supabaseProvider));
});

final recentChroniclesProvider = FutureProvider<List<Chronicle>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(chroniclesRepositoryProvider).getRecentChronicles(family.id);
});
