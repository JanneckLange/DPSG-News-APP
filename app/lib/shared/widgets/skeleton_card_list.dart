import 'package:flutter/material.dart';

/// Zeigt 3-4 schimmernde Platzhalter-Karten, passend zum Card-Layout von
/// [EventListTile], statt eines zentrierten Spinners waehrend Events/eigene
/// Events geladen werden.
class SkeletonCardList extends StatefulWidget {
  const SkeletonCardList({super.key, this.count = 4});

  final int count;

  @override
  State<SkeletonCardList> createState() => _SkeletonCardListState();
}

class _SkeletonCardListState extends State<SkeletonCardList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(opacity: _opacity.value, child: child);
      },
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.count,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            height: 88,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 160, height: 16, color: scheme.surfaceContainerHighest),
                const SizedBox(height: 10),
                Container(width: 100, height: 12, color: scheme.surfaceContainerHighest),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
