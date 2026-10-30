/// Graphiques de l'ecran Rapports, dessines avec `CustomPainter`.
///
/// Pourquoi pas une bibliotheque (fl_chart...) : deux graphiques simples ne
/// justifient pas une dependance de plus, dont l'API change d'une version
/// majeure a l'autre, a une semaine d'une soutenance. Ce fichier n'emploie
/// que des API de dessin stables depuis Flutter 1.
///
/// Regles appliquees (lisibilite et accessibilite) :
///  - UN seul axe vertical, gradue en valeurs « rondes » (0, 25 k, 50 k) ;
///  - marques fines, extremite arrondie, ancrees sur la ligne zero ;
///  - grille discrete, jamais plus foncee que les donnees ;
///  - la couleur n'est jamais seule : legende, libelles et lecture chiffree
///    sous le graphique ; un resume est lu par TalkBack / VoiceOver ;
///  - toucher une colonne la selectionne (cible = toute la largeur de la
///    colonne, pas la barre fine).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/format.dart';
import '../theme/typographie.dart';

/// Une colonne du graphique en barres.
typedef PointBarres = ({String libelle, int revenus, int depenses});

/// Un point de la courbe.
typedef PointCourbe = ({String libelle, int valeur});

const double _largeurAxe = 44;
const double _hauteurAbscisses = 24;
const double _margeHaut = 8;

TextStyle _styleAxe(PaletteMonCheptel pal) =>
    Typo.legende.copyWith(fontSize: 11, height: 1.1, color: pal.texteDiscret);

/// Graduations « rondes » couvrant [bas, haut], zero compris.
///
/// Pas de 1, 2, 2,5 ou 5 fois une puissance de dix : on lit « 25 k », jamais
/// « 23 714 ».
List<double> graduations(double bas, double haut, {int cible = 4}) {
  bas = math.min(0.0, bas);
  haut = math.max(0.0, haut);
  if (haut - bas <= 0) return const [0, 1];
  final brut = (haut - bas) / cible;
  final puissance = math.pow(10, (math.log(brut) / math.ln10).floor()).toDouble();
  final n = brut / puissance;
  final double pas =
      (n <= 1 ? 1.0 : n <= 2 ? 2.0 : n <= 2.5 ? 2.5 : n <= 5 ? 5.0 : 10.0) * puissance;
  // Pas d'un franc au minimum : des montants entiers ne se graduent pas
  // en demi-francs (« 0, 1, 1, 2 » une fois arrondis a l'affichage).
  final double pasEntier = math.max(pas, 1.0);
  final debut = (bas / pasEntier).floor() * pasEntier;
  final fin = (haut / pasEntier).ceil() * pasEntier;
  return [for (var v = debut; v <= fin + pasEntier / 2; v += pasEntier) v];
}

/// Faut-il ecrire le libelle d'abscisse de la colonne [i] sur [n] ?
/// Au-dela de six colonnes, un sur deux (en partant du dernier mois) —
/// douze mois ne tiennent pas en toutes lettres sur un telephone. Le mois
/// selectionne est toujours ecrit ; ses deux voisins s'effacent alors pour
/// lui laisser la place.
bool _libelleVisible(int i, int n, int? selection) {
  if (n <= 6 || i == selection) return true;
  if (selection != null && (i - selection).abs() == 1) return false;
  return (n - 1 - i).isEven;
}

/// Largeur disponible pour un libelle d'abscisse.
double _largeurLibelle(double largeurColonne, int n) =>
    n <= 6 ? largeurColonne - 2 : largeurColonne * 2 - 4;

void _ecrire(Canvas canvas, String texte, Offset ancre, TextStyle style, TextScaler echelle,
    {TextAlign alignement = TextAlign.center, double largeurMax = 80}) {
  final tp = TextPainter(
    text: TextSpan(text: texte, style: style),
    textDirection: TextDirection.ltr,
    // Les graduations grossissent avec le reglage du telephone, comme le
    // reste du texte (WCAG 1.4.4), jusqu'a 1,3 fois : au-dela, l'axe
    // mangerait le graphique.
    textScaler: echelle,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: largeurMax);
  final dx = switch (alignement) {
    TextAlign.right => ancre.dx - tp.width,
    TextAlign.left => ancre.dx,
    _ => ancre.dx - tp.width / 2,
  };
  tp.paint(canvas, Offset(dx, ancre.dy - tp.height / 2));
  tp.dispose();
}

