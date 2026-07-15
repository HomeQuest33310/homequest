import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../kingdom/providers/kingdom_provider.dart';
import '../data/domains_repository.dart';
import '../data/domains_repository_impl.dart';
import '../domain/domain.dart';

final domainsRepositoryProvider = Provider<DomainsRepository>((ref) {
  return SupabaseDomainsRepository(ref.watch(supabaseProvider));
});

final currentFamilyDomainsProvider = FutureProvider<List<Domain>>((ref) async {
  final kingdom = await ref.watch(currentKingdomProvider.future);
  if (kingdom == null) return const [];
  return ref.watch(domainsRepositoryProvider).getDomains(kingdom.id);
});
