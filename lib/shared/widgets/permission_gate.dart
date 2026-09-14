import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session_notifier.dart';
import '../permissions/permission.dart';

/// N'affiche [child] que si l'utilisateur connecté possède [permission].
/// Sinon, le widget est absent du tree (pas juste désactivé) — voir la
/// règle "vérification à 3 niveaux" du prompt.
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final allowed = session != null && session.can(permission);
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
