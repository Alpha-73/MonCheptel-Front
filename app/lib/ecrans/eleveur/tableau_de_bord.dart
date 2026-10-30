/// Accueil de l'eleveur.
///
/// Source : GET /api/tableau-de-bord?filiere=X, une seule requete pour tout
/// l'ecran. Les compteurs suivent la filiere choisie ; le solde, lui, couvre
/// toutes les filieres (le back le calcule ainsi, et la carte le dit).
///
/// De haut en bas, ce qui compte le plus d'abord :
///  1. l'en-tete personnel : salutation selon l'heure, prenom, jauge de
///     sante du cheptel (part des elevages a jour de leurs soins) ;
///  2. une alerte epidemie, en rouge plein, s'il y en a une ;
///  3. les chiffres du cheptel, animes ;
///  4. le solde du mois ;
///  5. quatre grands raccourcis, une famille de gestes chacun :
///     « + Opération » (dépense, revenu), « Changer le statut » (vente,
///     mort, transfert), « Ajouter un lot » et « Événement sanitaire » ;
///  6. « À faire », tout en bas : les rappels de soins, les retards en tete.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../theme/typographie.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/echafaudage.dart';
import '../../widgets/eleveur/chargeur_doux.dart';
import '../../widgets/eleveur/onglets_filiere.dart';
import '../../widgets/eleveur/pictos.dart';
import '../../widgets/navigation.dart';
import '../../widgets/vivant.dart';
import 'agir_vite.dart';
import 'animaux/ajouter_unite.dart';
import 'animaux/carnet.dart';
import 'finances/operations.dart';
import 'finances/rapports.dart';
import 'profil/notifications.dart';
import 'sante/alerte.dart';
import '../../widgets/mise_en_page.dart';

/// Prenom affiche dans la salutation : le premier mot du nom.
String prenomDe(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+'));
  return mots.isEmpty || mots.first.isEmpty ? 'Éleveur' : mots.first;
}

/// Jauge de sante : part des elevages actifs sans soin en retard. Nulle
/// quand il n'y a aucun elevage actif.
double? jaugeSante(int actifs, List<Rappel> rappels) {
  if (actifs <= 0) return null;
  final enRetard = {
    for (final r in rappels)
      if (r.joursRestants < 0) r.uniteId ?? -r.id,
  }.length;
  return ((actifs - enRetard) / actifs).clamp(0.0, 1.0);
}

class TableauDeBordEleveur extends StatefulWidget {
  const TableauDeBordEleveur({super.key, required this.versOnglet, this.charger});

  /// Pour les tests : remplace GET /api/tableau-de-bord.
  @visibleForTesting
  final Future<TableauDeBord> Function(String? filiere)? charger;

  /// Bascule vers un autre onglet de la barre du bas (1 = Animaux...).
  final ValueChanged<int> versOnglet;

  @override
  State<TableauDeBordEleveur> createState() => _TableauDeBordEleveurState();
}

