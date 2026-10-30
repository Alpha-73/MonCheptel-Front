/// Pictogrammes d'elevage dessines : tete de vache (le cheptel, l'emblème),
/// poule, mouton, chevre. Ils remplacent la patte de chien `Icons.pets` de
/// Material, qui ne parle pas a un eleveur.
///
/// Dessines sur une grille de 24 × 24 (comme les icones Material), donc
/// interchangeables avec une `Icon` de meme taille. [plein] : silhouette
/// pleine (etat actif) ; sinon contour (etat au repos).
library;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';

enum Espece { bovin, volaille, ovin, caprin }

/// L'espece dessinee pour une filiere du back (VOLAILLE, BOVINS...).
Espece especeDeFiliere(String? filiere) => switch (filiere) {
      'VOLAILLE' => Espece.volaille,
      'OVINS' => Espece.ovin,
      'CAPRINS' => Espece.caprin,
      _ => Espece.bovin,
    };

/// Un animal dessine, de la taille d'une icone.
class PictoAnimal extends StatelessWidget {
  const PictoAnimal({
    super.key,
    this.espece = Espece.bovin,
    this.taille = 24,
    this.couleur,
    this.plein = true,
    this.libelle,
  });

  /// Raccourci depuis le code de filiere du back.
  PictoAnimal.filiere(String? filiere,
      {super.key, this.taille = 24, this.couleur, this.plein = true, this.libelle})
      : espece = especeDeFiliere(filiere);

  final Espece espece;
  final double taille;

  /// Nulle : le vert de marque du theme.
  final Color? couleur;
  final bool plein;

  /// Lu par le lecteur d'ecran ; nul = decoratif.
  final String? libelle;

  @override
  Widget build(BuildContext context) {
    final dessin = CustomPaint(
      size: Size.square(taille),
      painter: _PeintreAnimal(espece, couleur ?? context.couleurs.marque, plein),
    );
    if (libelle == null) return ExcludeSemantics(child: dessin);
    return Semantics(label: libelle, image: true, child: dessin);
  }
}

/// La tete de vache seule : le pictogramme « Mes animaux » de la barre du bas.
class PictoCheptel extends StatelessWidget {
  const PictoCheptel({super.key, this.taille = 24, this.couleur, this.plein = true});
  final double taille;
  final Color? couleur;
  final bool plein;

  @override
  Widget build(BuildContext context) =>
      PictoAnimal(taille: taille, couleur: couleur, plein: plein);
}

/// Pastille ronde teintee portant l'animal : la vignette d'une ligne de liste.
class VignetteAnimal extends StatelessWidget {
  const VignetteAnimal({
    super.key,
    required this.filiere,
    this.taille = 48,
    this.actif = true,
  });
  final String? filiere;
  final double taille;
  final bool actif;

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          color: actif ? context.couleurs.fondMarquePale : context.couleurs.sable,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: PictoAnimal.filiere(filiere,
            taille: taille * 0.62,
            couleur: actif ? context.couleurs.marque : context.couleurs.texteDiscret),
      );
}

class _PeintreAnimal extends CustomPainter {
  _PeintreAnimal(this.espece, this.couleur, this.plein);
  final Espece espece;
  final Color couleur;
  final bool plein;

  static Path _union(List<Path> parts) =>
      parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

  static Path _ovale(double x, double y, double l, double h) =>
      Path()..addOval(Rect.fromLTWH(x, y, l, h));

