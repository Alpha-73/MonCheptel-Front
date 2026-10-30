/// Le carnet d'un lot ou d'un animal : son identite, son cycle, ses soins,
/// ses entrees et sorties, son argent.
///
/// Source : GET /api/cheptel/{id}, qui rend en une fois l'unite, ses
/// mouvements, ses sorties annulables, ses evenements sanitaires, ses
/// rappels et sa rentabilite.
///
/// Gestes :
///  - barre fixe en bas, une famille de gestes par bouton : Événement
///    sanitaire (soins, signaler une maladie) · Changer le statut (vente,
///    mort, transfert) · Opération (dépense, revenu) ;
///  - toucher une vente, une mort ou un transfert : l'annuler, avec
///    confirmation (audit F1, DELETE /api/cheptel/{id}/sorties/{sortieId}) ;
///  - « Clôturer le lot » : terminer un lot qui a encore des tetes, en fin
///    de cycle par exemple (audit F2, POST /api/cheptel/{id}/cloture) ;
///  - un acte saisi par un veterinaire est en lecture seule (audit F14).
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/echafaudage.dart';
import '../../../widgets/eleveur/pictos.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import '../finances/operation_form.dart';
import '../tableau_de_bord.dart' show CarteRappel;
import 'evenement.dart';
import 'mes_animaux.dart';
import 'modifier_unite.dart';
import 'rentabilite.dart';
import '../../../widgets/mise_en_page.dart';

typedef DonneesCarnet = ({DetailUnite detail, List<SortieUnite> sorties});

/// Titre et texte de la pop-up « Clôturer » quand il reste des tetes
/// (audit global G5).
@visibleForTesting
(String, String) messageClotureAvecTetes(Unite u) => u.estLot
    ? (
        '${u.code} compte encore ${Fmt.tetes(u.effectifRestant)}',
        'Pour le clôturer, dites ce qu’elles sont devenues : vendues, mortes ou '
            'transférées. Vos comptes resteront justes, et le lot se clôture tout seul.',
      )
    : (
        'Clôturer la fiche de ${u.code} ?',
        'Vendu, mort ou transféré ? Enregistrez sa sortie : la fiche se clôture '
            'd’elle-même.',
      );

/// « cette vente », « cette perte », « ce transfert ».
String _ceMouvement(String type) => switch (type) {
      'VENTE' => 'cette vente',
      'MORT' => 'cette perte',
      'TRANSFERT' => 'ce transfert',
      _ => 'cette sortie',
    };

class EcranCarnet extends StatelessWidget {
  const EcranCarnet({super.key, required this.uniteId, this.charger});
  final int uniteId;

  /// Pour les tests : remplace GET /api/cheptel/{id}.
  @visibleForTesting
  final Future<DonneesCarnet> Function()? charger;

  @override
  Widget build(BuildContext context) {
    return Chargeur<DonneesCarnet>(
      titreEcran: 'Carnet',
      charger: charger ?? () => CarnetApi.detail(uniteId),
      construire: (context, d, recharger) =>
          _Carnet(detail: d.detail, sorties: d.sorties, recharger: recharger),
    );
  }
}

class _Carnet extends StatelessWidget {
  const _Carnet({required this.detail, required this.sorties, required this.recharger});
  final DetailUnite detail;
  final List<SortieUnite> sorties;
  final Future<void> Function() recharger;

  Unite get u => detail.unite;