class _TableauDeBordEleveurState extends State<TableauDeBordEleveur> {
  /// Nulle au premier affichage : le back choisit la premiere filiere
  /// pratiquee, dans l'ordre Volaille, Bovins, Ovins, Caprins.
  String? _filiere;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.couleurs.fond,
      child: ChargeurDoux<TableauDeBord>(
        cle: _filiere,
        charger: () => (widget.charger ?? (f) => TableauDeBordApi.charger(filiere: f))(_filiere),
        squelette: Column(children: [
          EnteteVivant(grand: true, surtitre: '${salutation()},', titre: '…'),
          const SizedBox(height: 16),
          const Expanded(child: ListeSquelette(nombre: 4)),
        ]),
        construire: _contenu,
      ),
    );
  }

  Widget _contenu(
      BuildContext context, TableauDeBord t, Future<void> Function() recharger, bool enCours) {
    Future<void> puisRecharger(Widget ecran) async {
      await ouvrir<void>(context, ecran);
      await recharger();
    }

    Future<void> puis(Future<void> Function() geste) async {
      await geste();
      await recharger();
    }

    final filieres = L.trierFilieres(t.filieres);
    final affichee = t.filiereAffichee;
    // Audit F15 : la liste couvre toutes les filieres pratiquees ; on ne
    // garde que celles de l'onglet (ou communes a toutes).
    final alertes = [
      for (final a in t.alertes)
        if (a.filiere == null || affichee == null || a.filiere == affichee) a,
    ];
    final rappels = [...t.rappels]..sort((a, b) => a.joursRestants.compareTo(b.joursRestants));

    var rang = 0;
    Widget entree(Widget enfant) => Apparition(rang: rang++, child: enfant);

    // L'en-tete defile avec le contenu : sur un petit telephone, la jauge
    // ne doit pas manger la moitie de l'ecran en permanence.
    final entete = EnteteVivant(
      grand: true,
      surtitre: '${salutation()},',
      titre: prenomDe(t.nomEleveur),
      sousTitre: t.zone ?? 'Mon élevage',
      aDroite: BoutonEntete(
        icone: Icons.notifications_none_rounded,
        libelle: 'Notifications',
        badge: t.notificationsNonLues,
        onTap: () => puisRecharger(const EcranNotifications()),
      ),
      bas: affichee == null ? null : _JaugeCheptel(t: t, alertes: alertes.length),
    );

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: recharger,
          color: context.couleurs.marque,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              entete,
              // L'en-tete reste pleine largeur ; le reste se centre dans une
              // colonne lisible sur tablette et en paysage.
              LargeurLisible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const SizedBox(height: 8),
                  if (filieres.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: OngletsFiliere(
                        filieres: filieres,
                        active: affichee,
                        onChange: (f) => setState(() => _filiere = f),
                      ),
                    ),
                  if (affichee == null)
                    entree(Padding(
                      padding: const EdgeInsets.all(Dim.gouttiere),
                      child: _Bienvenue(onAjouter: () => widget.versOnglet(4)),
                    ))
                  else ...[
                    for (final a in alertes)
                      entree(Padding(
                        padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 0),
                        child: _BandeauAlerte(
                            alerte: a, onTap: () => puisRecharger(EcranAlerte(alerte: a))),
                      )),
                    const SizedBox(height: 8),
                    entree(Gouttiere(
                      enfant: _Chiffres(t: t, onTap: () => widget.versOnglet(1)),
                    )),
                  ],
                  const TitreSectionVivant('Solde'),
                  entree(Gouttiere(
                    enfant: _CarteArgent(
                      solde: t.soldeDuMois,
                      onTap: () => puisRecharger(const EcranOperations()),
                      onRapports: () => puisRecharger(const EcranRapports()),
                    ),
                  )),
                  if (affichee != null) ...[
                    const TitreSectionVivant('Raccourcis'),
                    entree(Gouttiere(
                      enfant: _Raccourcis(
                        filiere: affichee,
                        apres: recharger,
                      ),
                    )),
                    // « À faire » tout en bas, sous les cartes (demande du 28/10).
                    TitreSectionVivant(
                      'À faire',
                      action: rappels.length > 3 ? 'Tout voir' : null,
                      onAction: () => widget.versOnglet(2),
                    ),
                    if (rappels.isEmpty)
                      entree(const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Dim.gouttiere),
                        child: _RienAFaire(),
                      ))
                    else
                      for (final r in rappels.take(3))
                        entree(Padding(
                          padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 10),
                          child: CarteRappel(
                            rappel: r,
                            onTap: () => puis(() => surRappel(context, r)),
                          ),
                        )),
                  ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          left: 0,
          right: 0,
          child: BarreRechargement(actif: enCours),
        ),
      ],
    );
  }
}

