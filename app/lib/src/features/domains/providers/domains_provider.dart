import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../family/providers/family_provider.dart';
import '../data/domains_repository.dart';
import '../data/domains_repository_impl.dart';
import '../domain/domain.dart';

final domainsRepositoryProvider = Provider<DomainsRepository>((ref) {
  return SupabaseDomainsRepository(ref.watch(supabaseProvider));
});

final currentFamilyDomainsProvider = FutureProvider<List<Domain>>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return const [];
  return ref.watch(domainsRepositoryProvider).getDomains(family.id);
});
