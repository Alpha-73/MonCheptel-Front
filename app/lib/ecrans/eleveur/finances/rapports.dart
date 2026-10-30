/// Maquette : « Rapports - 3 mois / 6 mois / 12 mois », etendue le 6 octobre.
///
/// Sources : GET /api/finances/rapport?debut&fin, toutes filieres, DEUX fois :
/// la periode choisie et la periode precedente, pour la comparaison.
///
/// Ce que l'ecran montre :
///  1. le solde de la periode et son ecart avec la periode precedente ;
///  2. revenus et depenses mois par mois (barres groupees) ;
///  3. le solde CUMULE (courbe) : la trajectoire de l'exploitation, ce
///     qu'un histogramme mensuel ne montre pas ;
///  4. la repartition des depenses par poste (barres horizontales triees) ;
///  5. le tableau des chiffres, pour qui ne lit pas les graphiques.
///
/// Periodes « glissantes » : « Trimestriel » = le mois en cours et les deux
/// precedents, jusqu'a aujourd'hui. Les dates exactes sont toujours
/// affichees, pour ne pas laisser croire a un trimestre civil.
///
/// La comparaison se fait A DATE EGALE : le 6 octobre, en Trimestriel,
/// « 1er aout - 6 octobre » se compare a « 1er mai - 6 juillet », pas a
/// « mai a juillet » entier. Sinon le mois en cours, incomplet, ferait
/// toujours baisser le resultat.
///
/// Filtre par filiere (audit F20) : le back filtre bien le total, la
/// repartition et l'evolution (`OperationFinanciereRepository`). L'onglet
/// n'apparait que si l'eleveur pratique plusieurs filieres.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/vivant.dart';
import '../../../widgets/graphiques.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Donnees = ({Rapport actuel, Rapport precedent});

/// Une periode proposee : nombre de mois, onglet, et la periode precedente
/// deja precedee de sa preposition (« au mois », « à l'année »).
typedef _Periode = ({int mois, String onglet, String precedente});

const List<_Periode> _periodes = [
  (mois: 1, onglet: 'Mensuel', precedente: 'au mois précédent'),
  (mois: 3, onglet: 'Trimestriel', precedente: 'au trimestre précédent'),
  (mois: 6, onglet: 'Semestriel', precedente: 'au semestre précédent'),
  (mois: 12, onglet: 'Annuel', precedente: "à l'année précédente"),
];

/// Meme jour, [n] mois plus tot ou plus tard, borne au dernier jour du mois
/// (31 octobre moins un mois = 30 septembre, pas 1er octobre).
DateTime _decalerMois(DateTime d, int n) {
  final cible = DateTime(d.year, d.month + n, 1);
  final dernierJour = DateTime(cible.year, cible.month + 1, 0).day;
  return DateTime(cible.year, cible.month, d.day > dernierJour ? dernierJour : d.day);
}

class EcranRapports extends StatefulWidget {
  const EcranRapports({super.key});

  @override
  State<EcranRapports> createState() => _EcranRapportsState();
}

class _EcranRapportsState extends State<EcranRapports> {
  int _indexPeriode = 1; // Trimestriel, comme la maquette

  /// Nulle : toutes filieres.
  String? _filiere;
  List<String> _filieres = const [];

  _Periode get _periode => _periodes[_indexPeriode];

  @override
  void initState() {
    super.initState();
    AuthApi.moi().then((p) {
      if (mounted) setState(() => _filieres = L.trierFilieres(p.filieresPratiquees));
    }, onError: (Object _) {});
  }

  Future<_Donnees> _charger() async {
    final maintenant = DateTime.now();
    final fin = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final mois = _periode.mois;
    final debut = DateTime(fin.year, fin.month - (mois - 1), 1);
    final debutPrecedent = DateTime(debut.year, debut.month - mois, 1);
    final finPrecedente = _decalerMois(fin, -mois);
    final r = await Future.wait([
      FinanceApi.rapport(debut: debut, fin: fin, filiere: _filiere),
      FinanceApi.rapport(debut: debutPrecedent, fin: finPrecedente, filiere: _filiere),
    ]);
    return (actuel: r[0], precedent: r[1]);
  }

