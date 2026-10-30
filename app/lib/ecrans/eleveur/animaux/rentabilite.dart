/// Maquette : « Rentabilite - Par entree 45 j » et « Par periode 1 an ».
///
/// Sources :
///   GET /api/finances/rentabilite/{id}   revenus, depenses et solde de TOUTES
///                                        les operations rattachees a l'unite
///   GET /api/finances/operations         le detail de ces operations
///   GET /api/types-elevage?filiere=X     le mode d'evaluation du type
///
/// Ecart assume avec la maquette : le back calcule la rentabilite depuis
/// l'entree de l'unite, pas sur une periode decoupee (« ouverte le 1 juil. »).
/// L'ecran le dit tel quel plutot que d'afficher des bornes de periode
/// que le calcul n'utilise pas.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/vivant.dart';
import '../finances/operations.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Donnees = ({Solde solde, List<Operation> operations, TypeElevage? type});

class EcranRentabilite extends StatelessWidget {
  const EcranRentabilite({super.key, required this.unite});
  final Unite unite;

  Future<_Donnees> _charger() async {
    // Pas de borne a l'entree : le back somme TOUTES les operations de
    // l'unite, y compris un achat date d'avant la mise en place. La liste
    // doit montrer les memes lignes que le solde.
    final debut = DateTime(2000);
    final reponses = await Future.wait([
      FinanceApi.rentabilite(unite.id),
      FinanceApi.operations(debut: debut, fin: DateTime.now(), filiere: unite.filiere),
      ReferentielApi.typesElevage(filiere: unite.filiere),
    ]);
    TypeElevage? type;
    for (final t in reponses[2] as List<TypeElevage>) {
      if (t.id == unite.typeElevageId) type = t;
    }
    return (
      solde: reponses[0] as Solde,
      operations: (reponses[1] as List<Operation>)
          .where((o) => o.uniteId == unite.id)
          .toList(),
      type: type,
    );
  }

  @override
  Widget build(BuildContext context) => Chargeur<_Donnees>(
        titreEcran: 'Rentabilité',
        charger: _charger,
        construire: (context, d, recharger) => EcranSecondaire(
          titre: 'Rentabilité',
          sousTitre: unite.code,
          corps: RefreshIndicator(
            onRefresh: recharger,
            color: context.couleurs.marque,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, Dim.gouttiere, Dim.gouttiere, 32)),
              children: _contenu(context, d),
            ),
          ),
        ),
      );

  List<Widget> _contenu(BuildContext context, _Donnees d) {
    // Audit F6 : on se fonde sur la duree de cycle, pas sur le nom de
    // l'enumeration (PAR_ENTREE / PAR_PERIODE sont inverses cote back).
    final duree = d.type?.dureeCycleJours;
    final parCycle = duree != null;
    final jour = unite.dateEntree == null
        ? null
        : DateTime.now().difference(unite.dateEntree!).inDays;
    final s = d.solde;
    final total = s.revenus + s.depenses;

    return [
      Text(
        unite.estLot ? 'Cycle en cours · ${unite.code}' : '${L.filiere(unite.filiere)} · ${unite.code}',
        style: context.typo.titreSection,
      ),
      const SizedBox(height: 4),
      Text(
        [
          '${unite.estLot ? 'Mise en place' : 'Entrée'} le ${Fmt.date(unite.dateEntree)}',
          if (jour != null && duree != null) 'jour $jour sur $duree',
        ].join(' · '),
        style: context.typo.corpsDiscret,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.couleurs.fondFonce,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.solde >= 0 ? 'Bénéfice' : 'Perte',
                style: context.typo.legendeForte.copyWith(color: context.couleurs.surMarqueDiscret)),
            CompteurAnime(
              valeur: s.solde,
              style: context.typo.chiffreHeros.copyWith(color: context.couleurs.surEntete),
              format: (n) => Fmt.fcfa(n, signe: true),
            ),
            const SizedBox(height: 14),
            // Barre gagne / depense : la part de chacun dans l'argent remue.
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: total == 0
                    ? const ColoredBox(color: Color(0x33FFFFFF))
                    : Row(children: [
                        Expanded(
                            flex: s.revenus,
                            child: ColoredBox(color: context.couleurs.graviteFaible)),
                        Expanded(
                            flex: s.depenses,
                            child: ColoredBox(color: context.couleurs.accent)),
                      ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text('Gagné\n${Fmt.fcfa(s.revenus)}',
                    style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
              ),
              Expanded(
                child: Text('Dépensé\n${Fmt.fcfa(s.depenses)}',
                    textAlign: TextAlign.right,
                    style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
              ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (unite.dateCloturePrevue != null)
        Note('Fin du cycle prévue le ${Fmt.date(unite.dateCloturePrevue)}.',
            icone: Icons.event_outlined),
      Note(parCycle
          ? 'Se juge à la fin de chaque cycle de $duree jours.'
          : 'Se juge sur une année entière.'),
      const Note("Sans les dépenses communes à toute la ferme (non rattachées à cet élevage)."),
      const SizedBox(height: 8),
      Text('Détail des opérations', style: context.typo.titreSection),
      const SizedBox(height: 8),
      if (d.operations.isEmpty)
        const EtatVide('Aucune opération rattachée à cet élevage.')
      else
        for (final o in d.operations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LigneOperation(operation: o),
          ),
    ];
  }
}
