/// Les quatre onglets de l'espace veterinaire et la barre du bas :
/// Accueil, Éleveurs, Conseils, Profil.
///
/// Meme principe que l'espace eleveur (voir coquille_eleveur.dart) : un
/// onglet est reconstruit, donc recharge, a chaque visite.
library;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../pousse/pousse.dart';
import '../../widgets/echafaudage.dart';
import 'accueil_veterinaire.dart';
import 'commun_veterinaire.dart';
import 'demandes.dart';
import 'mes_conseils.dart';
import 'profil_veterinaire.dart';

class CoquilleVeterinaire extends StatefulWidget {
  const CoquilleVeterinaire({super.key});

  @override
  State<CoquilleVeterinaire> createState() => _CoquilleVeterinaireState();
}

class _CoquilleVeterinaireState extends State<CoquilleVeterinaire> {
  int _index = OngletVeto.accueil;

  /// Sous-onglet de la file a l'ouverture (« Traités » depuis l'accueil).
  int _ongletFile = OngletFile.attente;

  /// Change a chaque notification recue application ouverte : l'onglet
  /// courant est reconstruit, donc recharge.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    // Le telephone recoit les nouveaux cas meme application fermee
    // (pousse/pousse.dart).
    Pousse.instance.activer(role: 'VETERINAIRE');
    Pousse.instance.recues.addListener(_surNotification);
  }

  @override
  void dispose() {
    Pousse.instance.recues.removeListener(_surNotification);
    super.dispose();
  }

  /// Un nouveau cas arrive : l'Accueil et la file des demandes se
  /// rechargent ; le Profil et les Conseils ne bougent pas.
  void _surNotification() {
    if (!mounted) return;
    if (_index == OngletVeto.accueil || _index == OngletVeto.eleveurs) {
      setState(() => _version++);
    }
  }

  Widget _onglet() => switch (_index) {
        OngletVeto.accueil =>
          TableauDeBordVeterinaire(versOnglet: _aller, versTraites: _versTraites),
        OngletVeto.eleveurs => EleveursOrientes(versOnglet: _aller, ongletInitial: _ongletFile),
        OngletVeto.conseils => const MesConseils(),
        _ => const ProfilVeterinaire(),
      };

  void _aller(int index) => setState(() {
        _index = index;
        _ongletFile = OngletFile.attente;
      });

  void _versTraites() => setState(() {
        _index = OngletVeto.eleveurs;
        _ongletFile = OngletFile.traites;
      });

  @override
  Widget build(BuildContext context) {
    // Retour Android : hors de l'Accueil, il ramene a l'Accueil au lieu de
    // quitter l'application — comme l'espace eleveur (audit du 10 octobre).
    return PopScope(
      canPop: _index == OngletVeto.accueil,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _aller(OngletVeto.accueil);
      },
      // Barre du bas fixe : le contenu s'arrete au-dessus d'elle.
      child: Scaffold(
        backgroundColor: context.couleurs.fond,
        body: KeyedSubtree(key: ValueKey((_index, _ongletFile, _version)), child: _onglet()),
        bottomNavigationBar: BarreNavigation(
          entrees: navVeterinaire,
          indexActif: _index,
          onChange: _aller,
        ),
      ),
    );
  }
}
