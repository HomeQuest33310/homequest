import '../domain/domain.dart';

abstract class DomainsRepository {
  Future<List<Domain>> getDomains(String familyId);
}
