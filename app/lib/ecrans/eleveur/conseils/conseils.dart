/// Conseils des veterinaires : liste par filiere et par theme, et lecture.
///
/// Sources : GET /api/auth/moi (filieres pratiquees : seules celles-la ont
/// un onglet, audit L12), GET /api/conseils?filiere=&categorie=&page=
/// (publies seulement, par pages) et GET /api/conseils/{id}.
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
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/vivant.dart';
import '../sante/veterinaires.dart';
import '../../../widgets/mise_en_page.dart';

IconData iconeCategorieConseil(String c) => switch (c) {
      'SANTE' => Icons.health_and_safety_outlined,
      'PRODUCTION' => Icons.trending_up_rounded,
      'HYGIENE' => Icons.clean_hands_outlined,
      _ => Icons.lightbulb_outline_rounded,
    };

Color _teinteCategorie(BuildContext context, String c) => switch (c) {
      'SANTE' => context.couleurs.sante,
      'PRODUCTION' => context.couleurs.marque,
      'HYGIENE' => context.couleurs.attentionTexte,
      _ => context.couleurs.marque,
    };

/// Les conseils ouverts depuis un autre ecran (Santé) : meme contenu que
/// l'onglet, avec un retour.
class EcranConseils extends StatelessWidget {
  const EcranConseils({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.couleurs.fond,
        body: const ConseilsListe(retour: true),
      );
}

class ConseilsListe extends StatefulWidget {
  const ConseilsListe({super.key, this.retour = false});

  /// Fleche de retour dans l'en-tete (ecran pousse, pas onglet).
  final bool retour;

  @override
  State<ConseilsListe> createState() => _ConseilsListeState();
}

class _ConseilsListeState extends State<ConseilsListe> {
  /// Toutes, puis les filieres pratiquees (toutes tant que le profil n'est
  /// pas charge, ou s'il ne peut pas l'etre).
  List<String?> _onglets = const [null, ...L.filieres];
  String? _filiere;
  String? _categorie;

  @override
  void initState() {
    super.initState();
    AuthApi.moi().then((p) {
      if (!mounted) return;
      final f = L.trierFilieres(p.filieresPratiquees);
      if (f.isEmpty) return;
      setState(() {
        _onglets = [null, ...f];
        // Ouvre sur la premiere filiere pratiquee, pas sur « Toutes ».
        _filiere = f.first;
      });
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EnteteVivant(
          titre: 'Conseils',
          sousTitre: 'Écrits par des vétérinaires',
          retour: widget.retour,
          bas: OngletsSurMarque(
            libelles: [for (final f in _onglets) f == null ? 'Toutes' : L.filiere(f)],
            indexActif: _onglets.indexOf(_filiere).clamp(0, _onglets.length - 1),
            onChange: (i) => setState(() => _filiere = _onglets[i]),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 4),
            children: [
              _PuceTheme(
                libelle: 'Tous les thèmes',
                icone: Icons.apps_rounded,
                actif: _categorie == null,
                onTap: () => setState(() => _categorie = null),
              ),
              for (final c in L.categoriesConseil)
                _PuceTheme(
                  libelle: L.categorieConseil(c),
                  icone: iconeCategorieConseil(c),
                  actif: _categorie == c,
                  onTap: () => setState(() => _categorie = c),
                ),
            ],
          ),
        ),
        Expanded(
          child: _ListePaginee(
              key: ValueKey('$_filiere/$_categorie'), filiere: _filiere, categorie: _categorie),
        ),
      ],
    );
  }
}

