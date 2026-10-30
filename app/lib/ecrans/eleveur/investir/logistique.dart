/// Maquette : « Logistique - Volaille / Bovins / Ovins / Caprins ».
///
/// Source : GET /api/types-elevage?filiere=X — les parametres du
/// referentiel, tels que l'administration les a saisis.
///
/// Les couts ne sont pas recalcules ici : le simulateur les chiffre a
/// partir du budget. Le bouton « Simuler » y renvoie.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/palette.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/eleveur/onglets_filiere.dart';
import '../../../widgets/pastille.dart';
import 'investir.dart';
import '../../../widgets/mise_en_page.dart';

class EcranLogistique extends StatefulWidget {
  const EcranLogistique({super.key, this.filiere = 'VOLAILLE'});
  final String filiere;

  @override
  State<EcranLogistique> createState() => _EcranLogistiqueState();
}

class _EcranLogistiqueState extends State<EcranLogistique> {
  late String _filiere = widget.filiere;

  @override
  Widget build(BuildContext context) => EcranSecondaire(
        titre: 'Logistique',
        sousTitre: "Ce qu'il faut pour se lancer",
        corps: Column(
          children: [
            const SizedBox(height: 12),
            OngletsFiliere(
              filieres: L.filieres,
              active: _filiere,
              onChange: (f) => setState(() => _filiere = f ?? _filiere),
            ),
            Expanded(
              child: Chargeur<List<TypeElevage>>(
                key: ValueKey(_filiere),
                charger: () => ReferentielApi.typesElevage(filiere: _filiere),
                construire: (context, types, _) => ListView(
                  padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
                  children: [
                    if (types.isEmpty)
                      const EtatVide("Aucun type d'élevage renseigné pour cette filière."),
                    for (final t in types)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CarteType(type: t),
                      ),
                    const Note('Estimations indicatives, mises à jour par l’administration.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        pied: BoutonPrincipal('Simuler avec mon budget',
            onPressed: () => ouvrir<void>(context, const EcranInvestir())),
      );
}

String _nombre(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');

class _CarteType extends StatelessWidget {
  const _CarteType({required this.type});
  final TypeElevage type;

  @override
  Widget build(BuildContext context) {
    final t = type;
    final temperature = (t.temperatureMin != null && t.temperatureMax != null)
        ? '${t.temperatureMin} à ${t.temperatureMax} °C'
        : null;
    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(t.libelle, style: context.typo.titreSection)),
            Pastille(L.difficulte(t.difficulte), ton: L.tonDifficulte(t.difficulte)),
          ]),
          Text(
            t.dureeCycleJours == null
                ? 'Rentabilité évaluée sur un an'
                : 'Cycle de ${t.dureeCycleJours} jours',
            style: context.typo.corpsDiscret,
          ),
          const SizedBox(height: 10),
          Text("Ce qu'il faut pour démarrer", style: context.typo.corpsFort),
          if (t.espaceParSujetM2 != null)
            LigneValeur('Espace', '${_nombre(t.espaceParSujetM2!)} m² par sujet'),
          if (temperature != null) LigneValeur('Température', temperature),
          if (t.alimentParSujetKg != null)
            LigneValeur('Aliment', '${_nombre(t.alimentParSujetKg!)} kg par sujet'),
          if (t.eauParSujetJourL != null)
            LigneValeur('Eau', '${_nombre(t.eauParSujetJourL!)} L par sujet et par jour'),
          if (t.vaccinsObligatoires != null && t.vaccinsObligatoires!.isNotEmpty)
            LigneValeur('Vaccins', t.vaccinsObligatoires!),
          if (t.tauxMortalite != null)
            LigneValeur('Mortalité habituelle',
                '${_nombre(t.tauxMortalite! * 100)} %'),
        ],
      ),
    );
  }
}
