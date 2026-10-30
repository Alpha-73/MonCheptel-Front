/// Maquette : « Alerte - Detail ».
///
/// L'alerte elle-meme vient du tableau de bord (deja chargee). L'ecran
/// ajoute ce qui concerne l'eleveur : ses unites actives de la filiere
/// visee (GET /api/cheptel?filiere=X&statut=ACTIF), et la fiche de la
/// maladie (GET /api/signalements/maladies, rapprochee par le nom : l'alerte
/// ne porte que le nom de la maladie, pas son identifiant).
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import 'maladies.dart';
import 'veterinaires.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Donnees = ({List<Unite> exposees, Maladie? maladie});

class EcranAlerte extends StatelessWidget {
  const EcranAlerte({super.key, required this.alerte});
  final Alerte alerte;

  Future<_Donnees> _charger() async {
    final reponses = await Future.wait([
      CheptelApi.lister(filiere: alerte.filiere, statut: 'ACTIF'),
      SignalementApi.maladies(filiere: alerte.filiere),
    ]);
    Maladie? maladie;
    for (final m in reponses[1] as List<Maladie>) {
      if (m.nom == alerte.maladie) maladie = m;
    }
    return (exposees: reponses[0] as List<Unite>, maladie: maladie);
  }

  @override
  Widget build(BuildContext context) {
    final a = alerte;
    return Chargeur<_Donnees>(
      titreEcran: 'Alerte sanitaire',
      charger: _charger,
      construire: (context, d, _) {
        final lots = d.exposees.where((u) => u.estLot).length;
        final animaux = d.exposees.length - lots;
        final tetes = d.exposees.fold<int>(0, (s, u) => s + u.effectifRestant);
        final exposition = d.exposees.isEmpty
            ? 'Aucun élevage exposé'
            : [
                if (lots > 0) '$lots lot${lots > 1 ? 's' : ''}',
                if (animaux > 0) '$animaux ${animaux > 1 ? 'animaux' : 'animal'}',
                Fmt.tetes(tetes),
              ].join(' · ');

        return EcranVivant(
          titre: 'Alerte sanitaire',
          corps: ListView(
            padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.couleurs.fondErreurPale,
                  borderRadius: BorderRadius.circular(Dim.rayon),
                  border: Border(
                      left: BorderSide(color: context.couleurs.erreur, width: Dim.bordureEncart)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ALERTE ÉPIDÉMIE',
                        style: context.typo.legendeForte.copyWith(color: context.couleurs.erreur)),
                    const SizedBox(height: 6),
                    Text(a.maladie, style: context.typo.chiffre.copyWith(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                        a.dateDeclenchement != null &&
                                DateTime.now().difference(a.dateDeclenchement!).inDays >= 7
                            ? 'Déclenchée le ${Fmt.date(a.dateDeclenchement)}'
                            : 'Déclenchée ${Fmt.ilYA(a.dateDeclenchement).toLowerCase()}',
                        style: context.typo.legende),
                    if (a.dateFin != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.event_rounded, size: 20, color: context.couleurs.erreur),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text("Alerte jusqu'au ${Fmt.dateLongue(a.dateFin)}",
                                style: context.typo.corpsFort),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Carte(
                enfant: Column(
                  children: [
                    LigneValeur('Zone concernée', a.zone),
                    LigneValeur('Filière', a.filiere == null ? 'Toutes' : L.filiere(a.filiere)),
                    if (a.dateFin != null) LigneValeur('Fin prévue', Fmt.date(a.dateFin)),
                    LigneValeur('Éleveurs prévenus', Fmt.montant(a.portee)),
                    LigneValeur('Vos élevages exposés', exposition, fort: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Que faire ?', style: context.typo.titreSection),
              const SizedBox(height: 6),
              Carte(enfant: Text(a.message, style: context.typo.corps)),
              const SizedBox(height: 8),
              const Note('Cette alerte a été envoyée par notification à tous les '
                  'éleveurs de la zone et de la filière concernées.'),
            ],
          ),
          pied: Row(
            children: [
              if (d.maladie != null) ...[
                Expanded(
                  child: BoutonSecondaire('Voir la maladie',
                      onPressed: () =>
                          ouvrir<void>(context, EcranFicheMaladie(maladie: d.maladie!))),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: BoutonPrincipal('Contacter un vétérinaire',
                    onPressed: () => ouvrir<void>(context, const EcranVeterinaires())),
              ),
            ],
          ),
        );
      },
    );
  }
}
