/// « Dépenses & revenus » : l'argent de l'elevage.
///
/// En haut, le solde du mois mis en scene dans l'en-tete (gagne, depense,
/// reste). Puis deux gros boutons « J'ai dépensé » / « J'ai gagné », les
/// graphiques, et l'historique groupe par mois, sur une periode au choix
/// (audit F22 : la liste etait figee sur trois mois).
///
/// Sources : GET /api/finances/solde (mois en cours, toutes filieres) et
/// GET /api/finances/operations?debut&fin.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../theme/typographie.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/formulaires.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import '../animaux/carnet.dart';
import '../investir/investir.dart';
import 'operation_form.dart';
import 'rapports.dart';
import 'vocabulaire_argent.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Donnees = ({Solde solde, List<Operation> operations});

/// Periodes de l'historique : nombre de mois (mois en cours compris).
const List<(int, String)> _periodes = [
  (1, 'Ce mois'),
  (3, '3 mois'),
  (6, '6 mois'),
  (12, '1 an'),
];

class EcranOperations extends StatefulWidget {
  const EcranOperations({super.key});

  @override
  State<EcranOperations> createState() => _EcranOperationsState();
}

class _EcranOperationsState extends State<EcranOperations> {
  /// Nulle = toutes ; sinon `DEPENSE` ou `REVENU`.
  String? _type;
  int _periode = 1;
  _Donnees? _donnees;
  Object? _erreur;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final maintenant = DateTime.now();
    final debut = DateTime(maintenant.year, maintenant.month - (_periodes[_periode].$1 - 1), 1);
    try {
      final r = await Future.wait([
        FinanceApi.soldeDuMois(),
        FinanceApi.operations(debut: debut, fin: maintenant),
      ]);
      if (!mounted) return;
      setState(() => _donnees = (solde: r[0] as Solde, operations: r[1] as List<Operation>));
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _puisRecharger(Widget ecran) async {
    await ouvrir<void>(context, ecran);
    await _charger();
  }

  Future<void> _surOperation(Operation o) async {
    if (!o.issueDUnMouvement) {
      await _puisRecharger(EcranOperation(existante: o));
      return;
    }
    final lieu = o.uniteCode ?? 'cet élevage';
    if (o.uniteId == null) {
      await afficherInfo(context, 'Argent d’une vente',
          message: 'Il vient de la vente notée dans le carnet de $lieu. '
              'Pour la corriger, annulez la vente dans ce carnet.');
      return;
    }
    final ouvrirCarnet = await choisirSuite(context, 'Argent d’une vente',
        message: 'Il vient de la vente notée dans le carnet de $lieu. '
            'Pour la corriger, annulez la vente dans ce carnet.',
        premier: 'Ouvrir le carnet',
        second: 'Fermer');
    if (ouvrirCarnet == true && mounted) {
      await _puisRecharger(EcranCarnet(uniteId: o.uniteId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _donnees;
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Column(
        children: [
          EnteteVivant(
            titre: 'Dépenses & revenus',
            retour: true,
            bas: _Solde(solde: d?.solde),
          ),
          Expanded(
            child: d == null
                ? (_erreur != null
                    ? EtatErreur(erreur: _erreur!, onReessayer: _charger)
                    : SingleChildScrollView(padding: lisible(context), 
                        child: const Padding(
                            padding: EdgeInsets.only(top: 16), child: ListeSquelette())))
                : RefreshIndicator(
                    onRefresh: _charger,
                    color: context.couleurs.marque,
                    child: _corps(d),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _corps(_Donnees d) {
    final liste = d.operations.where((o) => _type == null || o.type == _type).toList();
    final enfants = <Widget>[];
    String? mois;
    for (var i = 0; i < liste.length; i++) {
      final o = liste[i];
      final cle = o.dateOperation == null
          ? '—'
          : '${o.dateOperation!.year}-${o.dateOperation!.month.toString().padLeft(2, '0')}';
      if (cle != mois) {
        mois = cle;
        final duMois = liste.where((x) =>
            x.dateOperation != null &&
            '${x.dateOperation!.year}-${x.dateOperation!.month.toString().padLeft(2, '0')}' == cle);
        final total = duMois.fold<int>(0, (s, x) => s + x.montantSigne);
        enfants.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(_majuscule(Fmt.moisAnnee(cle)), style: context.typo.corpsFort),
              ),
              Text(Fmt.fcfa(total, signe: true), style: context.typo.legendeForte),
            ],
          ),
        ));
      }
      enfants.add(Apparition(
        rang: i % 8,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LigneOperation(operation: o, onTap: () => _surOperation(o)),
        ),
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: _GrosBoutonArgent(
                libelle: "J'ai dépensé",
                icone: Icons.remove_rounded,
                type: 'DEPENSE',
                onTap: () => _puisRecharger(const EcranOperation(type: 'DEPENSE')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GrosBoutonArgent(
                libelle: "J'ai gagné",
                icone: Icons.add_rounded,
                type: 'REVENU',
                onTap: () => _puisRecharger(const EcranOperation(type: 'REVENU')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CarteAcces(
          icone: Icons.bar_chart_rounded,
          titre: 'Voir les graphiques',
          detail: 'Par mois, par poste de dépense',
          onTap: () => _puisRecharger(const EcranRapports()),
        ),
        const SizedBox(height: 10),
        CarteAcces(
          icone: Icons.savings_outlined,
          titre: 'Où investir mon argent ?',
          detail: 'Quelle filière démarrer avec mon budget',
          onTap: () => _puisRecharger(const EcranInvestir()),
        ),
        const SizedBox(height: 8),
        const TitreSectionVivantSansMarge('Historique'),
        SizedBox(
          height: Dim.hauteurTactile,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _periodes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _Pilule(
              libelle: _periodes[i].$2,
              actif: i == _periode,
              onTap: () {
                setState(() => _periode = i);
                _charger();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Segments<String?>(
          options: const [(null, 'Tout'), ('DEPENSE', 'Dépenses'), ('REVENU', 'Revenus')],
          valeur: _type,
          onChange: (t) => setState(() => _type = t),
        ),
        if (_chargement) LinearProgressIndicator(minHeight: 2, color: context.couleurs.accent),
        const SizedBox(height: 4),
        if (liste.isEmpty)
          const EtatVide('Rien de noté sur cette période.',
              icone: Icons.account_balance_wallet_outlined)
        else
          ...enfants,
      ],
    );
  }
}

String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Titre de section a trait orange, sans les marges laterales (le corps
/// porte deja la gouttiere).
class TitreSectionVivantSansMarge extends StatelessWidget {
  const TitreSectionVivantSansMarge(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(texte, style: context.typo.titreSection)),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                  color: context.couleurs.accent, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      );
}

/// Le solde du mois porte par l'en-tete : grand chiffre anime, puis
/// « Gagné » et « Dépensé » en pilules.
class _Solde extends StatelessWidget {
  const _Solde({required this.solde});
  final Solde? solde;

  @override
  Widget build(BuildContext context) {
    final s = solde;
    final mois = Fmt.moisLong(DateTime.now().month);
    final blanc = context.typo.legendeForte.copyWith(color: context.couleurs.surMarqueDiscret);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Il vous reste en $mois', style: blanc),
        const SizedBox(height: 4),
        if (s == null)
          const SizedBox(height: 34, width: 180)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: CompteurAnime(
                  valeur: s.solde,
                  style: context.typo.chiffreHeros.copyWith(color: context.couleurs.surEntete),
                  format: (n) => Fmt.montant(n, signe: true),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('FCFA', style: context.typo.corpsFort.copyWith(color: context.couleurs.surMarqueDiscret)),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PiluleFlux(
                  icone: Icons.arrow_downward_rounded,
                  libelle: 'Gagné',
                  montant: s?.revenus),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PiluleFlux(
                  icone: Icons.arrow_upward_rounded,
                  libelle: 'Dépensé',
                  montant: s?.depenses),
            ),
          ],
        ),
      ],
    );
  }
}

class _PiluleFlux extends StatelessWidget {
  const _PiluleFlux({required this.icone, required this.libelle, required this.montant});
  final IconData icone;
  final String libelle;
  final int? montant;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
              child: Icon(icone, size: 18, color: context.couleurs.surAccent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle, style: context.typo.legende.copyWith(color: context.couleurs.surMarqueDiscret)),
                  Text(montant == null ? '…' : Fmt.montant(montant!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _GrosBoutonArgent extends StatelessWidget {
  const _GrosBoutonArgent(
      {required this.libelle, required this.icone, required this.type, required this.onTap});
  final String libelle;
  final IconData icone;
  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        rayon: 16,
        libelle: libelle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: couleurType(context, type).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 30, color: couleurType(context, type)),
              ),
              const SizedBox(height: 8),
              Text(libelle, style: context.typo.corpsFort, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _Pilule extends StatelessWidget {
  const _Pilule({required this.libelle, required this.actif, required this.onTap});
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: actif,
        button: true,
        child: Material(
          color: actif ? context.couleurs.marque : context.couleurs.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: actif ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(libelle,
                    style: Typo.bouton
                        .copyWith(color: actif ? context.couleurs.surMarque : context.couleurs.texte)),
              ),
            ),
          ),
        ),
      );
}

/// Une ligne d'argent : pictogramme de la categorie, libelle, elevage et
/// date, montant signe.
class LigneOperation extends StatelessWidget {
  const LigneOperation({super.key, required this.operation, this.onTap});
  final Operation operation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final o = operation;
    final revenu = o.type == 'REVENU';
    final titre = (o.libelle == null || o.libelle!.isEmpty)
        ? L.categorieOperation(o.categorie)
        : corrigerLibelle(o.libelle!);
    final contexte = [
      Fmt.dateCourte(o.dateOperation),
      o.uniteCode ?? 'Toute la ferme',
    ].join(' · ');
    final contenu = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: couleurType(context, o.type).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconeCategorie(o.categorie), color: couleurType(context, o.type), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: context.typo.corpsFort, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(contexte, style: context.typo.legende),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.montant(o.montantSigne, signe: true),
                style: context.typo.titreSection.copyWith(
                    fontSize: 18, color: revenu ? context.couleurs.marque : context.couleurs.texte),
              ),
              if (o.issueDUnMouvement) const Pastille('Vente'),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
            color: context.couleurs.surface, borderRadius: BorderRadius.circular(Dim.rayon)),
        child: contenu,
      );
    }
    return Pressable(onTap: onTap, child: contenu);
  }
}