  @override
  Widget build(BuildContext context) {
    final onglets = <String?>[null, ..._filieres];
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Column(
        children: [
          EnteteVivant(
            titre: 'Graphiques',
            sousTitre: 'Gagné et dépensé',
            retour: true,
            bas: OngletsSurMarque(
              libelles: [for (final p in _periodes) p.onglet],
              indexActif: _indexPeriode,
              onChange: (i) => setState(() => _indexPeriode = i),
            ),
          ),
          if (_filieres.length > 1) ...[
            const SizedBox(height: 4),
            Onglets(
              libelles: [for (final f in onglets) f == null ? 'Toutes' : L.filiere(f)],
              indexActif: onglets.indexOf(_filiere).clamp(0, onglets.length - 1),
              onChange: (i) => setState(() => _filiere = onglets[i]),
            ),
          ],
          Expanded(
            child: ChargeurVivant<_Donnees>(
              key: ValueKey('$_indexPeriode/$_filiere'),
              charger: _charger,
              construire: (context, d, recharger) => RefreshIndicator(
                onRefresh: recharger,
                color: context.couleurs.marque,
                child: _Contenu(donnees: d, periode: _periode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenu extends StatefulWidget {
  const _Contenu({required this.donnees, required this.periode});
  final _Donnees donnees;
  final _Periode periode;

  @override
  State<_Contenu> createState() => _ContenuState();
}

class _ContenuState extends State<_Contenu> {
  /// Mois selectionne dans les graphiques. Par defaut le dernier : le mois
  /// en cours, celui que l'eleveur veut voir.
  late int _selection = widget.donnees.actuel.evolution.length - 1;
  bool _tableau = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.donnees.actuel;
    final evolution = r.evolution;
    final vide = evolution.every((p) => p.revenus == 0 && p.depenses == 0);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 12, Dim.gouttiere, 32)),
      children: [
        Text('Du ${Fmt.date(r.debut)} au ${Fmt.date(r.fin)}', style: context.typo.legende),
        const SizedBox(height: 8),
        _carteSolde(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TuileFlux(
                couleur: context.couleurs.graphiqueRevenus,
                libelle: 'Gagné',
                montant: r.total.revenus,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TuileFlux(
                couleur: context.couleurs.graphiqueDepenses,
                libelle: 'Dépensé',
                montant: r.total.depenses,
              ),
            ),
          ],
        ),
        if (vide) ...[
          const SizedBox(height: 16),
          const EtatVide('Aucune opération sur cette période : '
              'rien à représenter. Enregistrez vos dépenses et vos ventes '
              'pour voir apparaître les graphiques.'),
        ] else ...[
          const SizedBox(height: 16),
          _carteBarres(evolution),
          if (evolution.length > 1) ...[
            const SizedBox(height: 12),
            _carteCourbe(evolution),
          ],
          const SizedBox(height: 12),
          _carteRepartition(r),
        ],
      ],
    );
  }

  // ── 1. solde et comparaison ─────────────────────────────────────────────

  Widget _carteSolde() {
    final actuel = widget.donnees.actuel.total.solde;
    final avant = widget.donnees.precedent.total.solde;
    final ecart = actuel - avant;
    final hausse = ecart > 0;
    final baisse = ecart < 0;
    // Pourcentage seulement sur une base positive : « +300 % » apres un
    // solde negatif ne veut rien dire.
    final pourcent = avant > 0 ? ' (${hausse ? '+' : baisse ? '−' : ''}'
            '${(ecart.abs() * 100 / avant).round()} %)'
        : '';
    final couleur = hausse ? context.couleurs.marque : baisse ? context.couleurs.erreur : context.couleurs.texteDiscret;

    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Il vous est resté', style: context.typo.corpsDiscret),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: Fmt.montant(actuel, signe: true), style: context.typo.chiffreHeros),
            TextSpan(text: '  FCFA', style: context.typo.corpsDiscret),
          ])),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icone ET signe ET texte : la tendance ne repose pas sur la
              // seule couleur.
              Icon(
                hausse ? Icons.trending_up : baisse ? Icons.trending_down : Icons.trending_flat,
                size: 20,
                color: couleur,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ecart == 0
                      ? 'Identique ${widget.periode.precedente}, à date égale'
                      : '${Fmt.fcfa(ecart, signe: true)}$pourcent par rapport '
                          '${widget.periode.precedente}, à date égale',
                  style: context.typo.legendeForte.copyWith(color: couleur),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. barres mensuelles ────────────────────────────────────────────────

  Widget _carteBarres(List<PointMensuel> evolution) {
    final sel = _borne(_selection, evolution.length);
    final p = evolution[sel];
    final resume = 'Revenus et dépenses par mois. ${[
      for (final e in evolution)
        '${Fmt.moisAnnee(e.mois)} : revenus ${Fmt.montant(e.revenus)}, '
            'dépenses ${Fmt.montant(e.depenses)} francs CFA'
    ].join('. ')}.';

    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenus et dépenses par mois', style: context.typo.corpsFort),
          const SizedBox(height: 2),
          Text('En FCFA. Touchez un mois.', style: context.typo.corpsDiscret),
          const SizedBox(height: 12),
          GraphiqueBarres(
            points: [
              for (final e in evolution)
                (libelle: Fmt.moisAxe(e.mois), revenus: e.revenus, depenses: e.depenses),
            ],
            selection: sel,
            onSelection: (i) => setState(() => _selection = i),
            resume: resume,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              LegendeGraphique(couleur: context.couleurs.graphiqueRevenus, texte: 'Revenus'),
              LegendeGraphique(couleur: context.couleurs.graphiqueDepenses, texte: 'Dépenses'),
            ],
          ),
          const Divider(height: 24),
          // Lecture chiffree du mois choisi : la valeur exacte, que le
          // graphique ne donne qu'a l'oeil.
          Text(_majuscule(Fmt.moisAnnee(p.mois)), style: context.typo.corpsFort),
          const SizedBox(height: 6),
          _ligneLecture('Revenus', Fmt.fcfa(p.revenus), context.couleurs.graphiqueRevenus),
          _ligneLecture('Dépenses', Fmt.fcfa(p.depenses), context.couleurs.graphiqueDepenses),
          _ligneLecture('Solde du mois', Fmt.fcfa(p.solde, signe: true), null, fort: true),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _tableau = !_tableau),
              icon: Icon(_tableau ? Icons.expand_less : Icons.table_rows_outlined,
                  color: context.couleurs.marque),
              label: Text(_tableau ? 'Masquer le tableau' : 'Voir le tableau des mois',
                  style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
            ),
          ),
          if (_tableau) _TableauMois(evolution: evolution),
        ],
      ),
    );
  }

  Widget _ligneLecture(String libelle, String valeur, Color? pastille, {bool fort = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            if (pastille != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: pastille, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 18),
            Expanded(child: Text(libelle, style: fort ? context.typo.corpsFort : context.typo.corps)),
            Text(valeur, style: fort ? context.typo.corpsFort : context.typo.corps),
          ],
        ),
      );

  // ── 3. solde cumule ─────────────────────────────────────────────────────

  Widget _carteCourbe(List<PointMensuel> evolution) {
    final sel = _borne(_selection, evolution.length);
    final cumuls = <int>[];
    var total = 0;
    for (final e in evolution) {
      total += e.solde;
      cumuls.add(total);
    }
    final resume = 'Solde cumulé depuis le début de la période. ${[
      for (var i = 0; i < evolution.length; i++)
        'Fin ${Fmt.moisAnnee(evolution[i].mois)} : ${Fmt.montant(cumuls[i], signe: true)} francs CFA'
    ].join('. ')}.';

    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solde cumulé', style: context.typo.corpsFort),
          const SizedBox(height: 2),
          Text("Ce que l'exploitation a gagné (ou perdu) depuis le début de la période.",
              style: context.typo.legende),
          const SizedBox(height: 12),
          GraphiqueCourbe(
            points: [
              for (var i = 0; i < evolution.length; i++)
                (libelle: Fmt.moisAxe(evolution[i].mois), valeur: cumuls[i]),
            ],
            selection: sel,
            onSelection: (i) => setState(() => _selection = i),
            resume: resume,
          ),
          const SizedBox(height: 8),
          Text(
            'Fin ${Fmt.moisAnnee(evolution[sel].mois)} : '
            '${Fmt.fcfa(cumuls[sel], signe: true)}',
            style: context.typo.corpsFort,
          ),
        ],
      ),
    );
  }

  // ── 4. repartition des depenses ─────────────────────────────────────────

  Widget _carteRepartition(Rapport r) {
    final lignes = [...r.repartitionDepenses]..sort((a, b) => b.montant.compareTo(a.montant));
    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Où va l’argent ?', style: context.typo.corpsFort),
          const SizedBox(height: 2),
          Text('Dépenses de la période, par poste.', style: context.typo.legende),
          const SizedBox(height: 8),
          if (lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucune dépense sur la période.', style: context.typo.corpsDiscret),
            )
          else
            for (final l in lignes) _LigneRepartition(ligne: l),
        ],
      ),
    );
  }
}

