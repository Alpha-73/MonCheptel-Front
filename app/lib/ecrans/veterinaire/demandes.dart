/// Maquettes : « Veto - Eleveurs orientes » (devenue la file de tri) et
/// « Veto - Demande detail » (devenue la fiche de cas). La clôture est dans
/// cloture.dart.
///
/// Sources : GET /api/signalements/file (par statut), GET
/// /api/signalements/{id} (ouverture depuis une notification), POST
/// /api/signalements/{id}/prise-en-charge.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/barre_etat.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../theme/typographie.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/echafaudage.dart';
import '../../widgets/etats.dart';
import '../../widgets/navigation.dart';
import '../../widgets/pastille.dart';
import '../../widgets/vivant.dart';
import 'cloture.dart';
import 'commun_veterinaire.dart';
import '../../widgets/mise_en_page.dart';

/// Ouvre la fiche d'un cas, puis suit le choix fait après la clôture :
/// rester, revenir aux demandes, ou à l'accueil. [recharger] est appelé au
/// retour dans tous les cas.
Future<void> ouvrirDemande(BuildContext context, Signalement s,
    {required Future<void> Function() recharger,
    required ValueChanged<int> versOnglet}) async {
  final onglet = await ouvrir<int>(context, EcranDemande(signalement: s));
  await recharger();
  if (onglet != null) versOnglet(onglet);
}

// ── file de tri ───────────────────────────────────────────────────────────

/// Onglets de la file.
abstract final class OngletFile {
  static const int attente = 0;
  static const int traites = 1;
}

class EleveursOrientes extends StatefulWidget {
  const EleveursOrientes(
      {super.key, required this.versOnglet, this.ongletInitial = OngletFile.attente});
  final ValueChanged<int> versOnglet;

  /// [OngletFile.traites] depuis la tuile « Cas traités » de l'accueil.
  final int ongletInitial;

  @override
  State<EleveursOrientes> createState() => _EleveursOrientesState();
}

class _EleveursOrientesState extends State<EleveursOrientes> {
  late int _onglet = widget.ongletInitial;

  /// Filtre de gravite : null = toutes.
  String? _gravite;

  static Future<(Demandes, Demandes)> _charger() async {
    final r = await Future.wait([chargerEnAttente(), chargerTraites()]);
    return (r[0], r[1]);
  }

