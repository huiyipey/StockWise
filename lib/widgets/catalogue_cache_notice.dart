import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/catalogue_cache.dart';
import '../services/local_data_session.dart';
import '../services/local_database.dart';
import 'inventory_ui.dart';

class CatalogueCacheNotice extends StatelessWidget {
  const CatalogueCacheNotice({
    super.key,
    this.scope,
    this.cache,
    this.horizontalMargin = 20,
  });
  final LocalScope? scope;
  final CatalogueCache? cache;
  final double horizontalMargin;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: cache ?? CatalogueCache.instance,
    builder: (context, _) {
      final scope = this.scope ?? LocalDataSession.instance.scope;
      if (scope == null) return const SizedBox.shrink();
      final source = cache ?? CatalogueCache.instance;
      final inventory = source.status(scope);
      final categories = source.status(scope, 'categories');
      final status = inventory?.source != CatalogueSource.live
          ? inventory
          : categories;
      if (status == null || status.source == CatalogueSource.live) {
        return const SizedBox.shrink();
      }
      final saved = status.savedAt;
      final stamp = saved == null
          ? ''
          : ' · ${DateFormat('d MMM, HH:mm').format(saved)}';
      final text = switch (status.source) {
        CatalogueSource.pending =>
          'Syncing catalogue changes. Updates need a connection.',
        CatalogueSource.unavailable =>
          'Connect to load this store’s catalogue.',
        _ => 'Saved catalogue$stamp. Stock and prices may have changed.',
      };
      return Container(
        key: const ValueKey('catalogue-cache-notice'),
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAECD5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: InventoryColors.amber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: InventoryColors.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