  @override
  Widget build(BuildContext context) {
    Future<void> puisRecharger(Widget ecran) async {
      final resultat = await ouvrir<Object?>(context, ecran);
      // L'ecran de modification rend `true` quand l'unite a ete SUPPRIMEE :
      // le carnet n'a plus rien a montrer, on remonte a la liste.
      if (resultat == true && context.mounted) {
        Navigator.of(context).pop();
        return;
      }
      await recharger();
    }

    final c = u.estActif ? cycleDe(u) : null;
    final depasse = c != null && (c.joursRestants ?? 0) <= 0;
    final rappels =
        detail.rappels.where((r) => r.statut == 'A_VENIR' || r.statut == 'ECHU').toList()
          ..sort((a, b) => a.joursRestants.compareTo(b.joursRestants));

    var rang = 0;
    Widget entree(Widget enfant) => Apparition(rang: rang++, child: enfant);

    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Column(
        children: [
          EnteteVivant(
            retour: true,
            titre: u.code,
            sousTitre: '${L.filiere(u.filiere)} · ${u.typeElevage}',
            aDroite: u.estActif
                ? BoutonEntete(
                    icone: Icons.edit_outlined,
                    libelle: 'Modifier',
                    onTap: () => puisRecharger(EcranModifierUnite(unite: u)),
                  )
                : null,
            bas: _Heros(unite: u),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: recharger,
              color: context.couleurs.marque,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: lisible(context, const EdgeInsets.only(top: 8, bottom: 24)),
                children: [
                  if (u.note != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 0),
                      child: Row(children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 18, color: context.couleurs.texteDiscret),
                        const SizedBox(width: 6),
                        Expanded(child: Text(u.note!, style: context.typo.corpsDiscret)),
                      ]),
                    ),
                  // Audit F21 : un cycle fini se voit, et se termine.
                  if (depasse)
                    entree(Padding(
                      padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 0),
                      child: _CycleTermine(
                        jours: -(c.joursRestants ?? 0),
                        onVendre: () =>
                            puisRecharger(EcranChangerStatut(unite: u, type: 'VENTE')),
                        onCloturer: () => _cloturer(context),
                      ),
                    )),
                  if (rappels.isNotEmpty) ...[
                    const TitreSectionVivant('À faire'),
                    for (final r in rappels)
                      entree(Padding(
                        padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 10),
                        child: CarteRappel(rappel: r, onTap: () => _surRappel(context, r)),
                      )),
                  ],
                  const SizedBox(height: 8),
                  entree(Gouttiere(
                    enfant: _CarteSolde(
                      unite: u,
                      solde: detail.rentabilite,
                      onTap: () => puisRecharger(EcranRentabilite(unite: u)),
                    ),
                  )),
                  TitreSectionVivant(
                    'Historique',
                    action: u.estActif ? '+ Noter un soin' : null,
                    onAction: () => puisRecharger(EcranAjouterEvenement(unite: u)),
                  ),
                  Gouttiere(
                    enfant: _Frise(
                      entrees: _entreesFrise(context, puisRecharger),
                    ),
                  ),
                  if (u.estActif) ...[
                    const SizedBox(height: 20),
                    Gouttiere(
                      enfant: BoutonSecondaire(
                        u.estLot ? 'Clôturer le lot' : 'Clôturer la fiche',
                        icone: Icons.flag_outlined,
                        onPressed: () => _cloturer(context),
                      ),
                    ),
                    if (u.estLot)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 0),
                        child: Text('À zéro tête, le lot se termine tout seul.',
                            style: context.typo.legende, textAlign: TextAlign.center),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !u.estActif
          ? null
          : _BarreActions(
              actions: [
                (
                  'Événement sanitaire',
                  Icons.health_and_safety_outlined,
                  context.couleurs.fondErreurPale,
                  context.couleurs.erreur,
                  () => puisRecharger(EcranAjouterEvenement(unite: u)),
                ),
                (
                  'Changer le statut',
                  Icons.sync_alt_rounded,
                  context.couleurs.sable,
                  context.couleurs.encreFonce,
                  () => puisRecharger(EcranChangerStatut(unite: u)),
                ),
                (
                  'Opération',
                  Icons.payments_outlined,
                  context.couleurs.fondAccentPale,
                  context.couleurs.attentionTexte,
                  () => puisRecharger(EcranOperation(filiere: u.filiere)),
                ),
              ],
            ),
    );
  }

  /// Soins et mouvements, du plus recent au plus ancien.
  List<_EntreeFrise> _entreesFrise(
      BuildContext context, Future<void> Function(Widget) puisRecharger) {
    final parId = {for (final s in sorties) s.id: s};
    final liste = <_EntreeFrise>[
      for (final e in detail.evenements)
        _EntreeFrise(
          date: e.dateEvenement,
          icone: switch (e.type) {
            'VACCINATION' => Icons.vaccines_outlined,
            'TRAITEMENT' => Icons.medication_outlined,
            'MALADIE' => Icons.sick_outlined,
            _ => Icons.medical_services_outlined,
          },
          couleur: e.type == 'MALADIE' ? context.couleurs.erreur : context.couleurs.sante,
          titre: L.typeEvenement(e.type),
          detail: e.produitObservation,
          auteur: e.veterinaire == null ? null : 'par ${e.veterinaire}',
          // Audit F14 : l'acte d'un veterinaire ne se modifie pas ici.
          onTap: u.estActif && e.veterinaire == null
              ? () => puisRecharger(EcranModifierEvenement(evenement: e))
              : null,
          indice: u.estActif && e.veterinaire == null ? Icons.edit_outlined : null,
        ),
      for (final m in detail.mouvements)
        _EntreeFrise(
          date: m.dateMouvement,
          icone: m.estEntree ? Icons.login_rounded : Icons.logout_rounded,
          couleur: m.estEntree
              ? context.couleurs.marque
              : m.type == 'MORT'
                  ? context.couleurs.texteDiscret
                  : context.couleurs.attentionTexte,
          titre: [
            L.typeMouvement(m.type),
            if (u.estLot) '${m.estEntree ? '+' : '−'} ${Fmt.tetes(m.nombreTetes)}',
          ].join(' · '),
          detail: [
            if (parId[m.id]?.montant != null) Fmt.fcfa(parId[m.id]!.montant!, signe: true),
            if (m.motif != null) m.motif!,
          ].join(' · '),
          onTap: m.estEntree ? null : () => _annulerSortie(context, m, parId[m.id]),
          indice: m.estEntree ? null : Icons.undo_rounded,
        ),
    ];
    liste.sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
    return liste;
  }

  Future<void> _annulerSortie(BuildContext context, Mouvement m, SortieUnite? s) async {
    final quoi = _ceMouvement(m.type);
    final retour = u.estLot
        ? '${Fmt.tetes(m.nombreTetes)} reviendront dans ${u.code}.'
        : '${u.code} reviendra dans votre cheptel.';
    final ok = await confirmer(
      context,
      'Annuler $quoi ?',
      message: [
        retour,
        if (m.type == 'VENTE') 'Le revenu de la vente sera retiré de vos comptes.',
      ].join(' '),
      confirmer: 'Oui, annuler',
      annuler: 'Garder',
      destructif: true,
    );
    if (!ok || !context.mounted) return;
    try {
      // Contrat : sortieId = id du mouvement de sortie.
      await CarnetApi.annulerSortie(u.id, s?.id ?? m.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(switch (m.type) {
        'VENTE' => 'Vente annulée.',
        'MORT' => 'Perte annulée.',
        'TRANSFERT' => 'Transfert annulé.',
        _ => 'Sortie annulée.',
      })));
      await recharger();
    } on ApiException catch (e) {
      if (context.mounted) await afficherErreur(context, e);
    }
  }

  Future<void> _cloturer(BuildContext context) async {
    // Audit global G5 : des tetes encore presentes ne disparaissent pas des
    // comptes. On demande ce qu'elles sont devenues ; leur sortie clot
    // l'elevage d'elle-meme.
    if (u.effectifRestant > 0) {
      final suite = await choisirSuite(
        context,
        messageClotureAvecTetes(u).$1,
        message: messageClotureAvecTetes(u).$2,
        premier: u.estLot ? 'Enregistrer leur sortie' : 'Enregistrer sa sortie',
        second: 'Annuler',
      );
      if (suite != true || !context.mounted) return;
      await ouvrir<Object?>(
          context, EcranChangerStatut(unite: u, type: 'VENTE', toutesLesTetes: true));
      await recharger();
      return;
    }
    final ok = await confirmer(
      context,
      u.estLot ? 'Clôturer ${u.code} ?' : 'Clôturer la fiche de ${u.code} ?',
      // Ici, plus aucune tete : seuls les rappels restent a retirer.
      message: u.estLot
          ? 'Le lot ne sera plus suivi, et ses rappels de soins seront retirés.'
          : "L'animal ne sera plus suivi, et ses rappels de soins seront retirés.",
      confirmer: 'Clôturer',
      destructif: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await CarnetApi.cloturer(u.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${u.code} est clôturé.')));
      await recharger();
    } on ApiException catch (e) {
      if (context.mounted) await afficherErreur(context, e);
    }
  }

  Future<void> _surRappel(BuildContext context, Rappel r) async {
    final noter = await choisirSuite(
      context,
      r.libelle,
      message: 'Échéance ${Fmt.echeance(r.joursRestants)}, le ${Fmt.date(r.dateEcheance)}. '
          'Le soin est fait ? Notez-le.',
      premier: 'Noter ce soin',
      second: 'Ignorer ce rappel',
    );
    if (!context.mounted || noter == null) return;
    if (noter) {
      await ouvrir<void>(context, EcranAjouterEvenement(unite: u));
    } else {
      try {
        await SanitaireApi.ignorerRappel(r.id);
      } on ApiException catch (e) {
        if (context.mounted) await afficherErreur(context, e);
      }
    }
    await recharger();
  }
}