  @override
  Widget build(BuildContext context) {
    const entete = EnteteClair(titre: 'Éleveurs orientés');
    return ChargeurVeto<(Demandes, Demandes)>(
      entete: entete,
      charger: _charger,
      construire: (context, d, recharger) {
        final (attente, traites) = d;
        final source = _onglet == OngletFile.attente ? attente.liste : traites.liste;
        final liste =
            _gravite == null ? source : source.where((s) => s.gravite == _gravite).toList();
        final nouveaux = [for (final s in liste) if (s.statut == 'ORIENTE') s];
        final enCours = [for (final s in liste) if (s.statut != 'ORIENTE') s];
        var rang = 0;
        Widget carte(Signalement s) => Padding(
              padding: const EdgeInsets.only(bottom: Dim.ecart),
              child: Apparition(
                rang: rang++,
                child: CarteCas(
                  signalement: s,
                  onTap: () => ouvrirDemande(context, s,
                      recharger: recharger, versOnglet: widget.versOnglet),
                ),
              ),
            );
        return Column(
          children: [
            entete,
            Onglets(
              libelles: [
                'En attente (${attente.total})',
                'Traités (${traites.total})',
              ],
              indexActif: _onglet,
              onChange: (i) => setState(() => _onglet = i),
            ),
            const SizedBox(height: 8),
            _FiltreGravite(
              valeur: _gravite,
              source: source,
              onChange: (g) => setState(() => _gravite = g),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: recharger,
                color: context.couleurs.marque,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 24)),
                  children: [
                    if (liste.isEmpty)
                      EtatVide(
                        _gravite != null
                            ? 'Aucun cas de cette gravité.'
                            : _onglet == OngletFile.attente
                                ? 'Aucun éleveur ne vous attend. Les signalements des '
                                    'maladies que vous traitez arriveront ici.'
                                : "Vous n'avez encore traité aucun cas.",
                        icone: Icons.groups_outlined,
                      ),
                    if (_onglet == OngletFile.traites)
                      for (final s in liste) carte(s)
                    else ...[
                      if (nouveaux.isNotEmpty) _Groupe('À accepter', nouveaux.length),
                      for (final s in nouveaux) carte(s),
                      if (enCours.isNotEmpty) _Groupe('Acceptés', enCours.length),
                      for (final s in enCours) carte(s),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Groupe extends StatelessWidget {
  const _Groupe(this.titre, this.nombre);
  final String titre;
  final int nombre;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Semantics(
          header: true,
          child: Text('${titre.toUpperCase()} · $nombre',
              style: context.typo.legende.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ),
      );
}

/// Pastilles « Tous · Élevé · Moyen · Faible », avec le nombre de cas.
class _FiltreGravite extends StatelessWidget {
  const _FiltreGravite({required this.valeur, required this.source, required this.onChange});
  final String? valeur;
  final List<Signalement> source;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    int nb(String g) => source.where((s) => s.gravite == g).length;
    final options = <(String?, String, Color?)>[
      (null, 'Tous ${source.length}', null),
      for (final g in const ['ELEVE', 'MOYEN', 'FAIBLE'])
        if (nb(g) > 0) (g, '${L.gravite(g)} ${nb(g)}', couleurGravite(context, g)),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
        children: [
          for (final (g, libelle, couleur) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: valeur == g,
                onSelected: (_) => onChange(g),
                showCheckmark: false,
                avatar: couleur == null
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                label: Text(libelle),
                labelStyle: context.typo.legendeForte.copyWith(
                    color: valeur == g ? context.couleurs.surMarque : context.couleurs.texte,
                    fontWeight: FontWeight.w700),
                selectedColor: context.couleurs.marque,
                backgroundColor: context.couleurs.surface,
                side: BorderSide(color: valeur == g ? context.couleurs.marque : context.couleurs.filet),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compatibilite : une demande dans une liste (voir [CarteCas]).
class CarteDemande extends StatelessWidget {
  const CarteDemande({super.key, required this.signalement, required this.onTap});
  final Signalement signalement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CarteCas(signalement: signalement, onTap: onTap);
}

// ── fiche de cas ──────────────────────────────────────────────────────────

/// Ouverture par identifiant (notification) : GET /api/signalements/{id}.
class EcranDemandeParId extends StatelessWidget {
  const EcranDemandeParId({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) => Chargeur<Signalement>(
        titreEcran: 'Demande',
        clair: true,
        charger: () => VeterinaireGardeApi.lire(id),
        construire: (context, s, _) => EcranDemande(signalement: s),
      );
}

class EcranDemande extends StatefulWidget {
  const EcranDemande(
      {super.key,
      required this.signalement,
      this.prendreEnCharge = SignalementApi.prendreEnCharge,
      this.refuser = SignalementApi.refuser});
  final Signalement signalement;

  /// POST /api/signalements/{id}/prise-en-charge (accepter) ; injectable
  /// pour les tests.
  final Future<Signalement> Function(int id) prendreEnCharge;

  /// POST /api/signalements/{id}/refus (V14) ; injectable pour les tests.
  final Future<Signalement> Function(int id, {String? motif}) refuser;

  @override
  State<EcranDemande> createState() => _EcranDemandeState();
}

class _EcranDemandeState extends State<EcranDemande> {
  late Signalement _s = widget.signalement;

  bool _priseEnCours = false;

  // Ouvrir une demande n'est PAS la prendre en charge (relecture, point 6).
  // Depuis l'audit du 29 octobre (V14), le veterinaire ACCEPTE ou REFUSE un
  // cas confie. Appeler l'eleveur n'engage plus a rien : on peut appeler
  // pour juger avant de decider. Seule la cloture vaut acceptation.

  /// Accepte le cas s'il est encore seulement confie. [explicite] : geste
  /// du bouton, dont l'echec s'affiche ; sinon en silence (la cloture).
  Future<void> _prendreEnCharge({bool explicite = false}) async {
    if (_s.statut != 'ORIENTE' || _priseEnCours) return;
    setState(() => _priseEnCours = true);
    try {
      final s = await widget.prendreEnCharge(_s.id);
      if (mounted) setState(() => _s = s);
      if (explicite && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cas accepté. L'éleveur est prévenu.")));
      }
    } on ApiException catch (e) {
      if (explicite && mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _priseEnCours = false);
    }
  }

  Future<void> _appeler() async {
    await appeler(context, _s.eleveurTelephone);
  }

  /// Refuse le cas confie (V14) : motif facultatif, l'eleveur est prevenu
  /// et choisit un autre veterinaire. Le cas quitte la file.
  Future<void> _refuser() async {
    if (_s.statut != 'ORIENTE' || _priseEnCours) return;
    final nom = _s.eleveurNom ?? "L'éleveur";
    final motif = await demanderMotif(context, 'Refuser ce cas ?',
        message: '$nom sera prévenu et choisira un autre vétérinaire.',
        confirmer: 'Refuser le cas',
        indication: 'Motif pour l’éleveur (facultatif)');
    if (motif == null || !mounted) return;
    setState(() => _priseEnCours = true);
    try {
      await widget.refuser(_s.id, motif: motif);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Cas refusé. L'éleveur va choisir un autre vétérinaire.")));
      await Navigator.of(context).maybePop(OngletVeto.eleveurs);
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _priseEnCours = false);
    }
  }

  Future<void> _cloturer() async {
    await _prendreEnCharge();
    if (!mounted) return;
    final r = await ouvrir<ResultatCloture>(context, EcranCloture(signalement: _s));
    if (r == null || !mounted) return;
    if (r.recharger) {
      Navigator.of(context).pop(OngletVeto.eleveurs);
      return;
    }
    if (r.signalement != null) setState(() => _s = r.signalement!);
    if (r.onglet != null) Navigator.of(context).pop(r.onglet);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final numero = aUnNumero(s.eleveurTelephone);
    final nom = s.eleveurNom ?? "l'éleveur";
    var rang = 0;
    Widget bloc(Widget w) => Padding(
          padding: const EdgeInsets.only(bottom: Dim.ecart),
          child: Apparition(rang: rang++, child: w),
        );
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Column(
        children: [
          _BandeauCas(s),
          Expanded(
            child: ListView(
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 24)),
              children: [
                if (s.statut == 'ORIENTE')
                  bloc(_CartePriseEnCharge(
                      enCours: _priseEnCours,
                      onAccepter: () => _prendreEnCharge(explicite: true),
                      onRefuser: _refuser)),
                bloc(_Frise(s)),
                if (s.traite) bloc(_CarteCompteRendu(s)),
                bloc(_CarteDiagnostic(s)),
                bloc(_CarteSymptomes(s)),
                bloc(_CarteEleveur(s)),
                bloc(_CarteAnimaux(s)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BarreActions(
        enfants: [
          // Confie, pas encore accepte : on peut appeler pour juger ; la
          // cloture attend l'acceptation (carte ci-dessus).
          if (s.statut == 'ORIENTE')
            numero
                ? BoutonPrincipal('Appeler $nom',
                    icone: Icons.call_rounded,
                    grand: true,
                    onPressed: _appeler)
                : const _SansNumero()
          else if (s.traite)
            numero
                ? BoutonPrincipal('Appeler $nom',
                    icone: Icons.call_rounded,
                    grand: true,
                    onPressed: _appeler)
                : const _SansNumero()
          else if (numero) ...[
            BoutonPrincipal('Appeler',
                icone: Icons.call_rounded,
                grand: true,
                onPressed: _appeler),
            BoutonSecondaire('Clôturer', icone: Icons.task_alt_rounded, grand: true,
                onPressed: _cloturer),
          ] else ...[
            const _SansNumero(),
            BoutonPrincipal('Clôturer le cas',
                icone: Icons.task_alt_rounded, grand: true, onPressed: _cloturer),
          ],
        ],
      ),
    );
  }
}

/// « Ce cas vous est confié » : accepter ou refuser (V14).
class _CartePriseEnCharge extends StatelessWidget {
  const _CartePriseEnCharge(
      {required this.enCours, required this.onAccepter, required this.onRefuser});
  final bool enCours;
  final VoidCallback onAccepter;
  final VoidCallback onRefuser;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Dim.ecart),
        decoration: BoxDecoration(
          color: context.couleurs.fondAccentPale,
          borderRadius: BorderRadius.circular(Dim.rayon),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ce cas vous est confié', style: context.typo.corpsFort),
            const SizedBox(height: 4),
            Text(
                "Acceptez-le si vous pouvez le suivre. Sinon, refusez-le : "
                "l'éleveur en choisira un autre.",
                style: context.typo.corpsDiscret),
            const SizedBox(height: 10),
            BoutonPrincipal('Accepter le cas',
                icone: Icons.check_rounded, onPressed: enCours ? null : onAccepter),
            const SizedBox(height: 8),
            BoutonSecondaire('Refuser', icone: Icons.close_rounded,
                onPressed: enCours ? null : onRefuser),
          ],
        ),
      );
}

/// Barre d'actions fixe, a portee de pouce.
class _BarreActions extends StatelessWidget {
  const _BarreActions({required this.enfants});
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          boxShadow: [
            BoxShadow(color: context.couleurs.ombrePanneau, blurRadius: 12, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 12, Dim.gouttiere, 12),
            child: Row(
              children: [
                for (var i = 0; i < enfants.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(flex: i == 0 && enfants.length > 1 ? 3 : 2, child: enfants[i]),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Bouton d'appel desactive, qui dit pourquoi.
class _SansNumero extends StatelessWidget {
  const _SansNumero();

  @override
  Widget build(BuildContext context) => const BoutonSecondaire('Numéro non renseigné',
      icone: Icons.phone_disabled_outlined, grand: true);
}

/// Bandeau plein a la couleur de la gravite : maladie et anciennete en
/// grand, retour a gauche.
class _BandeauCas extends StatelessWidget {
  const _BandeauCas(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) {
    // Texte blanc sur rouge et vert (AA) ; vert sombre sur orange.
    final (fond, encre) = switch (s.gravite) {
      'ELEVE' => (context.couleurs.graviteHaute, context.couleurs.surEntete),
      'MOYEN' => (context.couleurs.graviteMoyenne, context.couleurs.surAccent),
      _ => (context.couleurs.enteteFin, context.couleurs.surEntete),
    };
    // Icones de la barre d'etat claires sur rouge et vert, sombres sur orange.
    final style = encre == context.couleurs.surEntete ? BarreEtat.surMarque : BarreEtat.surClair;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: Container(
        width: double.infinity,
        color: fond,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  4, MediaQuery.paddingOf(context).top + 4, Dim.gouttiere, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Retour',
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(Icons.arrow_back_rounded, color: encre),
                    ),
                    Expanded(
                      child: Text(L.graviteLongue(s.gravite).toUpperCase(),
                          style: Typo.pastille.copyWith(color: encre, letterSpacing: 0.6)),
                    ),
                    if (s.traite)
                      Text('TRAITÉ',
                          style: Typo.pastille.copyWith(color: encre, letterSpacing: 0.6)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: Dim.gouttiere - 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(s.maladie ?? 'Maladie non identifiée',
                                    style: Typo.titreEcran.copyWith(color: encre, fontSize: 24)),
                              ),
                              Text(
                                [s.eleveurNom ?? 'Éleveur', ligneUnite(s)].join(' · '),
                                style: context.typo.legendeForte.copyWith(color: encre),
                              ),
                            ],
                          ),
                        ),
                        if (!s.traite) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(ancienneteCourte(s.dateSignalement),
                                  style: context.typo.chiffreHeros.copyWith(color: encre, fontSize: 30)),
                              Text("d'attente", style: context.typo.legendeForte.copyWith(color: encre)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Signalé → Confié → Accepté → Traité ».
class _Frise extends StatelessWidget {
  const _Frise(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) {
    final atteinte = switch (s.statut) {
      'TRAITE' => 3,
      'EN_COURS' => 2,
      'ORIENTE' => 1,
      _ => 0,
    };
    const etapes = ['Signalé', 'Confié', 'Accepté', 'Traité'];
    final dates = [Fmt.dateCourte(s.dateSignalement), '', '', Fmt.dateCourte(s.dateTraitement)];
    return Semantics(
      label: 'Étape : ${etapes[atteinte]}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < etapes.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: Container(
                              height: 3,
                              color: i == 0
                                  ? Colors.transparent
                                  : (i <= atteinte ? context.couleurs.marque : context.couleurs.sable))),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: i <= atteinte ? context.couleurs.marque : context.couleurs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: i == atteinte ? context.couleurs.accent : context.couleurs.marque, width: 2),
                        ),
                      ),
                      Expanded(
                          child: Container(
                              height: 3,
                              color: i == etapes.length - 1
                                  ? Colors.transparent
                                  : (i < atteinte ? context.couleurs.marque : context.couleurs.sable))),
                    ]),
                    const SizedBox(height: 4),
                    Text(etapes[i],
                        textAlign: TextAlign.center,
                        style: context.typo.legende.copyWith(
                            fontSize: 12.5,
                            color: i <= atteinte ? context.couleurs.texte : context.couleurs.texteDiscret,
                            fontWeight: i == atteinte ? FontWeight.w800 : FontWeight.w600)),
                    if (i <= atteinte && dates[i].isNotEmpty && dates[i] != '—')
                      Text(dates[i], style: context.typo.legende.copyWith(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteCompteRendu extends StatelessWidget {
  const _CarteCompteRendu(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) => Carte(
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TitreCarte('VOTRE COMPTE RENDU'),
            Row(children: [
              Icon(Icons.verified_outlined, color: context.couleurs.marque, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.maladieConfirmee == null
                      ? 'Diagnostic non posé'
                      : 'Diagnostic retenu : ${s.maladieConfirmee}',
                  style: context.typo.corpsFort,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(s.compteRendu ?? '—', style: context.typo.corps),
            const SizedBox(height: 6),
            Text('Traité le ${Fmt.date(s.dateTraitement)}', style: context.typo.legende),
          ],
        ),
      );
}

/// Ce que dit l'outil : hypothese, autre hypothese, protocole de reference.
class _CarteDiagnostic extends StatelessWidget {
  const _CarteDiagnostic(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) {
    final p = s.diagnostic?.probable;
    final a = s.diagnostic?.alternative;
    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TitreCarte("DIAGNOSTIC DE L'OUTIL"),
          if (p == null)
            Text('Les symptômes ne désignent aucune maladie du catalogue.',
                style: context.typo.corpsDiscret)
          else ...[
            _Hypothese(libelle: 'Maladie probable', m: p),
            if (a != null && a.id != p.id) ...[
              Divider(height: 18, color: context.couleurs.filetLeger),
              _Hypothese(libelle: 'Autre hypothèse', m: a),
            ],
            if ((p.traitement ?? '').trim().isNotEmpty ||
                (p.symptomesTexte ?? '').trim().isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: context.couleurs.marque,
                  collapsedIconColor: context.couleurs.marque,
                  title: Text('Protocole de référence',
                      style: context.typo.corpsFort.copyWith(color: context.couleurs.marque)),
                  children: [
                    if ((p.symptomesTexte ?? '').trim().isNotEmpty) ...[
                      Text('Signes typiques', style: context.typo.legendeForte),
                      Text(p.symptomesTexte!.trim(), style: context.typo.corps),
                      const SizedBox(height: 8),
                    ],
                    if ((p.traitement ?? '').trim().isNotEmpty) ...[
                      Text('Conduite à tenir', style: context.typo.legendeForte),
                      Text(p.traitement!.trim(), style: context.typo.corps),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Hypothese extends StatelessWidget {
  const _Hypothese({required this.libelle, required this.m});
  final String libelle;
  final Maladie m;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 5,
            height: 40,
            decoration: BoxDecoration(
                color: couleurGravite(context, m.gravite), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: context.typo.legende),
                Text(m.nom, style: context.typo.corpsFort),
              ],
            ),
          ),
          Pastille(L.gravite(m.gravite), ton: L.tonGravite(m.gravite)),
        ],
      );
}

class _CarteSymptomes extends StatelessWidget {
  const _CarteSymptomes(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) => Carte(
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TitreCarte('SYMPTÔMES DÉCLARÉS'),
            if (s.symptomes.isEmpty)
              Text('Aucun symptôme transmis.', style: context.typo.corpsDiscret)
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final sy in s.symptomes) PuceSymptome(sy.libelle),
              ]),
            if (s.precision != null && s.precision!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Encart(
                  titre: '« ${s.precision!.trim()} »',
                  ton: s.gravite == 'ELEVE' ? TonEncart.erreur : TonEncart.attention,
                  fort: false,
                ),
              ),
            ],
          ],
        ),
      );
}

class _CarteEleveur extends StatelessWidget {
  const _CarteEleveur(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) => Carte(
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TitreCarte("L'ÉLEVEUR"),
            Row(
              children: [
                Avatar(Fmt.initiales(s.eleveurNom ?? '?'), taille: 46, pale: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.eleveurNom ?? 'Éleveur', style: context.typo.corpsFort),
                      Text(
                        [
                          if (s.eleveurZone != null) s.eleveurZone!,
                          if (aUnNumero(s.eleveurTelephone))
                            s.eleveurTelephone!
                          else
                            'Numéro non renseigné',
                        ].join(' · '),
                        style: context.typo.legende,
                      ),
                    ],
                  ),
                ),
                if (!s.traite)
                  BoutonAppelRond(nom: s.eleveurNom ?? "l'éleveur", numero: s.eleveurTelephone),
              ],
            ),
          ],
        ),
      );
}

class _CarteAnimaux extends StatelessWidget {
  const _CarteAnimaux(this.s);
  final Signalement s;

  @override
  Widget build(BuildContext context) {
    final effectif = s.uniteEffectif;
    final lot = effectif != null && effectif > 1;
    return Carte(
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TitreCarte('ANIMAUX CONCERNÉS'),
          _Ligne(lot ? 'Lot' : 'Animal', s.uniteCode ?? '—'),
          if (s.uniteType != null) _Ligne('Type', s.uniteType!),
          if (lot) _Ligne('Effectif du lot', '$effectif sujets'),
          if (afficherSujetsTouches(s))
            _Ligne('Sujets touchés', L.tranche(s.trancheEffectif),
                couleur: encreGravite(context, s.gravite)),
        ],
      ),
    );
  }
}

/// « Lot ........ LOT #024 » : libelle a gauche, valeur en gras a droite.
class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur, {this.couleur});
  final String libelle;
  final String valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libelle, style: context.typo.corpsDiscret),
            const SizedBox(width: 16),
            Expanded(
              child: Text(valeur,
                  textAlign: TextAlign.right, style: context.typo.corpsFort.copyWith(color: couleur)),
            ),
          ],
        ),
      );
}
