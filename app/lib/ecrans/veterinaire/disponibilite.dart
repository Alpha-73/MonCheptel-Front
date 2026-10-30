/// L'interrupteur « Disponible / Indisponible » du poste de garde.
///
/// Source : PUT /api/veterinaires/disponibilite {disponible}. Un
/// veterinaire indisponible n'est plus choisi par l'orientation automatique.
///
/// Optimiste : l'etat bascule tout de suite (retour au toucher), et revient
/// en arriere si le back refuse ou si le reseau manque.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/client_api.dart';
import '../../api/services.dart';
import '../../theme/palette.dart';
import '../../widgets/vivant.dart';

/// Ce qui enregistre le choix ; rend l'etat retenu par le back.
typedef EnregistrerDisponibilite = Future<bool> Function(bool disponible);

class InterrupteurDisponibilite extends StatefulWidget {
  const InterrupteurDisponibilite({
    super.key,
    required this.disponible,
    this.enregistrer = VeterinaireGardeApi.changerDisponibilite,
    this.surFond = true,
    this.onChange,
  });

  final bool disponible;
  final EnregistrerDisponibilite enregistrer;

  /// Pose sur l'en-tete sombre (texte blanc) ; sinon sur une carte claire.
  final bool surFond;
  final ValueChanged<bool>? onChange;

  @override
  State<InterrupteurDisponibilite> createState() => _InterrupteurDisponibiliteState();
}

class _InterrupteurDisponibiliteState extends State<InterrupteurDisponibilite> {
  late bool _dispo = widget.disponible;
  bool _envoi = false;

  @override
  void didUpdateWidget(InterrupteurDisponibilite old) {
    super.didUpdateWidget(old);
    if (old.disponible != widget.disponible && !_envoi) _dispo = widget.disponible;
  }

  Future<void> _basculer() async {
    if (_envoi) return;
    final voulu = !_dispo;
    HapticFeedback.selectionClick();
    setState(() {
      _dispo = voulu;
      _envoi = true;
    });
    final messager = ScaffoldMessenger.maybeOf(context);
    try {
      final retenu = await widget.enregistrer(voulu);
      if (!mounted) return;
      setState(() => _dispo = retenu);
      widget.onChange?.call(retenu);
      messager?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(retenu
            ? 'Vous êtes disponible : les nouveaux cas vous sont orientés.'
            : 'Vous êtes indisponible : aucun nouveau cas ne vous sera orienté.'),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _dispo = !voulu);
      messager?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Disponibilité non modifiée : ${e.texte}'),
      ));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispo = _dispo;
    final surFond = widget.surFond;
    final fond = dispo
        ? (surFond ? const Color(0x26FFFFFF) : context.couleurs.fondMarquePale)
        : context.couleurs.fondAccentPale;
    final encre = dispo
        ? (surFond ? context.couleurs.surEntete : context.couleurs.marque)
        : context.couleurs.encreFonce;
    final duree = mouvementReduit(context) ? Duration.zero : const Duration(milliseconds: 220);
    return Semantics(
      toggled: dispo,
      button: true,
      label: 'Disponibilité pour les nouveaux cas',
      value: dispo ? 'Disponible' : 'Indisponible',
      onTap: _basculer,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('interrupteur-disponibilite'),
          onTap: _envoi ? null : _basculer,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: duree,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: dispo ? const Color(0x40FFFFFF) : context.couleurs.accent, width: 1.5),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duree,
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dispo ? const Color(0xFF7BE0B8) : context.couleurs.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dispo ? 'Disponible' : 'Indisponible',
                          style: context.typo.corpsFort.copyWith(color: encre)),
                      Text(
                        dispo ? 'Les nouveaux cas vous sont orientés' : 'Aucun nouveau cas orienté',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.legende.copyWith(
                            color: dispo
                                ? (surFond ? context.couleurs.surMarqueDiscret : context.couleurs.texteDiscret)
                                : context.couleurs.encreFonce),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_envoi)
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: encre),
                  ),
                if (_envoi) const SizedBox(width: 8),
                // Le curseur dessine : piste et pastille, l'etat ne repose
                // pas sur la seule couleur (position + libelle).
                AnimatedContainer(
                  duration: duree,
                  width: 52,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  alignment: dispo ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: dispo ? context.couleurs.graviteFaible : context.couleurs.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: context.couleurs.surface, shape: BoxShape.circle),
                    child: Icon(dispo ? Icons.check_rounded : Icons.pause_rounded,
                        size: 16, color: dispo ? context.couleurs.graviteFaible : context.couleurs.encreFonce),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
