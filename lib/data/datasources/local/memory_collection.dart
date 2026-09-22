/// Cache en mémoire (jamais persisté sur disque) pour une collection
/// Firestore — remplace Hive : Firestore est désormais la seule base de
/// données de l'app. Ce cache existe uniquement pour donner aux écrans une
/// lecture synchrone (`all()`/`byId()`) pendant la session en cours ; il est
/// entièrement reconstruit à chaque `pullFromFirestore()` (login, ou après
/// chaque mutation) et perdu à la fermeture de l'app — sans connexion
/// internet, l'app ne peut plus rien lire ni écrire (choix assumé : voir
/// AuthRepository/SaleRepository pour la connexion et les ventes).
class MemoryCollection<T> {
  final Map<String, T> _items = {};

  List<T> get all => _items.values.toList();

  T? byId(String id) => _items[id];

  void put(String id, T item) => _items[id] = item;

  void remove(String id) => _items.remove(id);

  /// Remplace tout le contenu — utilisé par `pullFromFirestore()`.
  void replaceAll(Map<String, T> items) {
    _items
      ..clear()
      ..addAll(items);
  }

  bool containsKey(String id) => _items.containsKey(id);

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
}
