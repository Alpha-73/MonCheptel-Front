/// Clôture d'un cas, en plein écran (ancien dialogue « Compte rendu »).
///
/// Source : POST /api/signalements/{id}/cloture
/// {compteRendu, maladieConfirmeeId?} et, pour « Autre maladie… »,
/// GET /api/signalements/maladies-catalogue filtré par filière.
///
/// Pensée pour une main et peu de saisie :
///  - la maladie probable de l'outil est présélectionnée ; l'autre
///    hypothèse, une maladie du catalogue ou « Diagnostic non posé » se
///    choisissent d'un toucher ;
///  - des phrases toutes faites composent le compte rendu (le back l'exige
///    non vide) ; le texte libre n'est qu'un complément ;
///  - l'écran ne se ferme pas par erreur : quitter avec un compte rendu
///    commencé demande confirmation ;
///  - 422 (déjà clôturé), 403 (confié à un confrère), 404 et 409 (modifié
///    entre-temps) renvoient à la liste rechargée.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/typographie.dart';
import '../../widgets/boutons.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/vivant.dart';
import 'commun_veterinaire.dart';
import '../../widgets/mise_en_page.dart';

/// Envoi de la clôture ; injectable pour les tests.
typedef EnvoyerCloture = Future<Signalement> Function(
    int id, String compteRendu, int? maladieConfirmeeId);

Future<Signalement> _envoyerParDefaut(int id, String compteRendu, int? maladieId) =>
    VeterinaireGardeApi.cloturer(id, compteRendu, maladieConfirmeeId: maladieId);

/// Ce que rend l'écran de clôture à la fiche du cas.
class ResultatCloture {
  const ResultatCloture({this.signalement, this.onglet, this.recharger = false});

  /// Le cas clôturé, tel que le back l'a rendu.
  final Signalement? signalement;

  /// Onglet où aller ensuite (OngletVeto), si le vétérinaire l'a choisi.
  final int? onglet;

  /// Le cas a changé ailleurs (clos, réattribué) : revenir à la liste.
  final bool recharger;
}

/// Phrases toutes faites, dans l'ordre du geste le plus fréquent.
const List<String> phrasesCompteRendu = [
  'Vaccination faite',
  'Lot isolé',
  'Traitement prescrit',
  'Visite prévue',
  'Abattage sanitaire conseillé',
];

/// Assemble le compte rendu envoyé au back : phrases choisies, puis le
/// complément libre. Vide si rien n'est choisi ni écrit.
String composerCompteRendu(Iterable<String> phrases, String complement) {
  final morceaux = [
    for (final p in phrasesCompteRendu)
      if (phrases.contains(p)) '$p.',
    if (complement.trim().isNotEmpty) complement.trim(),
  ];
  return morceaux.join(' ');
}

class EcranCloture extends StatefulWidget {
  const EcranCloture({
    super.key,
    required this.signalement,
    this.envoyer = _envoyerParDefaut,
    this.catalogue = SignalementApi.catalogueComplet,
  });

  final Signalement signalement;
  final EnvoyerCloture envoyer;
  final Future<List<Maladie>> Function() catalogue;

  @override
  State<EcranCloture> createState() => _EcranClotureState();
}

/// Le choix de maladie : une maladie, ou « non posé ».
typedef _Choix = ({int? id, String nom});

const _Choix _nonPose = (id: null, nom: 'Diagnostic non posé');

class _EcranClotureState extends State<EcranCloture> {
  final _complement = TextEditingController();
  final _defilement = ScrollController();
  final Set<String> _phrases = {};
  late _Choix? _choix = _proposee == null ? null : (id: _proposee!.id, nom: _proposee!.nom);

  /// Une maladie que le back acceptera pour cette unite : elle touche sa
  /// filiere (audit global G6). Sans filiere connue, on ne filtre pas.
  bool _admissible(Maladie? m) {
    final f = widget.signalement.uniteFiliere;
    return m != null && (f == null || m.filieres.contains(f));
  }

  /// Maladie prise dans le catalogue (« Autre maladie… »).
  _Choix? _autre;
  String? _erreurCompteRendu;
  String? _erreurChoix;
  bool _envoi = false;
  Signalement? _clos;

  // Une hypothese d'une autre filiere (PPR ovins ET caprins sur un lot de
  // caprins... ou l'inverse) n'est ni proposee ni preselectionnee : le back
  // la refuserait en 422.
  Maladie? get _proposee {
    final m = widget.signalement.diagnostic?.probable;
    return _admissible(m) ? m : null;
  }

