/// Les cinq onglets de l'espace eleveur, la barre du bas fixe et son
/// bouton orange « Agir vite ».
///
/// Un onglet est RECONSTRUIT a chaque fois qu'on y revient, donc recharge :
/// une operation saisie depuis l'onglet Santé apparait dans l'Accueil sans
/// geste supplementaire. C'est un aller-retour reseau de plus, et c'est le
/// prix d'une application sans cache a invalider.
///
/// Touche retour d'Android (audit F7) : hors de l'Accueil, elle ramene a
/// l'Accueil au lieu de quitter l'application.
library;

import 'package:flutter/material.dart';

import '../../pousse/pousse.dart';
import '../../widgets/echafaudage.dart';
import '../../widgets/eleveur/pictos.dart';
import 'agir_vite.dart';
import 'animaux/mes_animaux.dart';
import 'conseils/conseils.dart';
import 'profil/profil.dart';
import 'sante/sante_accueil.dart';
import 'tableau_de_bord.dart';

class CoquilleEleveur extends StatefulWidget {
  const CoquilleEleveur({super.key, this.onglets, this.surAction});

  /// Pour les tests : remplace les ecrans des onglets (qui appellent le back).
  @visibleForTesting
  final Widget Function(int index, ValueChanged<int> aller)? onglets;

  /// Pour les tests : recoit l'action choisie dans « Agir vite » au lieu
  /// d'ouvrir l'ecran correspondant.
  @visibleForTesting
  final ValueChanged<ActionRapide>? surAction;

  @override
  State<CoquilleEleveur> createState() => _CoquilleEleveurState();
}

class _CoquilleEleveurState extends State<CoquilleEleveur> {
  int _index = 0;

  /// Change a chaque retour d'un ecran ouvert par « Agir vite » : l'onglet
  /// courant est reconstruit, donc recharge (un lot ajoute apparait).
  int _version = 0;

  @override
  void initState() {
    super.initState();
    // Le telephone recoit desormais les notifications de cet eleveur, meme
    // application fermee (pousse/pousse.dart). Sans session (tests), rien.
    Pousse.instance.activer(role: 'ELEVEUR');
    Pousse.instance.recues.addListener(_surNotification);
  }

  @override
  void dispose() {
    Pousse.instance.recues.removeListener(_surNotification);
    super.dispose();
  }

  /// Notification recue application ouverte : l'Accueil se recharge (cloche,
  /// alertes). Les autres onglets ne bougent pas : on ne fait pas sauter une
  /// liste en cours de lecture.
  void _surNotification() {
    if (mounted && _index == 0) setState(() => _version++);
  }

  Widget _onglet() {
    final test = widget.onglets;
    if (test != null) return test(_index, _aller);
    return switch (_index) {
      0 => TableauDeBordEleveur(versOnglet: _aller),
      1 => const MesAnimaux(),
      2 => const SanteAccueil(),
      3 => const ConseilsListe(),
      _ => const ProfilAccueil(),
    };
  }

  void _aller(int index) => setState(() => _index = index);

  Future<void> _agirVite() async {
    final action = await montrerAgirVite(context);
    if (action == null || !mounted) return;
    if (widget.surAction != null) {
      widget.surAction!(action);
      return;
    }
    await executerAction(context, action);
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _aller(0);
      },
      child: Scaffold(
        // Barre du bas fixe, ancree au bord : le contenu s'arrete
        // au-dessus d'elle (plus de padding de 110 sous les listes).
        body: KeyedSubtree(key: ValueKey((_index, _version)), child: _onglet()),
        bottomNavigationBar: BarreNavigation(
          entrees: navEleveur,
          indexActif: _index,
          onChange: _aller,
          actionCentrale: _agirVite,
          pictogrammes: {
            1: (couleur, actif) => PictoCheptel(taille: 26, couleur: couleur, plein: actif),
          },
        ),
      ),
    );
  }
}
