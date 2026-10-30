/// Les pieces « vivantes » de la refonte du 7 octobre : ce qui donne a
/// MonCheptel sa signature au lieu d'un Material generique.
///
///  - [EnteteVivant] : l'en-tete droit, en degrade vert ;
///  - [Apparition] : entree en fondu-glissement, decalee selon le rang ;
///  - [CompteurAnime] : un chiffre qui monte jusqu'a sa valeur ;
///  - [Pressable] : retour tactile (leger enfoncement) sur une carte ;
///  - [Squelette] : bloc de chargement qui scintille ;
///  - [AnneauProgression] : anneau de cycle ou de jauge, avec un centre.
///
/// Toutes les animations se coupent quand le telephone demande moins de
/// mouvement (`MediaQuery.disableAnimations`).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/barre_etat.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/typographie.dart';
import 'mise_en_page.dart';

bool mouvementReduit(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// « Bonjour », « Bon après-midi » ou « Bonsoir » selon l'heure du telephone.
String salutation([DateTime? maintenant]) {
  final h = (maintenant ?? DateTime.now()).hour;
  if (h < 5 || h >= 18) return 'Bonsoir';
  if (h < 12) return 'Bonjour';
  return 'Bon après-midi';
}

// ════════════════════════════════════════════════════════════════════════
// En-tete vivant
// ════════════════════════════════════════════════════════════════════════

/// En-tete de marque : degrade vert, bord inferieur droit. Les ondes
/// animees du logo sont reservees au splash et a la connexion.
///
/// [surtitre] (« Bonjour, ») au-dessus du [titre] ; [aDroite] pour la
/// cloche ou l'avatar ; [bas] pour un contenu porte par l'en-tete (bandeau
/// de chiffres, champ de recherche).
class EnteteVivant extends StatelessWidget {
  const EnteteVivant({
    super.key,
    required this.titre,
    this.surtitre,
    this.sousTitre,
    this.aDroite,
    this.bas,
    this.grand = false,
    this.sombre = false,
    this.retour = false,
  });

  final String titre;
  final String? surtitre;
  final String? sousTitre;
  final Widget? aDroite;
  final Widget? bas;

  /// Accueil : titre en [Typo.accroche].
  final bool grand;

  /// Variante vert sombre (espace veterinaire).
  final bool sombre;

  /// Fleche de retour a gauche du titre.
  final bool retour;

  @override
  Widget build(BuildContext context) {
    final c = context.couleurs;
    final couleurs = sombre
        ? [c.enteteSombreDebut, c.enteteSombreFin]
        : [c.enteteDebut, c.enteteFin];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarreEtat.pourEntete(c),
      // Bord inferieur DROIT (10 octobre) : le bord ondule faisait
      // decoratif. Un en-tete droit est la norme des applications de
      // reference ; la douceur vient des cartes et du panneau en dessous.
      child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: couleurs,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                // Le degrade couvre toute la largeur ; le texte s'aligne sur
                // la colonne lisible du contenu (tablette, paysage).
                padding: EdgeInsets.fromLTRB(
                  (retour ? 4 : Dim.gouttiere) + margesLaterales(context).gauche,
                  MediaQuery.paddingOf(context).top + (grand ? 18 : 10),
                  Dim.gouttiere + margesLaterales(context).droite,
                  // 18/22 : l'ondulation du bord n'est plus a compenser.
                  bas == null ? 18 : 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (retour)
                          IconButton(
                            tooltip: 'Retour',
                            onPressed: () => Navigator.maybePop(context),
                            icon: Icon(Icons.arrow_back_rounded,
                                color: context.couleurs.surEntete),
                          ),
                        Expanded(child: _textes(context)),
                        if (aDroite != null) aDroite!,
                      ],
                    ),
                    if (bas != null) ...[
                      const SizedBox(height: 16),
                      bas!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _textes(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (surtitre != null)
            Text(surtitre!,
                style: context.typo.corps.copyWith(color: context.couleurs.surMarqueDiscret)),
          Semantics(
            header: true,
            child: Text(titre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: grand ? Typo.accroche : Typo.titreEcran),
          ),
          if (sousTitre != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const _PointSignal(),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(sousTitre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.legendeForte
                          .copyWith(color: context.couleurs.surMarqueDiscret)),
                ),
              ],
            ),
          ],
        ],
      );
}

/// Le point orange du logo, devant la ligne de contexte.
class _PointSignal extends StatelessWidget {
  const _PointSignal();
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
      );
}

