import 'package:uuid/uuid.dart';

import '../datasources/local/hive_datasource.dart';
import '../models/client_model.dart';

class ClientRepository {
  final _uuid = const Uuid();

  List<ClientModel> all() {
    final list = HiveDatasource.clients.values.toList();
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

  ClientModel? byId(String id) => HiveDatasource.clients.get(id);

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
    await HiveDatasource.clients.put(client.id, client);
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
    await client.save();
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
    await client.save();
  }

  Future<void> delete(String id) async {
    await HiveDatasource.clients.delete(id);
  }
}