// ── en-tete ────────────────────────────────────────────────────────────────

class _Heros extends StatelessWidget {
  const _Heros({required this.unite});
  final Unite unite;

  @override
  Widget build(BuildContext context) {
    final u = unite;
    final c = u.estActif ? cycleDe(u) : null;
    final depasse = c != null && (c.joursRestants ?? 0) < 0;
    final blanc = context.typo.corpsFort.copyWith(color: context.couleurs.surEntete);
    final pale = context.typo.legendeForte.copyWith(color: context.couleurs.surMarqueDiscret);

    final Widget tete = c != null
        ? AnneauProgression(
            valeur: c.avancement,
            taille: 76,
            epaisseur: 8,
            couleur: context.couleurs.accent,
            piste: const Color(0x33FFFFFF),
            centre: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('J+${c.jour}', style: blanc.copyWith(fontSize: 18, height: 1)),
              Text('sur ${c.duree}', style: pale.copyWith(fontSize: 12, height: 1.2)),
            ]),
          )
        : Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: PictoAnimal.filiere(u.filiere, taille: 44, couleur: context.couleurs.surEntete),
          );

    final lignes = <Widget>[
      if (!u.estActif)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Pastille(L.statutUnite(u.statut), ton: L.tonStatutUnite(u.statut)),
        ),
      if (u.estLot) ...[
        BarreEffectif(restant: u.effectifRestant, initial: u.effectifInitial, clair: true),
        const SizedBox(height: 6),
        Text('Mis en place le ${Fmt.date(u.dateEntree)}', style: pale),
        if (c != null)
          Text(
            depasse
                ? 'Cycle dépassé de ${-c.joursRestants!} jour${-c.joursRestants! > 1 ? 's' : ''}'
                : 'Fin prévue le ${Fmt.date(u.dateCloturePrevue)}',
            style: depasse ? blanc : pale,
          ),
      ] else ...[
        Text(detailAnimal(u), style: blanc, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('Entré le ${Fmt.date(u.dateEntree)}', style: pale),
      ],
    ];

    return Row(children: [
      tete,
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lignes),
      ),
    ]);
  }
}