  Maladie? get _alternative {
    final m = widget.signalement.diagnostic?.alternative;
    return _admissible(m) ? m : null;
  }

  String get _compteRendu => composerCompteRendu(_phrases, _complement.text);

  bool get _commence =>
      _phrases.isNotEmpty ||
      _complement.text.trim().isNotEmpty ||
      _choix?.id != _proposee?.id;

  @override
  void dispose() {
    _complement.dispose();
    _defilement.dispose();
    super.dispose();
  }

  // ── sortie ──────────────────────────────────────────────────────────────

  Future<void> _quitter() async {
    if (_envoi) return;
    final nav = Navigator.of(context);
    if (_clos != null) {
      nav.pop(ResultatCloture(signalement: _clos));
      return;
    }
    if (_commence) {
      final ok = await confirmer(context, 'Abandonner la clôture ?',
          message: 'Le compte rendu commencé sera perdu.',
          confirmer: 'Abandonner',
          annuler: 'Continuer la saisie');
      if (!ok || !mounted) return;
    }
    nav.pop();
  }

  // ── choix de la maladie ─────────────────────────────────────────────────

  /// Filtre du catalogue : la filiere de l'unite (audit global G6). Les
  /// filieres des hypotheses ne servent que si le back ne l'a pas donnee.
  List<String> get _filieres {
    final f = widget.signalement.uniteFiliere;
    if (f != null) return [f];
    final d = widget.signalement.diagnostic;
    return L.trierFilieres({...?d?.probable?.filieres, ...?d?.alternative?.filieres});
  }

