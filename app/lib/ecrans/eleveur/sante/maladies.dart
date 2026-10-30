/// Maquette : « Catalogue - Liste » et « Maladie - Fiche ».
///
/// Source : GET /api/signalements/maladies — le catalogue VU PAR L'ELEVEUR :
/// le back y masque le traitement des maladies qui exigent un veterinaire.
///
/// Ecart assume : la fiche de la maquette affiche « Vétérinaires
/// compétents 3 », « Cas signalés ce mois 38 ». Aucune route eleveur ne
/// rend ces chiffres ; ils ne sont pas affiches plutot qu'inventes.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import 'signalement.dart';
import 'veterinaires.dart';
import '../../../widgets/mise_en_page.dart';

class EcranCatalogueMaladies extends StatelessWidget {
  const EcranCatalogueMaladies({super.key});

  @override
  Widget build(BuildContext context) => Chargeur<List<Maladie>>(
        titreEcran: 'Catalogue des maladies',
        charger: () => SignalementApi.maladies(),
        construire: (context, maladies, _) => EcranVivant(
          titre: 'Catalogue des maladies',
          corps: ListView(
            padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
            children: [
              Text('Les maladies suivies par MonCheptel, avec leurs signes.',
                  style: context.typo.corpsDiscret),
              const SizedBox(height: 12),
              if (maladies.isEmpty) const EtatVide('Le catalogue est vide.'),
              for (final m in maladies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Carte(
                    onTap: () => ouvrir<void>(context, EcranFicheMaladie(maladie: m)),
                    enfant: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.nom, style: context.typo.corpsFort),
                              const SizedBox(height: 4),
                              Text(L.trierFilieres(m.filieres).map(L.filiere).join(', '),
                                  style: context.typo.legende),
                            ],
                          ),
                        ),
                        Pastille(L.gravite(m.gravite), ton: L.tonGravite(m.gravite)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: context.couleurs.texteDiscret),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class EcranFicheMaladie extends StatelessWidget {
  const EcranFicheMaladie({super.key, required this.maladie});
  final Maladie maladie;

  @override
  Widget build(BuildContext context) {
    final m = maladie;
    return EcranVivant(
      titre: m.nom,
      sousTitre: L.trierFilieres(m.filieres).map(L.filiere).join(', '),
      corps: ListView(
        padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
        children: [
          Row(children: [
            Pastille(L.graviteLongue(m.gravite), ton: L.tonGravite(m.gravite)),
          ]),
          const SizedBox(height: 16),
          if (m.symptomesTexte != null && m.symptomesTexte!.trim().isNotEmpty) ...[
            Text('SYMPTÔMES PRINCIPAUX', style: context.typo.legendeForte),
            const SizedBox(height: 6),
            Carte(enfant: Text(m.symptomesTexte!, style: context.typo.corps)),
            const SizedBox(height: 16),
          ],
          if (m.orienteVersVeterinaire)
            Encart(
              titre: 'Un vétérinaire doit intervenir',
              detail: '${L.graviteLongue(m.gravite)} : aucun traitement n’est proposé ici. '
                  'Signalez le cas : l’application vous met en relation avec un '
                  'vétérinaire compétent de votre zone.',
              ton: TonEncart.erreur,
            )
          else if (m.traitement != null) ...[
            Text('TRAITEMENT DE PREMIÈRE INTENTION', style: context.typo.legendeForte),
            const SizedBox(height: 6),
            Carte(enfant: Text(m.traitement!, style: context.typo.corps)),
            const SizedBox(height: 8),
            const Note('Si les signes persistent, contactez un vétérinaire.'),
          ],
        ],
      ),
      pied: Row(
        children: [
          Expanded(
            child: BoutonSecondaire('Vétérinaires',
                onPressed: () => ouvrir<void>(context, const EcranVeterinaires())),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BoutonPrincipal('Signaler cette maladie',
                onPressed: () => ouvrir<void>(context, const EcranSignalementChoix())),
          ),
        ],
      ),
    );
  }
}
