import 'package:flutter/material.dart';

import 'stat_tile.dart';

/// Scrollfreie Reihe von [StatTile]s fuer Dashboard-Kopfbereiche. Jede Kachel
/// nimmt gleich viel Platz ein, damit auch auf schmalen Geraeten kein
/// horizontales Scrollen noetig ist. Wird von Events- und Autor-Dashboard
/// gemeinsam genutzt.
class DashboardStatRow extends StatelessWidget {
  const DashboardStatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
