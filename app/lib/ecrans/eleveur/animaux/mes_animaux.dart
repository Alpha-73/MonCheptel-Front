/// Mes animaux : lots et animaux, par filiere.
///
/// Sources : GET /api/cheptel?filiere=X (la liste) et GET /api/auth/moi
/// (les filieres pratiquees, pour les onglets ; garde en memoire pour la
/// session : il ne change que depuis Profil). Les chiffres du bandeau sont
/// calcules ICI a partir de la liste : ils decrivent exactement ce qui est
/// affiche dessous, sans second appel.
///
/// Un lot se lit d'un coup d'oeil : anneau du cycle (J+16 sur 45), barre
/// d'effectif (restant sur initial). Un animal : sa vignette d'espece.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../theme/typographie.dart';
import '../../../widgets/eleveur/chargeur_doux.dart';
import '../../../widgets/eleveur/onglets_filiere.dart';
import '../../../widgets/eleveur/pictos.dart';
import '../../../widgets/formulaires.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import 'ajouter_unite.dart';
import 'carnet.dart';
import '../../../widgets/mise_en_page.dart';

/// Le cycle d'un lot : jour courant, duree prevue, avancement (0..1+).
/// Nul pour un animal, ou un lot sans fin de cycle prevue.
typedef Cycle = ({int jour, int duree, double avancement, int? joursRestants});

Cycle? cycleDe(Unite u, [DateTime? maintenant]) {
  final debut = u.dateEntree;
  final fin = u.dateCloturePrevue;
  if (!u.estLot || debut == null || fin == null) return null;
  final duree = fin.difference(debut).inDays;
  if (duree <= 0) return null;
  final ajd = maintenant ?? DateTime.now();
  final jour = DateTime(ajd.year, ajd.month, ajd.day).difference(debut).inDays;
  return (
    jour: jour,
    duree: duree,
    avancement: jour / duree,
    joursRestants: u.joursRestants ?? duree - jour,
  );
}

class MesAnimaux extends StatefulWidget {
  const MesAnimaux({super.key});

  @override
  State<MesAnimaux> createState() => _MesAnimauxState();
}

typedef _Donnees = ({List<Unite> unites, List<String> filieres});

class _MesAnimauxState extends State<MesAnimaux> {
  /// Filieres pratiquees, gardees pour la session (audit F17).
  static List<String>? _filieresConnues;

  /// Nulle = onglet « Toutes ».
  String? _filiere;

  /// Onglet « Clôturés » : les elevages termines (cloture, vente, mort,
  /// transfert). Par defaut, l'onglet « Actifs ».
  bool _clotures = false;

