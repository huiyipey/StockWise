import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/app_models.dart';
import 'stockwise_ui.dart';
import 'glass_bottom_nav.dart' show NavItem;

abstract final class InventoryColors {
  static const background = Color(0xFFF4F6F0);
  static const ink = Color(0xFF18382C);
  static const green = Color(0xFF247653);
  static const soft = Color(0xFFE1EBDD);
  static const muted = Color(0xFF64766A);
  static const line = Color(0xFFD1DAD0);
  static const error = Color(0xFFBB513D);
  static const amber = Color(0xFFA26124);
}

/// Keeps the approved inventory design scoped to its own pages and dialogs.
class InventoryTheme extends StatelessWidget {
  const InventoryTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const border = InventoryInputBorder();
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: InventoryColors.background,
        colorScheme: base.colorScheme.copyWith(
          primary: InventoryColors.green,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: InventoryColors.ink,
          error: InventoryColors.error,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: InventoryColors.ink,
          displayColor: InventoryColors.ink,
        ),
        dividerColor: InventoryColors.line,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 12),
          labelStyle: TextStyle(color: InventoryColors.muted, fontSize: 12),
          floatingLabelStyle: TextStyle(
            color: InventoryColors.muted,
            fontSize: 12,
          ),
          hintStyle: TextStyle(color: InventoryColors.muted, fontSize: 13),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: InventoryInputBorder(
            borderSide: BorderSide(color: InventoryColors.green, width: 1.4),
          ),
          errorBorder: InventoryInputBorder(
            borderSide: BorderSide(color: InventoryColors.error),
          ),
          focusedErrorBorder: InventoryInputBorder(
            borderSide: BorderSide(color: InventoryColors.error, width: 1.4),
          ),
          errorMaxLines: 3,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: InventoryColors.green),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: InventoryColors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// An enclosed field with its floating label inside, as in the PDF.
class InventoryInputBorder extends UnderlineInputBorder {
  const InventoryInputBorder({
    super.borderSide = const BorderSide(color: InventoryColors.line),
  });
  @override
  InventoryInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) => InventoryInputBorder(borderSide: borderSide ?? this.borderSide);
  @override
  InventoryInputBorder scale(double t) =>
      InventoryInputBorder(borderSide: borderSide.scale(t));
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is InventoryInputBorder
      ? InventoryInputBorder(
          borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        )
      : super.lerpFrom(a, t);
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is InventoryInputBorder
      ? InventoryInputBorder(
          borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        )
      : super.lerpTo(b, t);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(BorderRadius.circular(12).toRRect(rect));
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      BorderRadius.circular(12).toRRect(rect.deflate(borderSide.width)),
    );
  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRRect(
      BorderRadius.circular(12).toRRect(rect.deflate(borderSide.width / 2)),
      borderSide.toPaint(),
    );
  }
}

