import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../features/auth/session_notifier.dart';

/// N'affiche [child] que si le poste de travail de l'utilisateur connecté
/// figure dans [allowedWorkstations]. Voir spec §7 "logique de filtrage
/// par poste".
class PostGate extends ConsumerWidget {
  final List<Workstation> allowedWorkstations;
  final Widget child;
  final Widget? fallback;

  const PostGate({
    super.key,
    required this.allowedWorkstations,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final allowed = session != null && allowedWorkstations.contains(session.workstation);
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