  Future<_Donnees> _charger() async {
    final f = _filiere;
    final reponses = await Future.wait([
      CheptelApi.lister(filiere: f),
      if (_filieresConnues == null) AuthApi.moi(),
    ]);
    if (reponses.length > 1) {
      _filieresConnues = L.trierFilieres((reponses[1] as Profil).filieresPratiquees);
    }
    return (unites: reponses[0] as List<Unite>, filieres: _filieresConnues!);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.couleurs.fond,
      child: ChargeurDoux<_Donnees>(
        cle: _filiere,
        charger: _charger,
        squelette: const Column(children: [
          EnteteVivant(titre: 'Mes animaux'),
          SizedBox(height: 16),
          Expanded(child: ListeSquelette(nombre: 4)),
        ]),
        construire: _contenu,
      ),
    );
  }

  Widget _contenu(
      BuildContext context, _Donnees d, Future<void> Function() recharger, bool enCours) {
    final f = _filiere;
    final unites = [...d.unites]
      // Les elevages en cours d'abord, puis les plus recents.
      ..sort((a, b) {
        if (a.estActif != b.estActif) return a.estActif ? -1 : 1;
        return (b.dateEntree ?? DateTime(2000)).compareTo(a.dateEntree ?? DateTime(2000));
      });
    final actives = unites.where((u) => u.estActif).toList();
    final terminees = unites.where((u) => !u.estActif).toList();
    final affichees = _clotures ? terminees : actives;
    final lots = actives.where((u) => u.estLot).toList();
    final animaux = actives.where((u) => !u.estLot).toList();
    final tetes = lots.fold<int>(0, (s, u) => s + u.effectifRestant);

    final resume = [
      if (lots.isNotEmpty) '${lots.length} lot${lots.length > 1 ? 's' : ''} · ${Fmt.tetes(tetes)}',
      if (animaux.isNotEmpty) '${animaux.length} animal${animaux.length > 1 ? 'aux' : ''} suivi${animaux.length > 1 ? 's' : ''}',
    ];

    Future<void> ajouter() async {
      await ouvrir<void>(context, EcranAjouterUnite(filiere: f));
      await recharger();
    }

    // « Toutes » : on ne sait pas encore si ce sera un lot ou un animal.
    final libelleAjout = f == null
        ? 'Ajouter'
        : L.suiviParLot(f)
            ? 'Ajouter un lot'
            : 'Ajouter un animal';

    return Column(
      children: [
        EnteteVivant(
          titre: 'Mes animaux',
          sousTitre: resume.isEmpty ? 'Aucun élevage en cours' : resume.join(' · '),
          aDroite: d.filieres.isEmpty
              ? null
              : BoutonEntete(icone: Icons.add_rounded, libelle: libelleAjout, onTap: ajouter),
        ),
        BarreRechargement(actif: enCours),
        Expanded(
          child: RefreshIndicator(
            // Tirer pour actualiser relit aussi les filieres du profil.
            onRefresh: () {
              _filieresConnues = null;
              return recharger();
            },
            color: context.couleurs.marque,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
                padding: lisible(context, const EdgeInsets.only(top: 8, bottom: 24)),
              children: [
                if (d.filieres.length > 1) ...[
                  OngletsFiliere(
                    filieres: [null, ...d.filieres],
                    active: f,
                    onChange: (x) => setState(() => _filiere = x),
                  ),
                  const SizedBox(height: 12),
                ],
                if (unites.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 12),
                    child: Segments<bool>(
                      options: [
                        (false, 'Actifs (${actives.length})'),
                        (true, 'Clôturés (${terminees.length})'),
                      ],
                      valeur: _clotures,
                      onChange: (v) => setState(() => _clotures = v),
                    ),
                  ),
                ],
                if (unites.isNotEmpty && affichees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Dim.gouttiere),
                    child: Text(
                        _clotures
                            ? 'Aucun élevage clôturé pour le moment.'
                            : 'Aucun élevage en cours. Vos élevages terminés sont dans « Clôturés ».',
                        textAlign: TextAlign.center,
                        style: context.typo.corpsDiscret),
                  ),
                if (unites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Dim.gouttiere),
                    child: _Vide(
                      filiere: f,
                      peutAjouter: d.filieres.isNotEmpty,
                      libelle: libelleAjout,
                      onAjouter: ajouter,
                    ),
                  )
                else
                  for (var i = 0; i < affichees.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 10),
                      child: Apparition(
                        rang: i,
                        child: CarteUnite(
                          unite: affichees[i],
                          onTap: () async {
                            await ouvrir<void>(context, EcranCarnet(uniteId: affichees[i].id));
                            await recharger();
                          },
                        ),
                      ),
                    ),
                if (unites.isNotEmpty && d.filieres.isNotEmpty && !_clotures)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 6, Dim.gouttiere, 0),
                    child: _BoutonAjout(libelle: libelleAjout, onTap: ajouter),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// « Zébu, femelle — née le 10 janv. 2022 » pour un animal.
String detailAnimal(Unite u) {
  final parties = <String>[
    if (u.race != null) u.race!,
    if (u.sexe != null) L.sexe(u.sexe).toLowerCase(),
  ];
  final naissance = u.dateNaissance == null
      ? null
      : '${u.sexe == 'FEMELLE' ? 'née' : 'né'} le ${Fmt.date(u.dateNaissance)}';
  final texte = [
    if (parties.isNotEmpty) parties.join(', '),
    if (naissance != null) naissance,
  ].join(' · ');
  return texte.isEmpty ? u.typeElevage : texte;
}

/// Une carte de la liste. Lot : anneau du cycle et barre d'effectif.
/// Animal : vignette d'espece, race, sexe, naissance.
class CarteUnite extends StatelessWidget {
  const CarteUnite({super.key, required this.unite, this.onTap});
  final Unite unite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = unite;
    final c = u.estActif ? cycleDe(u) : null;
    final depasse = c != null && (c.joursRestants ?? 0) < 0;

