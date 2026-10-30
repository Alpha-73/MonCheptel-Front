/// Boutons MonCheptel.
///
/// Construits sur `Material` + `InkWell` plutot que sur `ElevatedButton` :
/// le theme des boutons Material passe par `WidgetStateProperty`, renomme
/// depuis `MaterialStateProperty` en cours de route. En s'en passant, le
/// meme code compile sur toutes les versions recentes de Flutter.
library;

import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/typographie.dart';

enum _Genre { principal, secondaire, destructif }

class _BoutonBase extends StatelessWidget {
  const _BoutonBase({
    required this.libelle,
    required this.genre,
    this.onPressed,
    this.icone,
    this.pleineLargeur = true,
    this.iconeApres = false,
    this.grand = false,
  });

  final String libelle;
  final _Genre genre;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool pleineLargeur;
  final bool iconeApres;
  final bool grand;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;

    final (Color fond, Color encre, Color? bord) = switch (genre) {
      _Genre.principal => (context.couleurs.marque, context.couleurs.surMarque, null),
      _Genre.secondaire => (Colors.transparent, context.couleurs.marque, context.couleurs.marque),
      _Genre.destructif => (Colors.transparent, context.couleurs.erreur, context.couleurs.erreur),
    };

    final texte = Text(
      libelle,
      style: Typo.bouton.copyWith(color: encre),
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    final contenu = Row(
      mainAxisSize: pleineLargeur ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icone != null && !iconeApres) ...[
          Icon(icone, size: 18, color: encre),
          const SizedBox(width: 8),
        ],
        // `Flexible` seulement en pleine largeur : un bouton compact peut
        // etre pose dans une `Row` sans `Expanded`, donc avec une largeur
        // non bornee, et un enfant flexible y leverait une erreur de rendu.
        if (pleineLargeur)
          Flexible(child: texte)
        else
          texte,
        if (icone != null && iconeApres) ...[
          const SizedBox(width: 10),
          Icon(icone, size: 18, color: encre),
        ],
      ],
    );

    return Opacity(
      opacity: actif ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: grand && genre == _Genre.secondaire ? context.couleurs.surface : fond,
          borderRadius: BorderRadius.circular(Dim.rayon),
          border: bord == null
              ? null
              : Border.all(color: bord, width: grand ? 1.5 : Dim.filet),
          // Les grands boutons des ecrans d'accueil portent l'ombre de la
          // maquette : un liseré vert pale 6 px sous le bouton.
          boxShadow: grand
              ? const [BoxShadow(color: Color(0x33146B66), offset: Offset(0, 6))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(Dim.rayon),
            child: Container(
              height: grand ? 56 : Dim.hauteurTactile,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: contenu,
            ),
          ),
        ),
      ),
    );
  }
}

/// Action principale de l'ecran. Une seule par ecran.
///
/// [iconeApres] : l'icone suit le libelle (« Continuer → »). [grand] :
/// 56 px et ombre, pour les ecrans d'accueil (splash, choix du profil).
class BoutonPrincipal extends StatelessWidget {
  const BoutonPrincipal(this.libelle,
      {super.key,
      this.onPressed,
      this.icone,
      this.pleineLargeur = true,
      this.iconeApres = false,
      this.grand = false});
  final String libelle;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool pleineLargeur;
  final bool iconeApres;
  final bool grand;

  @override
  Widget build(BuildContext context) => _BoutonBase(
        libelle: libelle, genre: _Genre.principal,
        onPressed: onPressed, icone: icone, pleineLargeur: pleineLargeur,
        iconeApres: iconeApres, grand: grand,
      );
}

/// Action secondaire : contour vert, fond transparent (blanc si [grand]).
class BoutonSecondaire extends StatelessWidget {
  const BoutonSecondaire(this.libelle,
      {super.key,
      this.onPressed,
      this.icone,
      this.pleineLargeur = true,
      this.grand = false});
  final String libelle;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool pleineLargeur;
  final bool grand;

  @override
  Widget build(BuildContext context) => _BoutonBase(
        libelle: libelle, genre: _Genre.secondaire,
        onPressed: onPressed, icone: icone, pleineLargeur: pleineLargeur,
        grand: grand,
      );
}

/// Suppression, desactivation, cloture. Rouge, jamais decoratif.
class BoutonDestructif extends StatelessWidget {
  const BoutonDestructif(this.libelle,
      {super.key, this.onPressed, this.pleineLargeur = true});
  final String libelle;
  final VoidCallback? onPressed;
  final bool pleineLargeur;

  @override
  Widget build(BuildContext context) => _BoutonBase(
        libelle: libelle, genre: _Genre.destructif,
        onPressed: onPressed, pleineLargeur: pleineLargeur,
      );
}
