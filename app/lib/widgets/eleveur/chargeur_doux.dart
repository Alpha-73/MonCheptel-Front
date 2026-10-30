/// Chargeur qui GARDE l'ecran pendant un rechargement (audit F17).
///
/// Le [Chargeur] commun repart de zero quand sa cle change : changer
/// d'onglet de filiere effacait tout l'ecran et montrait un rond qui tourne.
/// Ici, au premier chargement on montre un [squelette] ; ensuite, les
/// dernieres donnees restent affichees et [construire] recoit `enCours`
/// pour poser une fine barre de progression.
library;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../etats.dart';

class ChargeurDoux<T> extends StatefulWidget {
  const ChargeurDoux({
    super.key,
    required this.charger,
    required this.construire,
    required this.squelette,
    this.cle,
  });

  final Future<T> Function() charger;

  /// Quand elle change (la filiere affichee), on recharge sans effacer.
  final Object? cle;

  final Widget squelette;

  final Widget Function(
          BuildContext context, T donnee, Future<void> Function() recharger, bool enCours)
      construire;

  @override
  State<ChargeurDoux<T>> createState() => _ChargeurDouxState<T>();
}

class _ChargeurDouxState<T> extends State<ChargeurDoux<T>> {
  T? _donnee;
  Object? _erreur;
  bool _enCours = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  @override
  void didUpdateWidget(covariant ChargeurDoux<T> ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.cle != widget.cle) _recharger();
  }

  Future<void> _recharger() async {
    // Une reponse lente d'un onglet quitte ne doit pas ecraser la suivante.
    final g = ++_generation;
    if (mounted) {
      setState(() {
        _enCours = true;
        _erreur = null;
      });
    }
    try {
      final d = await widget.charger();
      if (!mounted || g != _generation) return;
      setState(() {
        _donnee = d;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _enCours = false;
      });
      // Donnees deja a l'ecran : on les garde et on previent sans bloquer.
      if (_donnee != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Pas de connexion : données du dernier chargement.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _donnee;
    if (d == null) {
      if (_erreur != null) return EtatErreur(erreur: _erreur!, onReessayer: _recharger);
      return widget.squelette;
    }
    return widget.construire(context, d, _recharger, _enCours);
  }
}

/// La fine barre de progression a poser en haut d'une liste qui se recharge.
class BarreRechargement extends StatelessWidget {
  const BarreRechargement({super.key, required this.actif});
  final bool actif;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 3,
        child: actif
            ? LinearProgressIndicator(
                minHeight: 3,
                color: context.couleurs.accent,
                backgroundColor: context.couleurs.fondAccentPale,
              )
            : null,
      );
}
