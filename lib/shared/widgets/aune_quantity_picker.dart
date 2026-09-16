import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/qty_formatter.dart';

/// Sélecteur de quantité en aune (unité de longueur du tissu) : un nombre
/// d'aunes entières plus une fraction (1/4, 1/2, 3/4). Le prix total est
/// recalculé en direct à partir du prix unitaire de l'aune.
Future<double?> showAuneQuantityPicker(
  BuildContext context, {
  required String title,
  double initial = 1,
  double? unitPrice,
}) {
  final safeInitial = initial <= 0 ? 1.0 : QtyFormatter.roundToStep(initial);
  var whole = safeInitial.truncate();
  var quarters = ((safeInitial - whole) * 4).round();
  if (quarters == 4) {
    whole += 1;
    quarters = 0;
  }

  return showDialog<double>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final total = whole + quarters * QtyFormatter.auneStep;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: whole > 0 ? () => setState(() => whole--) : null,
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$whole',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => whole++),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    const Text('aune(s)'),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    _FractionChip(label: 'Aucun', selected: quarters == 0, onTap: () => setState(() => quarters = 0)),
                    _FractionChip(label: '1/4', selected: quarters == 1, onTap: () => setState(() => quarters = 1)),
                    _FractionChip(label: '1/2', selected: quarters == 2, onTap: () => setState(() => quarters = 2)),
                    _FractionChip(label: '3/4', selected: quarters == 3, onTap: () => setState(() => quarters = 3)),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  'Quantité: ${QtyFormatter.aune(total)} aune',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (unitPrice != null) ...[
                  const SizedBox(height: 4),
                  Text('Prix: ${MoneyFormatter.format(unitPrice * total)}'),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: total <= 0 ? null : () => Navigator.of(context).pop(total),
                child: const Text('Valider'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _FractionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FractionChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