// ── corps ──────────────────────────────────────────────────────────────────

class _CycleTermine extends StatelessWidget {
  const _CycleTermine({required this.jours, required this.onVendre, required this.onCloturer});
  final int jours;
  final VoidCallback onVendre;
  final VoidCallback onCloturer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.couleurs.fondAccentPale,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.couleurs.accent, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.flag_rounded, color: context.couleurs.attentionTexte, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                jours <= 0
                    ? "Le cycle se termine aujourd'hui"
                    : 'Cycle terminé depuis $jours jour${jours > 1 ? 's' : ''}',
                style: context.typo.corpsFort,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Vendez les têtes restantes (Changer le statut) ou clôturez le lot.',
              style: context.typo.corps),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: BoutonSecondaire('Clôturer',
                    icone: Icons.flag_outlined, onPressed: onCloturer)),
            const SizedBox(width: 10),
            Expanded(
                child:
                    BoutonPrincipal('Changer le statut',
                        icone: Icons.sync_alt_rounded, onPressed: onVendre)),
          ]),
        ]),
      );
}

class _CarteSolde extends StatelessWidget {
  const _CarteSolde({required this.unite, required this.solde, required this.onTap});
  final Unite unite;
  final Solde solde;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        rayon: 18,
        libelle: 'Argent de cet élevage : ${Fmt.fcfa(solde.solde, signe: true)}. '
            'Voir la rentabilité',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: context.couleurs.sable, shape: BoxShape.circle),
                child: Icon(Icons.payments_outlined, color: context.couleurs.encreFonce),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(unite.estLot ? 'Argent du lot' : "Argent de l'animal",
                      style: context.typo.legendeForte),
                  CompteurAnime(
                    valeur: solde.solde,
                    style: context.typo.chiffre.copyWith(
                        color: solde.solde < 0 ? context.couleurs.erreur : context.couleurs.titre),
                    format: (n) => Fmt.fcfa(n, signe: true),
                  ),
                  Text('Gagné ${Fmt.fcfa(solde.revenus)} · dépensé ${Fmt.fcfa(solde.depenses)}',
                      style: context.typo.legende),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
            ]),
          ),
        ),
      );
}