class _PuceTheme extends StatelessWidget {
  const _PuceTheme(
      {required this.libelle, required this.icone, required this.actif, required this.onTap});
  final String libelle;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          selected: actif,
          button: true,
          child: Material(
            color: actif ? context.couleurs.fondAccentPale : context.couleurs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: actif ? context.couleurs.accent : context.couleurs.filetLeger, width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: actif ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 20, color: actif ? context.couleurs.attentionTexte : context.couleurs.texteDiscret),
                    const SizedBox(width: 6),
                    Text(libelle,
                        style: context.typo.corpsFort.copyWith(
                            color: actif ? context.couleurs.texte : context.couleurs.texteDiscret)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Liste qui charge la page suivante a la demande (« Voir plus »).
class _ListePaginee extends StatefulWidget {
  const _ListePaginee({super.key, required this.filiere, required this.categorie});
  final String? filiere;
  final String? categorie;

  @override
  State<_ListePaginee> createState() => _ListePagineeState();
}

class _ListePagineeState extends State<_ListePaginee> {
  final List<ConseilResume> _conseils = [];
  int _page = 0;
  bool _derniere = false;
  bool _chargement = false;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _suivante();
  }

  Future<void> _suivante() async {
    if (_chargement || _derniere) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final p = await ConseilEleveurApi.lister(
          filiere: widget.filiere, categorie: widget.categorie, page: _page);
      if (!mounted) return;
      setState(() {
        _conseils.addAll(p.elements);
        _derniere = p.derniere;
        _page++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _toutRecharger() async {
    if (_chargement) return;
    setState(() {
      _conseils.clear();
      _page = 0;
      _derniere = false;
    });
    await _suivante();
  }

  @override
  Widget build(BuildContext context) {
    if (_conseils.isEmpty && _erreur != null) {
      return EtatErreur(erreur: _erreur!, onReessayer: _suivante);
    }
    if (_conseils.isEmpty && _chargement) {
      return SingleChildScrollView(padding: lisible(context), child: const ListeSquelette(nombre: 4));
    }
    return RefreshIndicator(
      onRefresh: _toutRecharger,
      color: context.couleurs.marque,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 24)),
        children: [
          if (_conseils.isEmpty)
            EtatVide(widget.filiere == null
                ? 'Aucun conseil publié pour le moment.'
                : 'Aucun conseil pour la filière ${L.filiere(widget.filiere).toLowerCase()}.',
                icone: Icons.lightbulb_outline_rounded),
          for (var i = 0; i < _conseils.length; i++)
            Apparition(
              rang: i % 8,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CarteConseil(
                  conseil: _conseils[i],
                  onTap: () => ouvrir<void>(context, EcranConseil(conseilId: _conseils[i].id)),
                ),
              ),
            ),
          if (_erreur != null && _conseils.isNotEmpty)
            Text((_erreur is ApiException) ? (_erreur as ApiException).texte : 'Erreur',
                style: context.typo.corps.copyWith(color: context.couleurs.erreur)),
          if (!_derniere && _conseils.isNotEmpty)
            BoutonSecondaire(_chargement ? 'Chargement…' : 'Voir plus',
                onPressed: _chargement ? null : _suivante),
        ],
      ),
    );
  }
}

class _CarteConseil extends StatelessWidget {
  const _CarteConseil({required this.conseil, required this.onTap});
  final ConseilResume conseil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conseil;
    final teinte = _teinteCategorie(context, c.categorie);
    return Pressable(
      onTap: onTap,
      rayon: 16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: teinte.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconeCategorieConseil(c.categorie), color: teinte, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.titre, style: context.typo.corpsFort.copyWith(fontSize: 17)),
                  if (c.extrait != null) ...[
                    const SizedBox(height: 4),
                    Text(c.extrait!,
                        style: context.typo.corpsDiscret, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      L.categorieConseil(c.categorie),
                      L.filiere(c.filiere),
                      c.auteur ?? 'MonCheptel',
                    ].join(' · '),
                    style: context.typo.legende,
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

class EcranConseil extends StatelessWidget {
  const EcranConseil({super.key, required this.conseilId});
  final int conseilId;

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Conseil',
        corps: ChargeurVivant<ConseilDetail>(
          charger: () => ConseilApi.lire(conseilId),
          construire: (context, c, _) => ListView(
            padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 32)),
            children: [
              Row(
                children: [
                  Icon(iconeCategorieConseil(c.categorie),
                      color: _teinteCategorie(context, c.categorie)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${L.categorieConseil(c.categorie)} · ${L.filiere(c.filiere)}',
                        style: context.typo.legendeForte),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(header: true, child: Text(c.titre, style: context.typo.titreSection.copyWith(fontSize: 24))),
              const SizedBox(height: 4),
              Text(
                [
                  c.auteur?.nom ?? 'MonCheptel',
                  if (c.datePublication != null) Fmt.date(c.datePublication),
                ].join(' · '),
                style: context.typo.corpsDiscret,
              ),
              const SizedBox(height: 16),
              Text(c.contenu, style: context.typo.corps.copyWith(fontSize: 17, height: 1.55)),
              const SizedBox(height: 20),
              // F19 : la note dit vrai — un conseil sans auteur vient de
              // l'administration, pas d'un veterinaire.
              Note(
                  c.auteur != null
                      ? 'Rédigé par un vétérinaire, relu par MonCheptel.'
                      : 'Publié par MonCheptel.',
                  icone: Icons.verified_outlined),
              if (c.auteur != null) ...[
                const SizedBox(height: 12),
                BoutonPrincipal('Contacter ce vétérinaire',
                    icone: Icons.call_rounded,
                    onPressed: () => ouvrir<void>(
                        context, EcranFicheVeterinaire(veterinaire: c.auteur!))),
              ],
            ],
          ),
        ),
      );
}