  Future<void> _chercherAutre() async {
    final m = await showModalBottomSheet<Maladie>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.couleurs.fond,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Dim.rayonPanneau))),
      builder: (_) => _FeuilleCatalogue(charger: widget.catalogue, filieres: _filieres),
    );
    if (m == null || !mounted) return;
    setState(() {
      _autre = (id: m.id, nom: m.nom);
      _choix = _autre;
      _erreurChoix = null;
    });
  }

  void _choisir(_Choix c) => setState(() {
        _choix = c;
        _erreurChoix = null;
      });

  // ── envoi ───────────────────────────────────────────────────────────────

  Future<void> _cloturer() async {
    final texte = _compteRendu;
    setState(() {
      _erreurCompteRendu = texte.isEmpty
          ? 'Touchez une phrase ou écrivez quelques mots : le compte rendu est obligatoire.'
          : null;
      _erreurChoix =
          _choix == null ? 'Choisissez la maladie retenue, ou « Diagnostic non posé ».' : null;
    });
    if (_erreurCompteRendu != null || _erreurChoix != null) {
      // Amener l'erreur sous les yeux : en haut pour la maladie, en bas
      // pour le compte rendu.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_defilement.hasClients) return;
        final cible = _erreurChoix != null ? 0.0 : _defilement.position.maxScrollExtent;
        if (mouvementReduit(context)) {
          _defilement.jumpTo(cible);
        } else {
          _defilement.animateTo(cible,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
      return;
    }
    setState(() => _envoi = true);
    try {
      final s = await widget.envoyer(widget.signalement.id, texte, _choix!.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _clos = s);
    } on ApiException catch (e) {
      if (!mounted) return;
      final (titre, recharger) = switch (e.statut) {
        422 => ('Ce cas est déjà clôturé', true),
        403 => ('Ce cas a été confié à un confrère', true),
        404 => ("Ce cas n'est plus dans votre file", true),
        409 => ("Ce cas vient d'être modifié", true),
        _ => ('Clôture impossible', false),
      };
      await afficherErreur(context, e, titre: titre);
      if (recharger && mounted) {
        Navigator.of(context).pop(const ResultatCloture(recharger: true));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  // ── rendu ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.signalement;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _quitter();
      },
      child: Scaffold(
        backgroundColor: context.couleurs.fond,
        body: Column(
          children: [
            EnteteVivant(
              sombre: true,
              retour: true,
              titre: _clos == null ? 'Clôture du cas' : 'Cas clôturé',
              sousTitre: [s.eleveurNom ?? 'Éleveur', if (s.uniteCode != null) s.uniteCode!]
                  .join(' · '),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: mouvementReduit(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                child: _clos == null ? _formulaire() : _Confirmation(signalement: _clos!),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _clos == null ? _pied() : null,
      ),
    );
  }

  Widget _formulaire() {
    final proposee = _proposee;
    final alternative = _alternative;
    final options = <(_Choix, String?)>[
      if (proposee != null) ((id: proposee.id, nom: proposee.nom), "Proposée par l'outil"),
      if (alternative != null && alternative.id != proposee?.id)
        ((id: alternative.id, nom: alternative.nom), 'Autre hypothèse'),
      if (_autre != null && _autre!.id != proposee?.id && _autre!.id != alternative?.id)
        (_autre!, 'Choisie dans le catalogue'),
    ];
    return ListView(
      key: const ValueKey('formulaire'),
      controller: _defilement,
      padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 24)),
      children: [
        const _Etape(numero: 1, titre: 'Maladie retenue'),
        for (final (c, note) in options)
          _OptionMaladie(
            key: ValueKey('maladie-${c.id}'),
            nom: c.nom,
            note: note,
            choisie: _choix?.id == c.id && _choix != _nonPose,
            onTap: () => _choisir(c),
          ),
        _OptionMaladie(
          nom: 'Autre maladie…',
          note: 'Chercher dans le catalogue',
          icone: Icons.search_rounded,
          choisie: false,
          onTap: _chercherAutre,
        ),
        _OptionMaladie(
          nom: _nonPose.nom,
          note: 'Aucune maladie confirmée',
          icone: Icons.help_outline_rounded,
          choisie: _choix == _nonPose,
          onTap: () => _choisir(_nonPose),
        ),
        if (_erreurChoix != null) _MessageErreur(_erreurChoix!),
        const SizedBox(height: 8),
        const _Etape(numero: 2, titre: 'Compte rendu'),
        Text("Touchez ce qui a été fait. L'éleveur le reçoit tel quel.",
            style: context.typo.legende),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in phrasesCompteRendu)
              FilterChip(
                label: Text(p),
                selected: _phrases.contains(p),
                showCheckmark: true,
                checkmarkColor: context.couleurs.surMarque,
                selectedColor: context.couleurs.marque,
                backgroundColor: context.couleurs.surface,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                side: BorderSide(
                    color: _phrases.contains(p) ? context.couleurs.marque : context.couleurs.filet),
                labelStyle: context.typo.corpsFort.copyWith(
                    color: _phrases.contains(p) ? context.couleurs.surMarque : context.couleurs.texte),
                onSelected: (v) => setState(() {
                  v ? _phrases.add(p) : _phrases.remove(p);
                  _erreurCompteRendu = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('complement'),
          controller: _complement,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000 - composerCompteRendu(_phrases, '').length - 1,
          style: context.typo.corps,
          onChanged: (_) => setState(() => _erreurCompteRendu = null),
          decoration: InputDecoration(
            labelText: 'Complément (facultatif)',
            hintText: 'Ex. : rappel dans 21 jours, eau javellisée.',
            errorText: _erreurCompteRendu,
            errorMaxLines: 3,
          ),
        ),
        if (_compteRendu.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Envoyé : « $_compteRendu »', style: context.typo.legende),
        ],
      ],
    );
  }

  Widget _pied() => DecoratedBox(
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          boxShadow: [
            BoxShadow(color: context.couleurs.ombrePanneau, blurRadius: 12, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Dim.gouttiere, 12, Dim.gouttiere,
                12 + MediaQuery.viewInsetsOf(context).bottom),
            child: BoutonPrincipal(_envoi ? 'Envoi…' : 'Clôturer le cas',
                icone: Icons.task_alt_rounded,
                grand: true,
                onPressed: _envoi ? null : _cloturer),
          ),
        ),
      );
}

class _Etape extends StatelessWidget {
  const _Etape({required this.numero, required this.titre});
  final int numero;
  final String titre;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.couleurs.marque, shape: BoxShape.circle),
            child: Text('$numero',
                style: Typo.pastille.copyWith(color: context.couleurs.surMarque)),
          ),
          const SizedBox(width: 10),
          Semantics(header: true, child: Text(titre, style: context.typo.titreSection)),
        ]),
      );
}

