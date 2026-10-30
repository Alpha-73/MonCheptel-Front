/// Maquette : « Veterinaires - Liste », sa pop-up « Appel » et
/// « Veterinaire - Fiche ».
///
/// Source : GET /api/veterinaires (zone de l'eleveur par defaut).
///
/// Ecart assume : la fiche de la maquette montre aussi les filieres, un
/// « délai moyen de réponse » et les maladies traitees. Le back ne les
/// expose pas dans `VeterinaireResumeReponse` ; la fiche s'en tient a ce
/// qui existe plutot que d'afficher des valeurs inventees.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/mise_en_page.dart';

class EcranVeterinaires extends StatelessWidget {
  const EcranVeterinaires({super.key});

  @override
  Widget build(BuildContext context) => Chargeur<List<VeterinaireResume>>(
        titreEcran: 'Vétérinaires',
        charger: () => ReferentielApi.veterinaires(),
        construire: (context, vets, recharger) => EcranVivant(
          titre: 'Annuaire des vétérinaires',
          sousTitre: 'Votre zone',
          corps: RefreshIndicator(
            onRefresh: recharger,
            color: context.couleurs.marque,
            child: vets.isEmpty
                ? ListView(padding: lisible(context), physics: const AlwaysScrollableScrollPhysics(), children: const [
                    EtatVide('Aucun vétérinaire enregistré dans votre zone pour le moment.'),
                  ])
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
                    children: [
                      for (final v in vets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CarteVeterinaire(
                            veterinaire: v,
                            onTap: () =>
                                ouvrir<void>(context, EcranFicheVeterinaire(veterinaire: v)),
                            onAppeler: () => confirmerAppel(context, v.nom, v.telephone),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      );
}

/// Ligne d'annuaire : initiales, nom, specialite — zone, bouton Appeler.
class CarteVeterinaire extends StatelessWidget {
  const CarteVeterinaire({super.key, required this.veterinaire, this.onTap, this.onAppeler});
  final VeterinaireResume veterinaire;
  final VoidCallback? onTap;
  final VoidCallback? onAppeler;

  @override
  Widget build(BuildContext context) {
    final v = veterinaire;
    final detail = [
      if (v.specialite != null) v.specialite!,
      if (v.zoneIntervention != null) v.zoneIntervention!,
    ].join(' — ');
    return Carte(
      onTap: onTap,
      enfant: Row(
        children: [
          Avatar(Fmt.initiales(v.nom), taille: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.nom, style: context.typo.corpsFort),
                if (detail.isNotEmpty) Text(detail, style: context.typo.legende),
                if (!v.disponible)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Pastille('Indisponible'),
                  ),
              ],
            ),
          ),
          if (onAppeler != null)
            BoutonSecondaire('Appeler', pleineLargeur: false, onPressed: onAppeler),
        ],
      ),
    );
  }
}

class EcranFicheVeterinaire extends StatelessWidget {
  const EcranFicheVeterinaire({super.key, required this.veterinaire});
  final VeterinaireResume veterinaire;

  @override
  Widget build(BuildContext context) {
    final v = veterinaire;
    return EcranVivant(
      titre: 'Vétérinaire',
      corps: ListView(
        padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
        children: [
          Carte(
            enfant: Column(
              children: [
                Avatar(Fmt.initiales(v.nom), taille: 64),
                const SizedBox(height: 10),
                Text(v.nom, style: context.typo.titreSection, textAlign: TextAlign.center),
                if (v.titre != null) Text(v.titre!, style: context.typo.corpsDiscret),
                const SizedBox(height: 12),
                if (v.zoneIntervention != null)
                  LigneValeur("Zone d'intervention", v.zoneIntervention!),
                if (v.specialite != null) LigneValeur('Spécialité', v.specialite!),
                LigneValeur('Téléphone', v.telephone ?? 'Non renseigné'),
                LigneValeur('Disponibilité', v.disponible ? 'Disponible' : 'Indisponible'),
              ],
            ),
          ),
        ],
      ),
      pied: BoutonPrincipal('Appeler ce vétérinaire',
          icone: Icons.call,
          onPressed: v.telephone == null ? null : () => appeler(context, v.telephone)),
    );
  }
}
