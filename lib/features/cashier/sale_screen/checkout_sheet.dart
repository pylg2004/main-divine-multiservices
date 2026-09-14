import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/models/enums.dart';

Future<PaymentMethod?> showCheckoutSheet(BuildContext context, {required double total}) {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: AppSizes.md,
        right: AppSizes.md,
        top: AppSizes.md,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Encaissement', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Total à payer : ${MoneyFormatter.format(total)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: AppSizes.md),
            _PaymentTile(
              icon: Icons.payments_outlined,
              label: 'Espèces',
              onTap: () => Navigator.of(context).pop(PaymentMethod.especes),
            ),
            _PaymentTile(
              icon: Icons.credit_card_outlined,
              label: 'Carte',
              onTap: () => Navigator.of(context).pop(PaymentMethod.carte),
            ),
            _PaymentTile(
              icon: Icons.phone_iphone_outlined,
              label: 'Mobile',
              onTap: () => Navigator.of(context).pop(PaymentMethod.mobile),
            ),
            const SizedBox(height: AppSizes.md),
          ],
        ),
      ),
    ),
  );
}

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PaymentTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