/// Le meme dialogue partout (audit F9) : ouvrir le carnet, ou ignorer.
Future<void> surRappel(BuildContext context, Rappel r) async {
  final voir = await choisirSuite(
    context,
    r.libelle,
    message: [
      if (r.uniteCode != null) r.uniteCode!,
      'échéance ${Fmt.echeance(r.joursRestants)}',
    ].join(' · '),
    premier: r.uniteId == null ? 'Fermer' : 'Ouvrir le carnet',
    second: 'Ignorer ce rappel',
  );
  if (!context.mounted || voir == null) return;
  if (voir) {
    if (r.uniteId != null) await ouvrir<void>(context, EcranCarnet(uniteId: r.uniteId!));
  } else {
    try {
      await SanitaireApi.ignorerRappel(r.id);
    } on ApiException catch (e) {
      if (context.mounted) await afficherErreur(context, e);
    }
  }
}

// ── en-tete : jauge du cheptel ─────────────────────────────────────────────

class _JaugeCheptel extends StatelessWidget {
  const _JaugeCheptel({required this.t, required this.alertes});
  final TableauDeBord t;
  final int alertes;

  @override
  Widget build(BuildContext context) {
    final f = t.filiereAffichee!;
    final parLot = L.suiviParLot(f);
    final jauge = jaugeSante(t.unitesActives, t.rappels);
    final retards = t.rappels.where((r) => r.joursRestants < 0).length;
    final etat = jauge == null
        ? 'Aucun élevage en cours'
        : jauge >= 1
            ? 'Cheptel à jour de ses soins'
            : jauge >= 0.7
                ? 'Quelques soins à rattraper'
                : 'Des soins en retard';
    final effectif = parLot
        ? '${Fmt.montant(t.unitesActives)} lot${t.unitesActives > 1 ? 's' : ''} · '
            '${Fmt.tetes(t.tetesRestantes)}'
        : '${Fmt.montant(t.unitesActives)} ${L.filiere(f).toLowerCase()} suivis';
    final pourcent = jauge == null ? 0 : (jauge * 100).round();

    return Semantics(
      label: jauge == null ? etat : '$etat, $pourcent pour cent. $effectif',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          children: [
            AnneauProgression(
              valeur: jauge ?? 0,
              taille: 72,
              epaisseur: 8,
              couleur: context.couleurs.accent,
              piste: const Color(0x33FFFFFF),
              centre: jauge == null
                  ? PictoAnimal.filiere(f, taille: 30, couleur: context.couleurs.surEntete)
                  : CompteurAnime(
                      valeur: pourcent,
                      style: Typo.titreEcran.copyWith(fontSize: 20),
                      format: (n) => '${n.round()} %',
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etat,
                      style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(effectif,
                      style: context.typo.legendeForte.copyWith(color: context.couleurs.surMarqueDiscret)),
                  if (retards > 0 || alertes > 0) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (retards > 0)
                        _PuceEntete('$retards soin${retards > 1 ? 's' : ''} en retard'),
                      if (alertes > 0) const _PuceEntete('Alerte dans la zone'),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuceEntete extends StatelessWidget {
  const _PuceEntete(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: context.couleurs.accent, borderRadius: BorderRadius.circular(10)),
        child:
            Text(texte, style: Typo.pastille.copyWith(fontSize: 13, color: context.couleurs.surAccent)),
      );
}

// ── corps ──────────────────────────────────────────────────────────────────

class _BandeauAlerte extends StatelessWidget {
  const _BandeauAlerte({required this.alerte, required this.onTap});
  final Alerte alerte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = alerte;
    final detail = [
      a.zone,
      if (a.dateFin != null) "jusqu'au ${Fmt.date(a.dateFin)}",
    ].join(' · ');
    return Pressable(
      onTap: onTap,
      couleur: context.couleurs.graviteHaute,
      rayon: 18,
      libelle: 'Alerte épidémie : ${a.maladie}. $detail',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
              child: Icon(Icons.campaign_rounded, color: context.couleurs.surEntete),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alerte : ${a.maladie}',
                      style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
                  Text(detail, style: context.typo.legendeForte.copyWith(color: context.couleurs.surEntete)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.couleurs.surEntete),
          ]),
        ),
      ),
    );
  }
}

