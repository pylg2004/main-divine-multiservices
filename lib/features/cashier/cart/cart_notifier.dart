import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client_model.dart';
import '../../../data/models/enums.dart';

class CartItem {
  final String referenceId;
  final SaleItemType type;
  final String title;
  final String? category;
  final String unit;
  final String? color;
  final double unitPrice;
  final int qty;

  const CartItem({
    required this.referenceId,
    required this.type,
    required this.title,
    this.category,
    this.unit = 'unité',
    this.color,
    required this.unitPrice,
    this.qty = 1,
  });

  double get sum => unitPrice * qty;

  CartItem copyWith({int? qty}) => CartItem(
        referenceId: referenceId,
        type: type,
        title: title,
        category: category,
        unit: unit,
        color: color,
        unitPrice: unitPrice,
        qty: qty ?? this.qty,
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  double get subtotal => state.fold(0, (sum, item) => sum + item.sum);

  void add(CartItem item) {
    final index = state.indexWhere((i) => i.referenceId == item.referenceId && i.type == item.type);
    if (index >= 0) {
      final existing = state[index];
      state = [
        ...state.sublist(0, index),
        existing.copyWith(qty: existing.qty + item.qty),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [...state, item];
    }
  }

  void updateQty(String referenceId, SaleItemType type, int qty) {
    if (qty <= 0) {
      remove(referenceId, type);
      return;
    }
    state = [
      for (final item in state)
        if (item.referenceId == referenceId && item.type == type) item.copyWith(qty: qty) else item,
    ];
  }

  void remove(String referenceId, SaleItemType type) {
    state = state.where((i) => !(i.referenceId == referenceId && i.type == type)).toList();
  }

  void clear() => state = [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

final selectedClientProvider = StateProvider<ClientModel?>((ref) => null);
final discountProvider = StateProvider<double>((ref) => 0);
