import '../domain/chronicle.dart';

abstract class ChroniclesRepository {
  Future<List<Chronicle>> getRecentChronicles(String familyId);
}