/// Pastille ronde translucide pour l'en-tete (cloche, avatar) : 48 px.
class BoutonEntete extends StatelessWidget {
  const BoutonEntete({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final etiquette = badge > 0 ? '$libelle, $badge non lue${badge > 1 ? 's' : ''}' : libelle;
    return Semantics(
      button: true,
      label: etiquette,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: Material(
          color: const Color(0x26FFFFFF),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(icone, color: context.couleurs.surEntete, size: 24),
                  if (badge > 0)
                    Positioned(
                      top: 4,
                      right: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.couleurs.accent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.couleurs.enteteDebut, width: 2),
                        ),
                        child: Text(badge > 9 ? '9+' : '$badge',
                            style: Typo.pastille.copyWith(
                                fontSize: 11, color: context.couleurs.surAccent)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Mouvement
// ════════════════════════════════════════════════════════════════════════

/// Entree en fondu et glissement vers le haut, decalee de 60 ms par [rang].
class Apparition extends StatefulWidget {
  const Apparition({super.key, required this.child, this.rang = 0});
  final Widget child;
  final int rang;

  @override
  State<Apparition> createState() => _ApparitionState();
}

class _ApparitionState extends State<Apparition> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _lance = false;
  Timer? _depart;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lance) return;
    _lance = true;
    if (mouvementReduit(context)) {
      _c.value = 1;
    } else {
      // Timer annule a la destruction : une tuile qui disparait avant son
      // entree (defilement rapide) ne laisse rien en attente.
      _depart = Timer(Duration(milliseconds: 60 * widget.rang.clamp(0, 8)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _depart?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        builder: (_, enfant) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, 18 * (1 - _t.value)), child: enfant),
        ),
        child: widget.child,
      );
}

/// Un nombre qui monte de 0 a [valeur] en 0,9 s. [format] met en forme
/// (separateur de milliers, « FCFA »…).
class CompteurAnime extends StatelessWidget {
  const CompteurAnime({
    super.key,
    required this.valeur,
    required this.style,
    this.format,
  });
  final num valeur;
  final TextStyle style;
  final String Function(num)? format;

  @override
  Widget build(BuildContext context) {
    final f = format ?? (n) => n.round().toString();
    if (mouvementReduit(context)) return Text(f(valeur), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valeur.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        f(valeur is int ? v.round() : v),
        style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        semanticsLabel: f(valeur),
      ),
    );
  }
}

/// Carte ou tuile qui s'enfonce legerement sous le doigt.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.rayon = Dim.rayon,
    this.couleur,
    this.ombre = true,
    this.libelle,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double rayon;

  /// Nulle : la surface du theme.
  final Color? couleur;
  final bool ombre;

  /// Etiquette lue par le lecteur d'ecran, si l'enfant ne suffit pas.
  final String? libelle;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _appui = false;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(widget.rayon);
    final carte = AnimatedScale(
      scale: _appui && !mouvementReduit(context) ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: rayon,
          boxShadow: widget.ombre
              ? const [
                  BoxShadow(color: Color(0x14193B39), blurRadius: 16, offset: Offset(0, 6)),
                ]
              : null,
        ),
        child: Material(
          color: widget.couleur ?? context.couleurs.surface,
          borderRadius: rayon,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _appui = v),
            splashColor: context.couleurs.fondMarquePale,
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.libelle == null) return carte;
    return Semantics(button: true, label: widget.libelle, child: carte);
  }
}

/// Bloc gris-sable qui scintille pendant un chargement.
class Squelette extends StatefulWidget {
  const Squelette({super.key, this.hauteur = 16, this.largeur = double.infinity, this.rayon = 8});
  final double hauteur;
  final double largeur;
  final double rayon;

  @override
  State<Squelette> createState() => _SqueletteState();
}

class _SqueletteState extends State<Squelette> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!mouvementReduit(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            width: widget.largeur,
            height: widget.hauteur,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.rayon),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + 3 * _c.value, 0),
                end: Alignment(-0.5 + 3 * _c.value, 0),
                colors: [
                  context.couleurs.sable,
                  context.couleurs.sombre ? const Color(0xFF2A3C37) : const Color(0xFFF8F4EC),
                  context.couleurs.sable,
                ],
              ),
            ),
          ),
        ),
      );
}

/// Trois cartes squelettes : l'etat de chargement standard d'une liste.
class ListeSquelette extends StatelessWidget {
  const ListeSquelette({super.key, this.nombre = 3});
  final int nombre;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Chargement',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
          child: Column(
            children: [
              for (var i = 0; i < nombre; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: Dim.ecart),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: context.couleurs.surface, borderRadius: BorderRadius.circular(Dim.rayon)),
                  child: const Row(
                    children: [
                      Squelette(hauteur: 44, largeur: 44, rayon: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Squelette(hauteur: 14, largeur: 160),
                            SizedBox(height: 8),
                            Squelette(hauteur: 12),
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

/// Anneau de progression anime (0..1), un [centre] au milieu.
class AnneauProgression extends StatelessWidget {
  const AnneauProgression({
    super.key,
    required this.valeur,
    this.taille = 56,
    this.epaisseur = 6,
    this.couleur,
    this.piste,
    this.centre,
  });
  final double valeur;
  final double taille;
  final double epaisseur;
  final Color? couleur;
  final Color? piste;
  final Widget? centre;

  @override
  Widget build(BuildContext context) {
    final v = valeur.clamp(0.0, 1.0);
    Widget anneau(double x) => CustomPaint(
          size: Size.square(taille),
          painter: _PeintreAnneau(x, epaisseur, couleur ?? context.couleurs.marque,
              piste ?? context.couleurs.sable),
          child: SizedBox.square(dimension: taille, child: Center(child: centre)),
        );
    if (mouvementReduit(context)) return anneau(v);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, x, __) => anneau(x),
    );
  }
}

class _PeintreAnneau extends CustomPainter {
  _PeintreAnneau(this.v, this.e, this.couleur, this.piste);
  final double v, e;
  final Color couleur, piste;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(e / 2, e / 2, s.width - e, s.height - e);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = e
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, p..color = piste);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, p..color = couleur);
  }

  @override
  bool shouldRepaint(_PeintreAnneau o) => o.v != v || o.couleur != couleur || o.piste != piste;
}

/// Titre de section avec le trait orange du logo dessous, et une action
/// facultative a droite (« Tout voir »).
class TitreSectionVivant extends StatelessWidget {
  const TitreSectionVivant(this.texte, {super.key, this.action, this.onAction});
  final String texte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 20, Dim.gouttiere, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
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
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                child: Text(action!, style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
              ),
          ],
        ),
      );
}
