class CaregiverSearchRange {
  const CaregiverSearchRange({required this.from, required this.to});

  factory CaregiverSearchRange.forPage({
    required int page,
    required int pageSize,
  }) {
    final from = page * pageSize;
    return CaregiverSearchRange(from: from, to: from + pageSize);
  }

  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is CaregiverSearchRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class CaregiverSearchCard {
  const CaregiverSearchCard({
    required this.id,
    required this.fullName,
    required this.city,
    required this.experience,
    required this.schedule,
    required this.description,
    this.contactPhone = '',
  });

  final String id;
  final String fullName;
  final String city;
  final String experience;
  final String schedule;
  final String description;
  final String contactPhone;
}

class CaregiverSearchPage {
  const CaregiverSearchPage({required this.items, required this.hasMore});

  final List<CaregiverSearchCard> items;
  final bool hasMore;
}