/// Grille horizontale et graduations, communes aux deux graphiques.
/// Rend la fonction qui convertit une valeur en ordonnee.
double Function(double) _grille(
    Canvas canvas, Size taille, List<double> ticks, TextScaler echelle, PaletteMonCheptel pal) {
  final basZone = taille.height - _hauteurAbscisses;
  final min = ticks.first;
  final max = ticks.last;
  double y(double v) => basZone - (v - min) / (max - min) * (basZone - _margeHaut);

  final fin = Paint()
    ..color = pal.filetLeger
    ..strokeWidth = 1;
  final zero = Paint()
    ..color = pal.filet
    ..strokeWidth = 1;
  for (final t in ticks) {
    final yy = y(t);
    canvas.drawLine(Offset(_largeurAxe, yy), Offset(taille.width, yy), t == 0 ? zero : fin);
    _ecrire(canvas, Fmt.compact(t), Offset(_largeurAxe - 6, yy), _styleAxe(pal), echelle,
        alignement: TextAlign.right, largeurMax: _largeurAxe - 6);
  }
  return y;
}

TextScaler _echelle(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

/// Index de la colonne sous le doigt.
int? _colonneSous(Offset position, double largeur, int n) {
  if (n == 0 || position.dx < _largeurAxe) return null;
  final i = ((position.dx - _largeurAxe) / ((largeur - _largeurAxe) / n)).floor();
  return i.clamp(0, n - 1);
}

// ── barres groupees : revenus et depenses ─────────────────────────────────

class GraphiqueBarres extends StatelessWidget {
  const GraphiqueBarres({
    super.key,
    required this.points,
    required this.selection,
    required this.onSelection,
    required this.resume,
    this.hauteur = 200,
  });

  final List<PointBarres> points;
  final int? selection;
  final ValueChanged<int> onSelection;

  /// Phrase lue par les lecteurs d'ecran a la place du dessin.
  final String resume;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: resume,
      image: true,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Le resume ci-dessus remplace le dessin pour TalkBack ; un
          // « toucher » sans position n'aurait rien a selectionner.
          excludeFromSemantics: true,
          // onTapUp et non onTapDown : un doigt pose pour faire defiler la
          // page ne doit pas changer la selection.
          onTapUp: (d) {
            final i = _colonneSous(d.localPosition, c.maxWidth, points.length);
            if (i != null) onSelection(i);
          },
          child: CustomPaint(
            size: Size(c.maxWidth, hauteur),
            painter: _PeintreBarres(points, selection, _echelle(context), context.couleurs),
          ),
        ),
      ),
    );
  }
}

class _PeintreBarres extends CustomPainter {
  _PeintreBarres(this.points, this.selection, this.echelle, this.pal);
  final PaletteMonCheptel pal;
  final List<PointBarres> points;
  final int? selection;
  final TextScaler echelle;

  @override
  void paint(Canvas canvas, Size taille) {
    if (points.isEmpty) return;
    final maximum = points.fold<int>(0, (m, p) => math.max(m, math.max(p.revenus, p.depenses)));
    final ticks = graduations(0, maximum.toDouble());
    final y = _grille(canvas, taille, ticks, echelle, pal);

    final n = points.length;
    final largeurColonne = (taille.width - _largeurAxe) / n;
    // Barres fines : au plus 14 px, et jamais plus du quart de la colonne.
    final largeurBarre = math.min(14.0, largeurColonne * 0.26);
    const ecart = 3.0;
    final basZone = taille.height - _hauteurAbscisses;

    for (var i = 0; i < n; i++) {
      final p = points[i];
      final centre = _largeurAxe + largeurColonne * (i + 0.5);
      final choisie = selection == null || selection == i;

      if (selection == i) {
        // Bande de selection derriere la colonne.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(centre - largeurColonne / 2 + 2, _margeHaut - 4,
                centre + largeurColonne / 2 - 2, basZone),
            const Radius.circular(8),
          ),
          Paint()..color = pal.fondMarquePale,
        );
      }

      void barre(double gauche, int valeur, Color couleur) {
        if (valeur <= 0) return;
        final haut = math.min(y(valeur.toDouble()), basZone - 2); // 2 px minimum
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(gauche, haut, gauche + largeurBarre, basZone),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = couleur,
        );
      }

      barre(centre - ecart / 2 - largeurBarre, p.revenus,
          choisie ? pal.graphiqueRevenus : pal.graphiqueRevenusAttenue);
      barre(centre + ecart / 2, p.depenses,
          choisie ? pal.graphiqueDepenses : pal.graphiqueDepensesAttenue);

      if (_libelleVisible(i, n, selection)) {
        _ecrire(
          canvas,
          p.libelle,
          Offset(centre, taille.height - _hauteurAbscisses / 2),
          selection == i
              ? _styleAxe(pal).copyWith(color: pal.texte, fontWeight: FontWeight.w700)
              : _styleAxe(pal),
          echelle,
          largeurMax: _largeurLibelle(largeurColonne, n),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PeintreBarres ancien) =>
      ancien.pal != pal ||
      ancien.points != points || ancien.selection != selection || ancien.echelle != echelle;
}