/// Index ramene dans [0, n - 1] : apres une actualisation, la liste peut
/// avoir change de longueur.
int _borne(int i, int n) => i < 0 ? 0 : (i >= n ? n - 1 : i);

String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _TuileFlux extends StatelessWidget {
  const _TuileFlux({required this.couleur, required this.libelle, required this.montant});
  final Color couleur;
  final String libelle;
  final int montant;

  @override
  Widget build(BuildContext context) => Carte(
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LegendeGraphique(couleur: couleur, texte: libelle),
            const SizedBox(height: 6),
            Text(Fmt.montant(montant),
                style: context.typo.titreSection, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('FCFA', style: context.typo.legende),
          ],
        ),
      );
}

/// Les memes chiffres, en tableau : lisibles par un lecteur d'ecran, et
/// verifiables a l'unite pres.
class _TableauMois extends StatelessWidget {
  const _TableauMois({required this.evolution});
  final List<PointMensuel> evolution;

  @override
  Widget build(BuildContext context) {
    TableRow ligne(List<String> cellules, {bool entete = false}) => TableRow(
          decoration: entete
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.couleurs.filet)))
              : null,
          children: [
            for (var i = 0; i < cellules.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  cellules[i],
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: entete ? context.typo.legendeForte : context.typo.legende.copyWith(color: context.couleurs.texte),
                ),
              ),
          ],
        );

    return Table(
      columnWidths: const {0: FlexColumnWidth(1.1)},
      children: [
        ligne(const ['Mois', 'Revenus', 'Dépenses', 'Solde'], entete: true),
        for (final e in evolution)
          ligne([
            Fmt.moisAxe(e.mois),
            Fmt.montant(e.revenus),
            Fmt.montant(e.depenses),
            Fmt.montant(e.solde, signe: true),
          ]),
      ],
    );
  }
}

class _LigneRepartition extends StatelessWidget {
  const _LigneRepartition({required this.ligne});
  final LigneRepartition ligne;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(L.categorieOperation(ligne.categorie), style: context.typo.corps)),
                Text(Fmt.fcfa(ligne.montant), style: context.typo.corpsFort),
                const SizedBox(width: 8),
                Pastille('${ligne.pourcentage.toStringAsFixed(0)} %'),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (ligne.pourcentage / 100).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: context.couleurs.graphiqueDepenses,
                backgroundColor: context.couleurs.filetLeger,
              ),
            ),
          ],
        ),
      );
}
