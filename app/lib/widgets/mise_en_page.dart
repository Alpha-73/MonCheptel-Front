/// Mise en page adaptative : du petit Android de 320 px a la tablette en
/// paysage.
///
/// Sur un grand ecran, le CONTENU se centre dans une colonne lisible de
/// [largeurLisible] px ; les fonds (en-tetes degrades, fond sable) restent
/// pleine largeur. Les listes gardent toute la largeur pour defiler : on
/// elargit seulement leurs marges laterales ([lisible]).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Largeur maximale du contenu : une colonne qui se lit sans balayer la
/// tete, et ou les tuiles passent a trois ou quatre de front.
const double largeurLisible = 720;

/// Marge a ajouter de chaque cote pour centrer une colonne de
/// [largeurLisible] dans un ecran de largeur [largeur].
double margeCentrage(double largeur) =>
    largeur > largeurLisible ? (largeur - largeurLisible) / 2 : 0;

/// Marges laterales a ajouter au contenu : le centrage sur grand ecran, et
/// au moins l'encoche ou les bords arrondis du telephone en paysage.
({double gauche, double droite}) margesLaterales(BuildContext context) {
  final m = margeCentrage(MediaQuery.sizeOf(context).width);
  final sur = MediaQuery.paddingOf(context);
  return (gauche: math.max(m, sur.left), droite: math.max(m, sur.right));
}

/// [p] augmente des [margesLaterales].
EdgeInsets lisible(BuildContext context, [EdgeInsets p = EdgeInsets.zero]) {
  final m = margesLaterales(context);
  if (m.gauche == 0 && m.droite == 0) return p;
  return p.copyWith(left: p.left + m.gauche, right: p.right + m.droite);
}

/// Pour un bloc qui ne defile pas : centre, au plus [largeur] px.
class LargeurLisible extends StatelessWidget {
  const LargeurLisible({super.key, required this.child, this.largeur = largeurLisible});
  final Widget child;
  final double largeur;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: largeur),
          child: child,
        ),
      );
}

/// Nombre de colonnes d'une grille de [n] tuiles dans [largeur] : 2 sur
/// telephone, 3 ou 4 quand la place le permet, de preference sans rangee
/// incomplete (4 tuiles : 4 ou 2, pas 3). [n] nul : grille ouverte.
int colonnesGrille(double largeur, int? n, {double ecart = 12, double largeurMin = 136}) {
  bool tient(int c) => c * largeurMin + (c - 1) * ecart <= largeur;
  final possibles = [for (final c in [4, 3, 2]) if ((n == null || c <= n) && tient(c)) c];
  if (possibles.isEmpty) return n != null && n < 2 ? 1 : 2;
  if (n == null) return possibles.first;
  return possibles.firstWhere((c) => n % c == 0, orElse: () => possibles.first);
}

/// Grille de tuiles : deux colonnes sur telephone, trois ou quatre quand la
/// place le permet (tablette, paysage). Chaque rangee prend la hauteur de
/// sa plus haute tuile : rien ne deborde, meme avec un texte agrandi.
class GrilleTuiles extends StatelessWidget {
  const GrilleTuiles({super.key, required this.children, this.ecart = 12, this.largeurMin = 136});
  final List<Widget> children;
  final double ecart;

  /// Largeur au-dessous de laquelle une tuile ne descend pas.
  final double largeurMin;

  /// Nombre de colonnes pour [n] tuiles dans [largeur] : le plus grand qui
  /// tienne, de preference sans rangee incomplete (4 tuiles : 4 ou 2, pas 3).
  static int colonnesPour(double largeur, int n, {double ecart = 12, double largeurMin = 136}) =>
      colonnesGrille(largeur, n, ecart: ecart, largeurMin: largeurMin);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, contraintes) {
        final n = children.length;
        final colonnes =
            colonnesPour(contraintes.maxWidth, n, ecart: ecart, largeurMin: largeurMin);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < n; i += colonnes) ...[
              if (i > 0) SizedBox(height: ecart),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < colonnes; j++) ...[
                      if (j > 0) SizedBox(width: ecart),
                      Expanded(child: i + j < n ? children[i + j] : const SizedBox()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      });
}