    final Widget tete;
    if (c != null) {
      tete = AnneauProgression(
        valeur: c.avancement,
        taille: 58,
        epaisseur: 6,
        couleur: depasse ? context.couleurs.graviteHaute : context.couleurs.accent,
        centre: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('J+${c.jour}', style: context.typo.corpsFort.copyWith(fontSize: 14, height: 1)),
          Text('/${c.duree}', style: context.typo.legende.copyWith(fontSize: 11, height: 1.1)),
        ]),
      );
    } else {
      tete = VignetteAnimal(filiere: u.filiere, taille: 58, actif: u.estActif);
    }

    final String? ligneCycle = c == null
        ? null
        : depasse
            ? 'Cycle dépassé de ${-c.joursRestants!} j'
            : 'Fin prévue le ${Fmt.date(u.dateCloturePrevue)}';

    return Pressable(
      onTap: onTap,
      rayon: 18,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            tete,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(u.code,
                          style: context.typo.titreSection.copyWith(fontSize: 18, height: 1.2),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (!u.estActif)
                      Pastille(L.statutUnite(u.statut), ton: L.tonStatutUnite(u.statut)),
                  ]),
                  Text(u.estLot ? u.typeElevage : detailAnimal(u),
                      style: context.typo.legende, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (u.estLot) ...[
                    const SizedBox(height: 8),
                    BarreEffectif(restant: u.effectifRestant, initial: u.effectifInitial),
                  ],
                  if (ligneCycle != null) ...[
                    const SizedBox(height: 4),
                    Text(ligneCycle,
                        style: context.typo.legendeForte.copyWith(
                            color: depasse ? context.couleurs.graviteHaute : context.couleurs.texteDiscret)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
          ],
        ),
      ),
    );
  }
}

/// « 150 / 185 têtes » et une barre : ce qui reste du lot mis en place.
class BarreEffectif extends StatelessWidget {
  const BarreEffectif({super.key, required this.restant, required this.initial, this.clair = false});
  final int restant;
  final int initial;

  /// Sur fond vert (en-tete).
  final bool clair;

  @override
  Widget build(BuildContext context) {
    final part = initial <= 0 ? 0.0 : (restant / initial).clamp(0.0, 1.0);
    return Semantics(
      label: '${Fmt.montant(restant)} têtes sur ${Fmt.montant(initial)}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: Fmt.montant(restant),
                style: context.typo.corpsFort.copyWith(color: clair ? context.couleurs.surEntete : null)),
            TextSpan(
                text: ' sur ${Fmt.tetes(initial)}',
                style: context.typo.legende.copyWith(color: clair ? context.couleurs.surMarqueDiscret : null)),
          ]),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: mouvementReduit(context) ? part : 0, end: part),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: clair ? context.couleurs.accent : context.couleurs.marque,
                backgroundColor: clair ? const Color(0x33FFFFFF) : context.couleurs.sable,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BoutonAjout extends StatelessWidget {
  const _BoutonAjout({required this.libelle, required this.onTap});
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        ombre: false,
        couleur: context.couleurs.fondMarquePale,
        rayon: 18,
        child: SizedBox(
          height: 56,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_rounded, color: context.couleurs.marque),
            const SizedBox(width: 8),
            Text(libelle, style: Typo.bouton.copyWith(color: context.couleurs.marque)),
          ]),
        ),
      );
}

class _Vide extends StatelessWidget {
  const _Vide({
    required this.filiere,
    required this.peutAjouter,
    required this.libelle,
    required this.onAjouter,
  });
  final String? filiere;
  final bool peutAjouter;
  final String libelle;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 12),
        VignetteAnimal(filiere: filiere ?? 'BOVINS', taille: 88),
        const SizedBox(height: 14),
        Text(
          !peutAjouter
              ? 'Choisissez vos filières dans Profil.'
              : filiere == null
                  ? 'Aucun animal pour le moment.'
                  : 'Aucun élevage en ${L.filiere(filiere).toLowerCase()}.',
          style: context.typo.corpsFort,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (peutAjouter) _BoutonAjout(libelle: libelle, onTap: onAjouter),
      ]);
}