/// Un rappel de soin : bande de couleur selon l'urgence, pictogramme,
/// libelle court. Rouge = en retard, orange = aujourd'hui ou demain.
class CarteRappel extends StatelessWidget {
  const CarteRappel({super.key, required this.rappel, required this.onTap});
  final Rappel rappel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rappel;
    final (couleur, fond) = r.joursRestants < 0
        ? (context.couleurs.graviteHaute, context.couleurs.fondErreurPale)
        : r.joursRestants <= 1
            ? (context.couleurs.attentionTexte, context.couleurs.fondAccentPale)
            : (context.couleurs.marque, context.couleurs.fondMarquePale);
    final quand = Fmt.echeance(r.joursRestants);
    final detail = [if (r.uniteCode != null) r.uniteCode!, quand].join(' · ');
    return Pressable(
      onTap: onTap,
      libelle: '${r.libelle}, $detail',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: couleur),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
                      child: Icon(Icons.vaccines_outlined, color: couleur),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.libelle, style: context.typo.corpsFort),
                          const SizedBox(height: 2),
                          Text(detail,
                              style: context.typo.legendeForte.copyWith(
                                  color: r.joursRestants <= 1 ? couleur : context.couleurs.texteDiscret)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RienAFaire extends StatelessWidget {
  const _RienAFaire();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: context.couleurs.fondMarquePale, borderRadius: BorderRadius.circular(Dim.rayon)),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: context.couleurs.marque, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('Aucun soin prévu cette semaine.', style: context.typo.corpsFort)),
        ]),
      );
}

class _Chiffres extends StatelessWidget {
  const _Chiffres({required this.t, required this.onTap});
  final TableauDeBord t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = t.filiereAffichee!;
    final parLot = L.suiviParLot(f);
    return Row(children: [
      Expanded(
        child: _TuileChiffre(
          valeur: parLot ? t.tetesRestantes : t.unitesActives,
          libelle: L.tetesDe(f),
          detail: parLot
              ? '${t.unitesActives} lot${t.unitesActives > 1 ? 's' : ''} en cours'
              : 'animal par animal',
          accent: true,
          filiere: f,
          onTap: onTap,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _TuileChiffre(
          valeur: parLot ? t.tetesSorties : t.unitesCloturees,
          libelle: parLot ? 'Têtes sorties' : 'Sortis du cheptel',
          detail: parLot
              ? '${t.unitesCloturees} lot${t.unitesCloturees > 1 ? 's' : ''} clôturé${t.unitesCloturees > 1 ? 's' : ''}'
              : 'vendus, morts, donnés',
          onTap: onTap,
        ),
      ),
    ]);
  }
}