// ── courbe : solde cumule ─────────────────────────────────────────────────

class GraphiqueCourbe extends StatelessWidget {
  const GraphiqueCourbe({
    super.key,
    required this.points,
    required this.selection,
    required this.onSelection,
    required this.resume,
    this.hauteur = 170,
  });

  final List<PointCourbe> points;
  final int? selection;
  final ValueChanged<int> onSelection;
  final String resume;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: resume,
      image: true,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Le resume ci-dessus remplace le dessin pour TalkBack ; un
          // « toucher » sans position n'aurait rien a selectionner.
          excludeFromSemantics: true,
          // onTapUp et non onTapDown : un doigt pose pour faire defiler la
          // page ne doit pas changer la selection.
          onTapUp: (d) {
            final i = _colonneSous(d.localPosition, c.maxWidth, points.length);
            if (i != null) onSelection(i);
          },
          child: CustomPaint(
            size: Size(c.maxWidth, hauteur),
            painter: _PeintreCourbe(points, selection, _echelle(context), context.couleurs),
          ),
        ),
      ),
    );
  }
}

class _PeintreCourbe extends CustomPainter {
  _PeintreCourbe(this.points, this.selection, this.echelle, this.pal);
  final PaletteMonCheptel pal;
  final List<PointCourbe> points;
  final int? selection;
  final TextScaler echelle;

  @override
  void paint(Canvas canvas, Size taille) {
    if (points.isEmpty) return;
    final valeurs = points.map((p) => p.valeur.toDouble());
    final ticks = graduations(valeurs.reduce(math.min), valeurs.reduce(math.max));
    final y = _grille(canvas, taille, ticks, echelle, pal);

    final n = points.length;
    final largeurColonne = (taille.width - _largeurAxe) / n;
    final basZone = taille.height - _hauteurAbscisses;
    Offset point(int i) =>
        Offset(_largeurAxe + largeurColonne * (i + 0.5), y(points[i].valeur.toDouble()));

    if (selection != null) {
      // Repere vertical sous le point choisi.
      final x = point(selection!).dx;
      canvas.drawLine(Offset(x, _margeHaut), Offset(x, basZone),
          Paint()
            ..color = pal.filet
            ..strokeWidth = 1);
    }

    final trace = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < n; i++) {
      trace.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(
      trace,
      Paint()
        ..color = pal.marque
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < n; i++) {
      final c = point(i);
      final choisi = i == selection;
      // Anneau blanc : le point se detache de la ligne qui le traverse.
      canvas.drawCircle(c, choisi ? 7 : 5, Paint()..color = pal.surface);
      canvas.drawCircle(c, choisi ? 5 : 3.5, Paint()..color = pal.marque);
      if (_libelleVisible(i, n, selection)) {
        _ecrire(
          canvas,
          points[i].libelle,
          Offset(c.dx, taille.height - _hauteurAbscisses / 2),
          choisi
              ? _styleAxe(pal).copyWith(color: pal.texte, fontWeight: FontWeight.w700)
              : _styleAxe(pal),
          echelle,
          largeurMax: _largeurLibelle(largeurColonne, n),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PeintreCourbe ancien) =>
      ancien.pal != pal ||
      ancien.points != points || ancien.selection != selection || ancien.echelle != echelle;
}

/// Pastille de legende : carre de couleur + libelle en couleur de TEXTE.
class LegendeGraphique extends StatelessWidget {
  const LegendeGraphique({super.key, required this.couleur, required this.texte});
  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(texte, style: context.typo.legende),
        ],
      );
}
