/// Identite visuelle MonCheptel : logo, embleme, fond degrade et ondes.
///
/// Tout vient du logo fourni (tete de vache + ondes orange, « Mon » vert et
/// « Cheptel » orange) et des maquettes « Splash anime », « Choix du profil »
/// et « Espace éleveur ». Les images sont tirees du SVG du logo, sans
/// retouche (`assets/marque`, en 1x, 2x et 3x).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/couleurs.dart';
import '../theme/palette.dart';

/// Le logo complet, avec le slogan. [clair] : version pour fond vert
/// (vache et « Mon » en blanc, « Cheptel » reste orange). Le theme sombre
/// prend toujours la version claire : le vert du logo disparaitrait sur le
/// fond vert-noir.
class LogoMonCheptel extends StatelessWidget {
  const LogoMonCheptel({super.key, this.largeur = 220, this.clair = false});
  final double largeur;
  final bool clair;

  /// Rapport hauteur / largeur du dessin (366 x 186).
  static const double proportion = 186 / 366;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'MonCheptel, le compagnon des éleveurs connectés',
        image: true,
        child: Image.asset(
          (clair || context.couleurs.sombre) ? 'assets/marque/logo-clair.png' : 'assets/marque/logo.png',
          width: largeur,
          height: largeur * proportion,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      );
}

/// Le logo sur une ligne : embleme a gauche du nom, sans slogan. Pour les
/// en-tetes, ou le logo complet serait trop haut.
class LogoEnLigne extends StatelessWidget {
  const LogoEnLigne({super.key, this.hauteur = 28, this.clair = false});
  final double hauteur;
  final bool clair;

  /// Rapport largeur / hauteur du dessin (446 x 66).
  static const double proportion = 446 / 66;

  @override
  Widget build(BuildContext context) => Image.asset(
        (clair || context.couleurs.sombre) ? 'assets/marque/logo-ligne-clair.png' : 'assets/marque/logo-ligne.png',
        height: hauteur,
        width: hauteur * proportion,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}

/// L'embleme seul : la tete de vache et ses ondes.
class EmblemeMonCheptel extends StatelessWidget {
  const EmblemeMonCheptel({super.key, this.taille = 40, this.clair = false});
  final double taille;
  final bool clair;

  @override
  Widget build(BuildContext context) => Image.asset(
        (clair || context.couleurs.sombre) ? 'assets/marque/embleme-clair.png' : 'assets/marque/embleme.png',
        width: taille,
        height: taille,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}

/// Fond des ecrans d'accueil (splash, choix du profil) : degrade vert tres
/// pale, halo vert en haut a droite, halo orange en bas a gauche.
/// Valeurs relevees dans la maquette (#F7FBFA -> #DCEAE7, halos a 22 % et
/// 20 %).
class FondMarque extends StatelessWidget {
  const FondMarque({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.couleurs.fondAccueilHaut, context.couleurs.fondAccueilBas],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
                right: -230, top: -180, width: 540, height: 540,
                child: _Halo(Color(0x38146B66))),
            const Positioned(
                left: -214, bottom: -138, width: 460, height: 460,
                child: _Halo(Color(0x33F4A259))),
            child,
          ],
        ),
      );
}

class _Halo extends StatelessWidget {
  const _Halo(this.couleur);
  final Color couleur;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [couleur, couleur.withAlpha(0)]),
        ),
      );
}

/// Le trait orange sous un titre (« ESPACE ÉLEVEUR », « Bienvenue… »).
class TraitMarque extends StatelessWidget {
  const TraitMarque({super.key, this.largeur = 32});
  final double largeur;

  @override
  Widget build(BuildContext context) => Container(
        width: largeur,
        height: 3,
        decoration: BoxDecoration(
          color: context.couleurs.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// Les ondes du logo, en grand : cercles concentriques qui s'elargissent
/// depuis un point orange, comme un signal. C'est le motif du splash ;
/// l'en-tete vert en garde une version fixe et discrete.
///
/// [anime] faux : cercles immobiles (en-tetes, tests, animations reduites).
class OndesSignal extends StatefulWidget {
  const OndesSignal({
    super.key,
    this.taille = 390,
    this.anime = true,
    this.couleur,
    this.point = true,
  });

  final double taille;
  final bool anime;

  /// Nulle : le vert de marque du theme.
  final Color? couleur;
  final bool point;

  @override
  State<OndesSignal> createState() => _OndesSignalState();
}

class _OndesSignalState extends State<OndesSignal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte « Supprimer les animations » d'Android.
    final reduit = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.anime && !reduit) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.taille,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _PeintreOndes(
                  phase: widget.anime ? _c.value : 0,
                  anime: widget.anime,
                  couleur: widget.couleur ?? context.couleurs.marque,
                  point: widget.point,
                ),
              ),
            ),
          ),
        ),
      );
}

class _PeintreOndes extends CustomPainter {
  _PeintreOndes({
    required this.phase,
    required this.anime,
    required this.couleur,
    required this.point,
  });

  final double phase;
  final bool anime;
  final Color couleur;
  final bool point;

  // Rayons relatifs des quatre cercles de la maquette (200, 155, 112, 74
  // sur 200) et leur opacite de remplissage (3,5 %, 4,5 %, 6 %, 8 %).
  static const _rayons = [1.0, 0.78, 0.56, 0.37];
  static const _fonds = [0.035, 0.045, 0.06, 0.08];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    for (var i = 0; i < _rayons.length; i++) {
      // Une respiration douce, decalee d'un cercle a l'autre.
      final souffle = anime
          ? 1 + 0.025 * math.sin((phase - i * 0.18) * 2 * math.pi)
          : 1.0;
      final ri = r * _rayons[i] * souffle;
      canvas.drawCircle(centre, ri,
          Paint()..color = couleur.withValues(alpha: _fonds[i]));
      canvas.drawCircle(
          centre,
          ri,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = couleur.withValues(alpha: 0.16));
    }

    if (anime) {
      // Deux ondes qui partent du centre et s'effacent en atteignant le bord.
      for (final decalage in [0.0, 0.5]) {
        final t = (phase + decalage) % 1.0;
        final courbe = Curves.easeOut.transform(t);
        canvas.drawCircle(
            centre,
            r * (0.06 + 0.94 * courbe),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Couleurs.accent.withValues(alpha: 0.45 * (1 - t)));
      }
    }

    if (point) {
      final pulsation = anime ? 1 + 0.25 * math.sin(phase * 2 * math.pi) : 1.0;
      canvas.drawCircle(centre, 9 * pulsation,
          Paint()..color = Couleurs.accent.withValues(alpha: 0.25));
      canvas.drawOval(
          Rect.fromCenter(center: centre, width: 13.6, height: 16),
          Paint()..color = Couleurs.accent);
    }
  }

  @override
  bool shouldRepaint(_PeintreOndes ancien) =>
      ancien.phase != phase || ancien.anime != anime;
}
