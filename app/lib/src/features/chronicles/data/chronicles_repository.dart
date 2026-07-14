import '../domain/chronicle.dart';
import '../domain/kingdom_legend_entry.dart';

abstract class ChroniclesRepository {
  Future<List<Chronicle>> getRecentChronicles(String familyId);

  Future<List<KingdomLegendEntry>> getKingdomLegend(String familyId);
}