class InventoryHeader extends StatelessWidget {
  const InventoryHeader({
    super.key,
    required this.title,
    this.storeName,
    this.back = false,
    this.onBack,
    this.trailing,
  });
  final String title;
  final String? storeName;
  final bool back;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    child: Row(
      children: [
        if (back) ...[
          IconButton.filledTonal(
            onPressed: onBack,
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: InventoryColors.green,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (storeName != null) ...[
                Text(
                  storeName!.toUpperCase(),
                  style: const TextStyle(
                    color: InventoryColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: InventoryColors.ink,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class InventoryButton extends StatelessWidget {
  const InventoryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.soft = false,
    this.centered = true,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy, soft, centered, danger;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: danger
          ? InventoryColors.error
          : soft
          ? InventoryColors.soft
          : InventoryColors.green,
      foregroundColor: soft ? InventoryColors.green : Colors.white,
      minimumSize: Size.fromHeight(soft || danger ? 46 : 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (busy) ...[
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: soft ? InventoryColors.green : Colors.white,
            ),
          ),
          const SizedBox(width: 9),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 9),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class InventoryBottomNav extends StatelessWidget {
  const InventoryBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
  });
  final int currentIndex;
  final List<NavItem> items;
  @override
  Widget build(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(9.5) * 1.2 * 2;
    return Container(
      height: (22 + 4 + labelHeight + 24).clamp(76, double.infinity),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: InventoryColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == currentIndex,
                button: true,
                label: items[i].label,
                child: Tooltip(
                  message: items[i].label,
                  child: Material(
                    color: i == currentIndex
                        ? InventoryColors.soft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: items[i].onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 5,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == currentIndex
                                  ? items[i].activeIcon
                                  : items[i].icon,
                              size: 22,
                              color: i == currentIndex
                                  ? InventoryColors.green
                                  : InventoryColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[i].label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                height: 1.2,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: i == currentIndex
                                    ? InventoryColors.green
                                    : InventoryColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InventoryEmpty extends StatelessWidget {
  const InventoryEmpty({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.inventory_2_outlined,
  });
  final String title;
  final String? body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 42),
    child: Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: InventoryColors.soft,
          child: Icon(icon, color: InventoryColors.green, size: 38),
        ),
        const SizedBox(height: 26),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: InventoryColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 18),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: InventoryColors.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

String inventoryCategoryName(String id, List<StoreCategory> records) {
  for (final record in records) {
    if (record.id == id) return record.name;
  }
  final name = id.replaceAll('-', ' ');
  return name.isEmpty
      ? 'Other'
      : '${name[0].toUpperCase()}${name.substring(1)}';
}

class InventoryBatchTile extends StatelessWidget {
  const InventoryBatchTile({
    super.key,
    required this.item,
    required this.categoryName,
    required this.onTap,
  });
  final InventoryBatch item;
  final String categoryName;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilExpiry;
    final urgent = days <= 2;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArtwork(size: 52, imagePath: item.imagePath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$categoryName / ${item.quantityOnHand} ${item.unitLabel}',
                      style: const TextStyle(
                        color: InventoryColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Exp: ${DateFormat('dd MMM yyyy').format(item.expiryAt)}',
                      style: const TextStyle(
                        color: InventoryColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: urgent
                      ? const Color(0xFFFAE7E0)
                      : const Color(0xFFFAECD6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  days < 0
                      ? 'Expired'
                      : days == 0
                      ? 'Today'
                      : '$days ${days == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: urgent
                        ? InventoryColors.error
                        : InventoryColors.amber,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showInventoryCategorySheet({
  required BuildContext context,
  required Map<String, String> choices,
  required String selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: InventoryColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) => InventoryTheme(
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4C1B3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Filter by category',
                style: TextStyle(
                  fontSize: 23,
                  color: InventoryColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = choices.entries.elementAt(index);
                    final active = selected == entry.key;
                    return Semantics(
                      selected: active,
                      button: true,
                      child: Material(
                        color: active ? InventoryColors.soft : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: ValueKey('category-option-${entry.key}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context, entry.key),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: active
                                            ? InventoryColors.green
                                            : InventoryColors.ink,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (active) ...[
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: InventoryColors.green,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

class InventoryFilters extends StatelessWidget {
  const InventoryFilters({
    super.key,
    required this.ids,
    required this.records,
    required this.category,
    required this.onCategory,
    required this.range,
    required this.onDate,
    required this.onClearDate,
    required this.ascending,
    required this.onSort,
    this.compact = false,
  });
  final List<String> ids;
  final List<StoreCategory> records;
  final String category;
  final ValueChanged<String> onCategory;
  final DateTimeRange? range;
  final VoidCallback onDate, onClearDate, onSort;
  final bool ascending, compact;

  @override
  Widget build(BuildContext context) {
    final selected = ids.contains(category) ? category : 'all';
    final unknown = ids.where((id) => !records.any((r) => r.id == id)).toList()
      ..sort();
    final ordered = [
      ...records.where((r) => ids.contains(r.id)).map((r) => r.id),
      ...unknown,
    ];
    final choices = <String, String>{
      'all': 'All categories',
      for (final id in ordered) id: inventoryCategoryName(id, records),
    };
    Future<void> selectCategory() async {
      final value = await showInventoryCategorySheet(
        context: context,
        choices: choices,
        selected: selected,
      );
      if (value != null && context.mounted) onCategory(value);
    }

    final dateText = range == null
        ? (compact ? 'Any expiry date' : 'Filter expiry date')
        : '${DateFormat('dd MMM').format(range!.start)} - ${DateFormat('dd MMM').format(range!.end)}';
    final sort = _InventoryFilterPill(
      key: const ValueKey('inventory-sort-filter'),
      label: ascending ? 'Asc' : 'Desc',
      icon: ascending ? Icons.arrow_upward : Icons.arrow_downward,
      onPressed: onSort,
      compact: true,
    );
    final dates = _InventoryFilterPill(
      key: const ValueKey('inventory-date-filter'),
      label: dateText,
      icon: Icons.calendar_today_outlined,
      onPressed: onDate,
      compact: compact,
      muted: true,
      outlined: !compact,
    );
    final clear = range == null
        ? null
        : IconButton(
            onPressed: onClearDate,
            tooltip: 'Clear date filter',
            icon: const Icon(Icons.close, size: 18),
          );
    if (compact) {
      final categories = _InventoryFilterPill(
        key: const ValueKey('inventory-category-filter'),
        label: choices[selected]!,
        onPressed: selectCategory,
        compact: true,
        bold: true,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(11) > 14) {
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [categories, dates, sort],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 10, child: categories),
                  const SizedBox(width: 6),
                  Expanded(flex: 11, child: dates),
                  const SizedBox(width: 6),
                  sort,
                ],
              );
            },
          ),
          ?clear,
        ],
      );
    }
    return Column(
      children: [
        Semantics(
          button: true,
          child: InkWell(
            key: const ValueKey('inventory-category-filter'),
            borderRadius: BorderRadius.circular(12),
            onTap: selectCategory,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Category'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      choices[selected]!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: dates),
            ?clear,
            const SizedBox(width: 8),
            sort,
          ],
        ),
      ],
    );
  }
}

class _InventoryFilterPill extends StatelessWidget {
  const _InventoryFilterPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.muted = false,
    this.bold = false,
    this.outlined = false,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact, muted, bold, outlined;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: outlined ? Colors.white : InventoryColors.soft,
      foregroundColor: muted ? InventoryColors.muted : InventoryColors.green,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(outlined ? 12 : 22),
        side: outlined
            ? const BorderSide(color: InventoryColors.line)
            : BorderSide.none,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 14 : 17),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