class _OptionMaladie extends StatelessWidget {
  const _OptionMaladie({
    super.key,
    required this.nom,
    required this.choisie,
    required this.onTap,
    this.note,
    this.icone,
  });
  final String nom;
  final String? note;
  final bool choisie;
  final IconData? icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          selected: choisie,
          inMutuallyExclusiveGroup: icone == null || choisie,
          child: Material(
            color: choisie ? context.couleurs.fondMarquePale : context.couleurs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dim.rayon),
              side: BorderSide(
                  color: choisie ? context.couleurs.marque : context.couleurs.filetLeger,
                  width: choisie ? 2 : 1),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Dim.rayon),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(
                      icone ??
                          (choisie
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                      color: choisie || icone != null ? context.couleurs.marque : context.couleurs.texteDiscret,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nom, style: context.typo.corpsFort),
                          if (note != null) Text(note!, style: context.typo.legende),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _MessageErreur extends StatelessWidget {
  const _MessageErreur(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(texte, style: context.typo.legendeForte.copyWith(color: context.couleurs.erreur)),
      );
}

/// Recherche dans le catalogue, filtré par filière.
class _FeuilleCatalogue extends StatefulWidget {
  const _FeuilleCatalogue({required this.charger, required this.filieres});
  final Future<List<Maladie>> Function() charger;
  final List<String> filieres;

  @override
  State<_FeuilleCatalogue> createState() => _FeuilleCatalogueState();
}

class _FeuilleCatalogueState extends State<_FeuilleCatalogue> {
  late final Future<List<Maladie>> _future = widget.charger();
  String _requete = '';

  bool _garder(Maladie m) =>
      (widget.filieres.isEmpty || m.filieres.any(widget.filieres.contains)) &&
      m.nom.toLowerCase().contains(_requete.trim().toLowerCase());

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, defilement) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration:
                  BoxDecoration(color: context.couleurs.filet, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 12, Dim.gouttiere, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _requete = v),
                style: context.typo.corps,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: widget.filieres.isEmpty
                      ? 'Chercher une maladie'
                      : 'Chercher ($_libelleFilieres)',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Maladie>>(
                future: _future,
                builder: (context, f) {
                  if (f.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(Dim.gouttiere),
                      child: Text(
                          f.error is ApiException
                              ? (f.error as ApiException).texte
                              : 'Catalogue indisponible.',
                          style: context.typo.corpsDiscret),
                    );
                  }
                  if (!f.hasData) return const ListeSquelette(nombre: 4);
                  final liste = f.data!.where(_garder).toList()
                    ..sort((a, b) => a.nom.compareTo(b.nom));
                  if (liste.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(Dim.gouttiere),
                      child: Text('Aucune maladie ne correspond.', style: context.typo.corpsDiscret),
                    );
                  }
                  return ListView.builder(
                    controller: defilement,
                    padding: lisible(context, const EdgeInsets.only(bottom: 24)),
                    itemCount: liste.length,
                    itemBuilder: (context, i) {
                      final m = liste[i];
                      return ListTile(
                        minVerticalPadding: 12,
                        leading: Container(
                          width: 6,
                          height: 36,
                          decoration: BoxDecoration(
                              color: couleurGravite(context, m.gravite),
                              borderRadius: BorderRadius.circular(3)),
                        ),
                        title: Text(m.nom, style: context.typo.corpsFort),
                        subtitle: Text(
                            [L.gravite(m.gravite), ...L.trierFilieres(m.filieres).map(L.filiere)]
                                .join(' · '),
                            style: context.typo.legende),
                        onTap: () => Navigator.of(context).pop(m),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );

  String get _libelleFilieres => widget.filieres.map(L.filiere).join(', ').toLowerCase();
}

/// Après la clôture : la coche, puis la suite en un geste.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.signalement});
  final Signalement signalement;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    final reduit = mouvementReduit(context);
    return ListView(
      key: const ValueKey('confirmation'),
      padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 24, Dim.gouttiere, 24)),
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: reduit ? 1 : 0.4, end: 1),
                duration: Duration(milliseconds: reduit ? 0 : 500),
                curve: Curves.elasticOut,
                builder: (_, v, enfant) => Transform.scale(scale: v, child: enfant),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration:
                      BoxDecoration(color: context.couleurs.marque, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: 52, color: context.couleurs.surMarque),
                ),
              ),
            ],
          ),
        ),
        Text('Cas clôturé',
            textAlign: TextAlign.center, style: context.typo.titreSection.copyWith(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          [
            if (s.maladieConfirmee != null) 'Diagnostic : ${s.maladieConfirmee}'
            else 'Diagnostic non posé',
            "${s.eleveurNom ?? "L'éleveur"} reçoit votre compte rendu.",
          ].join('\n'),
          textAlign: TextAlign.center,
          style: context.typo.corpsDiscret,
        ),
        const SizedBox(height: 28),
        BoutonPrincipal('Voir les demandes restantes',
            grand: true,
            onPressed: () => Navigator.of(context)
                .pop(ResultatCloture(signalement: s, onglet: OngletVeto.eleveurs))),
        const SizedBox(height: 10),
        BoutonSecondaire("Retour à l'accueil",
            onPressed: () => Navigator.of(context)
                .pop(ResultatCloture(signalement: s, onglet: OngletVeto.accueil))),
      ],
    );
  }
}