class _TuileChiffre extends StatelessWidget {
  const _TuileChiffre({
    required this.valeur,
    required this.libelle,
    required this.detail,
    required this.onTap,
    this.accent = false,
    this.filiere,
  });
  final int valeur;
  final String libelle;
  final String detail;
  final VoidCallback onTap;
  final bool accent;
  final String? filiere;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        rayon: 18,
        libelle: '$libelle : $valeur. $detail',
        child: ExcludeSemantics(
          child: Stack(children: [
            if (accent)
              Positioned(
                right: -6,
                bottom: -6,
                child: PictoAnimal.filiere(filiere, taille: 64, couleur: context.couleurs.fondMarquePale),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompteurAnime(
                    valeur: valeur,
                    style: context.typo.chiffreHeros
                        .copyWith(color: accent ? context.couleurs.marque : context.couleurs.titre),
                    format: (n) => Fmt.montant(n),
                  ),
                  const SizedBox(height: 4),
                  Text(libelle, style: context.typo.corpsFort),
                  Text(detail, style: context.typo.legende),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// Les quatre raccourcis, une famille de gestes chacun : l'argent, le
/// statut (sorties), l'ajout, la sante. Aucun ne melange les familles.
class _Raccourcis extends StatelessWidget {
  const _Raccourcis({required this.filiere, required this.apres});
  final String? filiere;
  final Future<void> Function() apres;

  @override
  Widget build(BuildContext context) {
    final c = context.couleurs;
    Future<void> faire(Future<void> Function() geste) async {
      await geste();
      await apres();
    }

    return GrilleTuiles(
      ecart: 10,
      children: [
        TuileAction(
          compact: true,
          libelle: '+ Opération',
          icone: Icons.payments_outlined,
          fond: c.fondAccentPale,
          encre: c.attentionTexte,
          onTap: () => faire(() => noterOperation(context, filiere: filiere)),
        ),
        TuileAction(
          compact: true,
          libelle: 'Changer le statut',
          icone: Icons.sync_alt_rounded,
          fond: c.sable,
          encre: c.encreFonce,
          onTap: () => faire(() => changerStatut(context, filiere: filiere)),
        ),
        TuileAction(
          compact: true,
          libelle:
              filiere != null && L.suiviParLot(filiere!) ? 'Ajouter un lot' : 'Ajouter un animal',
          picto: Stack(clipBehavior: Clip.none, children: [
            PictoAnimal.filiere(filiere, taille: 26),
            Positioned(
              right: -8,
              bottom: -6,
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, size: 16, color: c.surAccent),
              ),
            ),
          ]),
          onTap: () => faire(() => ouvrir<void>(context, EcranAjouterUnite(filiere: filiere))),
        ),
        TuileAction(
          compact: true,
          libelle: 'Événement sanitaire',
          icone: Icons.health_and_safety_outlined,
          fond: c.fondErreurPale,
          encre: c.erreur,
          onTap: () => faire(() => noterEvenementSanitaire(context, filiere: filiere)),
        ),
      ],
    );
  }
}

class _CarteArgent extends StatelessWidget {
  const _CarteArgent({required this.solde, required this.onTap, required this.onRapports});
  final Solde solde;
  final VoidCallback onTap;
  final VoidCallback onRapports;

  @override
  Widget build(BuildContext context) {
    final s = solde;
    return Pressable(
      onTap: onTap,
      rayon: 20,
      couleur: context.couleurs.fondFonce,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Solde du mois · toutes filières',
                      style: context.typo.legendeForte.copyWith(color: context.couleurs.surMarqueDiscret)),
                ),
                Semantics(
                  button: true,
                  label: 'Rapports et graphiques',
                  excludeSemantics: true,
                  child: Material(
                    color: const Color(0x26FFFFFF),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRapports,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.bar_chart_rounded, color: context.couleurs.surEntete),
                      ),
                    ),
                  ),
                ),
              ]),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Un gros solde sur un petit ecran se resserre au lieu de
                  // deborder.
                  Flexible(
                    child: CompteurAnime(
                      valeur: s.solde,
                      style: context.typo.chiffreHeros.copyWith(color: context.couleurs.surEntete),
                      format: (n) => Fmt.montant(n, signe: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('FCFA', style: context.typo.corpsFort.copyWith(color: context.couleurs.surMarqueDiscret)),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Flux('Gagné', s.revenus, Icons.south_west_rounded)),
                Expanded(child: _Flux('Dépensé', s.depenses, Icons.north_east_rounded)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Flux extends StatelessWidget {
  const _Flux(this.libelle, this.montant, this.icone);
  final String libelle;
  final int montant;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
          child: Icon(icone, size: 16, color: context.couleurs.accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(libelle, style: context.typo.legende.copyWith(color: context.couleurs.surMarqueDiscret)),
            Text(Fmt.fcfa(montant), style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
          ]),
        ),
      ]);
}

class _Bienvenue extends StatelessWidget {
  const _Bienvenue({required this.onAjouter});
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: context.couleurs.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const VignetteAnimal(filiere: 'BOVINS', taille: 72),
          const SizedBox(height: 12),
          Text('Bienvenue sur MonCheptel', style: context.typo.titreSection),
          const SizedBox(height: 4),
          Text(
            'Choisissez vos filières dans Profil, puis ajoutez vos animaux.',
            style: context.typo.corpsDiscret,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onAjouter,
            child: Text('Choisir mes filières', style: Typo.bouton.copyWith(color: context.couleurs.marque)),
          ),
        ]),
      );
}
