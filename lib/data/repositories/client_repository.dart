import 'dart:async';

import 'package:uuid/uuid.dart';

import '../datasources/local/memory_collection.dart';
import '../datasources/remote/firestore_sync_service.dart';
import '../models/client_model.dart';

class ClientRepository {
  final _uuid = const Uuid();
  final _sync = FirestoreSyncService.instance;
  final _cache = MemoryCollection<ClientModel>();

  static const _collection = 'clients';

  List<ClientModel> all() {
    final list = _cache.all;
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }

  List<ClientModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    return all()
        .where((c) =>
            c.fullName.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  ClientModel? byId(String id) => _cache.byId(id);

  Future<ClientModel> create({
    required String fullName,
    required String phone,
    String? email,
    DateTime? birthDate,
    String? notes,
  }) async {
    final client = ClientModel(
      id: _uuid.v4(),
      fullName: fullName.trim(),
      phone: phone.trim(),
      email: email?.trim(),
      birthDate: birthDate,
      notes: notes?.trim(),
      createdAt: DateTime.now(),
    );
    _cache.put(client.id, client);
    unawaited(_pushToFirestore(client));
    return client;
  }

  Future<void> update(
    ClientModel client, {
    String? fullName,
    String? phone,
    String? email,
    DateTime? birthDate,
    String? notes,
  }) async {
    if (fullName != null) client.fullName = fullName.trim();
    if (phone != null) client.phone = phone.trim();
    if (email != null) client.email = email.trim();
    if (birthDate != null) client.birthDate = birthDate;
    if (notes != null) client.notes = notes.trim();
    unawaited(_pushToFirestore(client));
  }

  Future<void> registerVisit({
    required String clientId,
    required double amountSpent,
    required int pointsEarned,
  }) async {
    final client = byId(clientId);
    if (client == null) return;
    client.totalSpent += amountSpent;
    client.loyaltyPoints += pointsEarned;
    client.lastVisit = DateTime.now();
    unawaited(_pushToFirestore(client));
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    unawaited(_sync.deleteDoc(_collection, id));
  }

  /// Supprime tous les clients (Firestore + cache) — utilisé par la
  /// réinitialisation des données depuis Paramètres.
  Future<void> deleteAll() async {
    final ids = _cache.all.map((c) => c.id).toList();
    for (final id in ids) {
      await _sync.deleteDoc(_collection, id);
    }
    _cache.replaceAll({});
  }

  /// Récupère les clients depuis Firestore (seule base de données) et
  /// remplace le cache en mémoire. À appeler au démarrage/après connexion —
  /// si Firestore est injoignable, le cache reste tel quel.
  Future<void> pullFromFirestore() async {
    final docs = await _sync.pullCollection(_collection);
    final map = <String, ClientModel>{
      for (final data in docs) data['id'] as String: _fromFirestore(data),
    };
    _cache.replaceAll(map);
  }

  Future<void> _pushToFirestore(ClientModel client) {
    return _sync.pushDoc(_collection, client.id, {
      'fullName': client.fullName,
      'phone': client.phone,
      'email': client.email,
      'birthDate': client.birthDate,
      'notes': client.notes,
      'loyaltyPoints': client.loyaltyPoints,
      'totalSpent': client.totalSpent,
      'createdAt': client.createdAt,
      'lastVisit': client.lastVisit,
    });
  }

  ClientModel _fromFirestore(Map<String, dynamic> data) {
    return ClientModel(
      id: data['id'] as String,
      fullName: data['fullName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      birthDate: data['birthDate'] as DateTime?,
      notes: data['notes'] as String?,
      loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
      createdAt: data['createdAt'] as DateTime? ?? DateTime.now(),
      lastVisit: data['lastVisit'] as DateTime?,
    );
  }
}