  static Path _rrect(double x, double y, double l, double h, double r) =>
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, l, h), Radius.circular(r)));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final remplir = Paint()
      ..color = couleur
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Silhouette (pleine ou en contour), traits (toujours en trait), trous
    // (yeux, narines : evides en plein, points en contour).
    late Path silhouette;
    final traits = Path();
    final trous = <Offset>[];
    var rayonTrou = 0.9;

    switch (espece) {
      case Espece.bovin:
        silhouette = _union([
          _rrect(7.2, 5.6, 9.6, 11, 4), // front
          _rrect(6.4, 13.2, 11.2, 7.6, 3.8), // mufle
          _ovale(2.2, 8.2, 5.4, 3.2), // oreille gauche
          _ovale(16.4, 8.2, 5.4, 3.2), // oreille droite
        ]);
        traits
          ..moveTo(8.2, 6.4)
          ..quadraticBezierTo(4.2, 6.0, 3.6, 2.6) // corne gauche
          ..moveTo(15.8, 6.4)
          ..quadraticBezierTo(19.8, 6.0, 20.4, 2.6); // corne droite
        trous.addAll(const [Offset(9.9, 11), Offset(14.1, 11), Offset(9.6, 17.2), Offset(14.4, 17.2)]);
        rayonTrou = 1.0;
      case Espece.volaille:
        final crete = _union([
          _ovale(6.0, 2.2, 2.8, 3.0),
          _ovale(8.0, 1.6, 2.8, 3.2),
          _ovale(10.0, 2.4, 2.6, 2.8),
        ]);
        final bec = Path()
          ..moveTo(5.2, 6.6)
          ..lineTo(2.4, 8.0)
          ..lineTo(5.4, 8.9)
          ..close();
        final queue = Path()
          ..moveTo(15.5, 11.5)
          ..lineTo(21.6, 5.2)
          ..quadraticBezierTo(22.6, 11.5, 19.4, 15.2)
          ..close();
        silhouette = _union([
          _ovale(4.8, 4.2, 7.0, 7.0), // tete
          _ovale(5.6, 9.0, 13.6, 10.6), // corps
          crete,
          bec,
          queue,
        ]);
        traits
          ..moveTo(10.4, 19.4)
          ..lineTo(10.4, 22.2)
          ..moveTo(14.2, 19.4)
          ..lineTo(14.2, 22.2);
        trous.add(const Offset(8.3, 7.0));
        rayonTrou = 0.85;
      case Espece.ovin:
        silhouette = _union([
          for (final (x, y) in const [
            (9.5, 9.6), (13.2, 8.6), (16.8, 10.2), (17.6, 13.8),
            (14.4, 15.4), (10.6, 15.2), (8.4, 12.8),
          ])
            _ovale(x - 3.3, y - 3.3, 6.6, 6.6), // toison en boucles
          _ovale(1.6, 8.0, 5.4, 7.0), // tete
        ]);
        traits
          ..moveTo(9.6, 18.4)
          ..lineTo(9.6, 22)
          ..moveTo(15.6, 18.4)
          ..lineTo(15.6, 22)
          ..moveTo(3.0, 9.4)
          ..lineTo(1.2, 8.0); // oreille
        trous.add(const Offset(4.0, 10.6));
        rayonTrou = 0.8;
      case Espece.caprin:
        final barbe = Path()
          ..moveTo(10.6, 16.8)
          ..lineTo(13.4, 16.8)
          ..lineTo(12.0, 22.4)
          ..close();
        silhouette = _union([
          _rrect(8.2, 5.4, 7.6, 12.8, 3.8), // tete allongee
          _ovale(2.0, 7.6, 6.8, 2.8), // oreille gauche, a l'horizontale
          _ovale(15.2, 7.6, 6.8, 2.8), // oreille droite
          barbe,
        ]);
        traits
          ..moveTo(9.6, 5.8)
          ..quadraticBezierTo(8.2, 2.0, 5.4, 1.6) // corne gauche, vers l'arriere
          ..moveTo(14.4, 5.8)
          ..quadraticBezierTo(15.8, 2.0, 18.6, 1.6);
        trous.addAll(const [Offset(10.4, 10.0), Offset(13.6, 10.0)]);
        rayonTrou = 0.85;
    }

    if (plein) {
      final evide = Path.combine(
        PathOperation.difference,
        silhouette,
        _union([for (final o in trous) Path()..addOval(Rect.fromCircle(center: o, radius: rayonTrou))]),
      );
      canvas.drawPath(evide, remplir);
    } else {
      canvas.drawPath(silhouette, trait);
      for (final o in trous) {
        canvas.drawCircle(o, rayonTrou * 0.8, remplir);
      }
    }
    canvas.drawPath(traits, trait);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreAnimal o) =>
      o.espece != espece || o.couleur != couleur || o.plein != plein;
}