class _EntreeFrise {
  const _EntreeFrise({
    required this.date,
    required this.icone,
    required this.couleur,
    required this.titre,
    this.detail,
    this.auteur,
    this.onTap,
    this.indice,
  });
  final DateTime? date;
  final IconData icone;
  final Color couleur;
  final String titre;
  final String? detail;
  final String? auteur;
  final VoidCallback? onTap;

  /// Petite icone a droite qui dit ce que fait le toucher (crayon, annuler).
  final IconData? indice;
}

/// Frise chronologique : une pastille de couleur par evenement, reliees par
/// un fil. Plus lisible que des cartes empilees.
class _Frise extends StatelessWidget {
  const _Frise({required this.entrees});
  final List<_EntreeFrise> entrees;

  @override
  Widget build(BuildContext context) {
    if (entrees.isEmpty) {
      return const EtatVide('Rien de noté pour le moment.');
    }
    return Container(
      decoration: BoxDecoration(
          color: context.couleurs.surface, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        for (var i = 0; i < entrees.length; i++)
          _LigneFrise(entree: entrees[i], premiere: i == 0, derniere: i == entrees.length - 1),
      ]),
    );
  }
}

class _LigneFrise extends StatelessWidget {
  const _LigneFrise({required this.entree, required this.premiere, required this.derniere});
  final _EntreeFrise entree;
  final bool premiere;
  final bool derniere;

  @override
  Widget build(BuildContext context) {
    final e = entree;
    final contenu = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: premiere ? 26 : 0,
                bottom: derniere ? null : 0,
                height: derniere ? 26 : null,
                child: Container(width: 2, color: context.couleurs.filetLeger),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: e.couleur.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.couleurs.surface, width: 2),
                  ),
                  child: Icon(e.icone, size: 19, color: e.couleur),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.titre, style: context.typo.corpsFort),
                  if (e.detail != null && e.detail!.isNotEmpty)
                    Text(e.detail!, style: context.typo.corps.copyWith(fontSize: 15)),
                  Text(
                    [Fmt.date(e.date), if (e.auteur != null) e.auteur!].join(' · '),
                    style: context.typo.legende,
                  ),
                ],
              ),
            ),
          ),
          if (e.indice != null)
            SizedBox(
              width: 48,
              child: Icon(e.indice, size: 22, color: context.couleurs.marque),
            )
          else if (e.auteur != null)
            SizedBox(
              width: 48,
              child: Icon(Icons.verified_outlined, size: 22, color: context.couleurs.sante),
            ),
        ],
      ),
    );
    if (e.onTap == null) return contenu;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: e.onTap, child: contenu),
    );
  }
}

typedef _Action = (String, IconData, Color, Color, VoidCallback);

/// Barre fixe en bas du carnet : les trois gestes, a portee de pouce.
class _BarreActions extends StatelessWidget {
  const _BarreActions({required this.actions});
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dim.rayonPanneau)),
          boxShadow: [
            BoxShadow(color: context.couleurs.ombrePanneau, blurRadius: 18, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(children: [
              for (final (libelle, icone, fond, encre, onTap) in actions)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: libelle,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
                            child: Icon(icone, color: encre),
                          ),
                          const SizedBox(height: 4),
                          Text(libelle,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: context.typo.legendeForte.copyWith(color: context.couleurs.texte)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
