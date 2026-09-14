import 'package:email_validator/email_validator.dart';

class Validators {
  Validators._();

  static String? required(String? value, {String field = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field est requis';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email requis';
    if (!EmailValidator.validate(value.trim())) return 'Email invalide';
    return null;
  }

  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!EmailValidator.validate(value.trim())) return 'Email invalide';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Mot de passe requis';
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Téléphone requis';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return 'Numéro de téléphone invalide';
    return null;
  }

  static String? positiveNumber(String? value, {String field = 'La valeur'}) {
    if (value == null || value.trim().isEmpty) return '$field est requis';
    final n = num.tryParse(value.replaceAll(',', '.'));
    if (n == null) return '$field doit être un nombre';
    if (n < 0) return '$field ne peut pas être négatif';
    return null;
  }
}
