class CaregiverSearchCursor {
  const CaregiverSearchCursor({required this.approvedAt, required this.id});

  final DateTime approvedAt;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is CaregiverSearchCursor &&
      other.approvedAt == approvedAt &&
      other.id == id;

  @override
  int get hashCode => Object.hash(approvedAt, id);
}

class CaregiverSearchCard {
  const CaregiverSearchCard({
    required this.id,
    required this.fullName,
    required this.city,
    required this.experience,
    required this.schedule,
    required this.description,
    required this.approvedAt,
    this.contactPhone = '',
  });

  final String id;
  final String fullName;
  final String city;
  final String experience;
  final String schedule;
  final String description;
  final String contactPhone;
  final DateTime approvedAt;

  CaregiverSearchCursor get cursor =>
      CaregiverSearchCursor(approvedAt: approvedAt, id: id);
}

class CaregiverSearchPage {
  const CaregiverSearchPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<CaregiverSearchCard> items;
  final bool hasMore;
  final CaregiverSearchCursor? nextCursor;
}
