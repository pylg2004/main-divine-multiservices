import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

/// Grille de [StatCard] responsive : contrairement à un `GridView` à ratio
/// fixe, chaque carte garde une hauteur intrinsèque (jamais de débordement
/// si le contenu est un peu plus grand que prévu) et repasse
/// automatiquement à la ligne dès que la largeur manque.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppSizes.tabletBreakpoint ? 4 : 2;
        final cardWidth = (constraints.maxWidth - (columns - 1) * AppSizes.sm) / columns;
        return Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final child in children) SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
