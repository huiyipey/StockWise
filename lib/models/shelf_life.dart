// Classify the total shelf life of a product.
enum ShelfLifeType { short, medium, long }

// Name the available expiry warning colours.
enum ShelfLifeColour { green, orange, red }

// Count whole calendar days without time-of-day differences.
int calendarDaysBetween(DateTime first, DateTime last) => DateTime.utc(
  last.year,
  last.month,
  last.day,
).difference(DateTime.utc(first.year, first.month, first.day)).inDays;

// Classify the product by its total shelf life.
ShelfLifeType shelfLifeType(int totalDays) => totalDays < 8
    ? ShelfLifeType.short
    : totalDays <= 90
    ? ShelfLifeType.medium
    : ShelfLifeType.long;

// Choose the warning colour from the days remaining.
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
