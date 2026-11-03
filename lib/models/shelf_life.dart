enum ShelfLifeType { short, medium, long }

enum ShelfLifeColour { green, orange, red }

int calendarDaysBetween(DateTime first, DateTime last) => DateTime.utc(
  last.year,
  last.month,
  last.day,
).difference(DateTime.utc(first.year, first.month, first.day)).inDays;

ShelfLifeType shelfLifeType(int totalDays) => totalDays < 8
    ? ShelfLifeType.short
    : totalDays <= 90
    ? ShelfLifeType.medium
    : ShelfLifeType.long;

ShelfLifeColour shelfLifeColour(ShelfLifeType type, int daysLeft) {
  final (orangeFirst, redFirst) = switch (type) {
    ShelfLifeType.short => (3, 1),
    ShelfLifeType.medium => (20, 6),
    ShelfLifeType.long => (60, 29),
  };
  return daysLeft > orangeFirst
      ? ShelfLifeColour.green
      : daysLeft <= redFirst
      ? ShelfLifeColour.red
      : ShelfLifeColour.orange;
}
