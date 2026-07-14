class KingdomLegendEntry {
  const KingdomLegendEntry({
    required this.id,
    required this.category,
    required this.eventType,
    required this.title,
    required this.body,
    required this.status,
    required this.occurredAt,
    required this.metadata,
  });

  factory KingdomLegendEntry.fromMap(Map<String, dynamic> map) {
    return KingdomLegendEntry(
      id: map['id'] as String,
      category: map['category'] as String,
      eventType: map['event_type'] as String,
      title: map['title'] as String,
      body: map['body'] as String? ?? '',
      status: map['status'] as String? ?? 'recorded',
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map? ?? const {},
      ),
    );
  }

  final String id;
  final String category;
  final String eventType;
  final String title;
  final String body;
  final String status;
  final DateTime occurredAt;
  final Map<String, dynamic> metadata;
}
