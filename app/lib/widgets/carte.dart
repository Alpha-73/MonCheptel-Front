/// Cartes et encarts — le vocabulaire de surface de la maquette.
library;

import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';

/// Carte blanche, rayon 12, filet tres leger et ombre douce.
///
/// Revision du 6 octobre : la maquette dessinait un filet gris sans ombre.
/// L'ombre de 2 px detache la carte du fond sans l'alourdir — c'est le
/// niveau 1 d'elevation des guides Material 3 et iOS. Le filet est garde,
/// plus clair, pour les ecrans peu contrastes au soleil.
///
/// Devient cliquable des qu'on lui passe [onTap] : l'effet d'encre est
/// decoupe au rayon de la carte, pas au rectangle qui la contient.
class Carte extends StatelessWidget {
  const Carte({
    super.key,
    required this.enfant,
    this.onTap,
    this.padding = const EdgeInsets.all(Dim.padCarte),
  });

  final Widget enfant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final contenu = Padding(padding: padding, child: enfant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        border: Border.all(color: context.couleurs.filetLeger, width: Dim.filet),
        borderRadius: BorderRadius.circular(Dim.rayon),
        boxShadow: [
          BoxShadow(color: context.couleurs.ombre, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: onTap == null
          ? contenu
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Dim.rayon),
                child: contenu,
              ),
            ),
    );
  }
}

/// Teinte d'un encart contextuel.
enum TonEncart { marque, attention, erreur }

/// Encart contextuel : fond teinte pale + bordure gauche de 3 px.
///
/// Sert aux alertes, aux rappels et aux avertissements. Le rouge est reserve
/// au destructif et aux erreurs — pas a « important ».
class Encart extends StatelessWidget {
  const Encart({
    super.key,
    required this.titre,
    this.detail,
    this.ton = TonEncart.marque,
    this.onTap,
    this.fort = true,
  });

  final String titre;
  final String? detail;
  final TonEncart ton;
  final VoidCallback? onTap;

  /// Titre en gras (defaut). `false` : un paragraphe d'explication en corps
  /// normal, comme les encarts des formulaires veterinaires.
  final bool fort;

  (Color, Color) _couleurs(BuildContext context) => switch (ton) {
        TonEncart.marque => (context.couleurs.fondMarquePale, context.couleurs.marque),
        TonEncart.attention => (context.couleurs.fondAttentionPale, context.couleurs.attention),
        TonEncart.erreur => (context.couleurs.fondErreurPale, context.couleurs.erreur),
      };

  @override
  Widget build(BuildContext context) {
    final (fond, bord) = _couleurs(context);
    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titre, style: fort ? context.typo.corpsFort : context.typo.corps),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: context.typo.legende),
          ],
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(Dim.rayon),
        border: Border(left: BorderSide(color: bord, width: Dim.bordureEncart)),
      ),
      child: onTap == null
          ? contenu
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Dim.rayon),
                child: contenu,
              ),
            ),
    );
  }
}

/// Tuile de statistique : un libelle, un chiffre, une precision.
///
/// S'emploie par deux dans une `Row`, chacune dans un `Expanded`.
class TuileStat extends StatelessWidget {
  const TuileStat({
    super.key,
    required this.libelle,
    required this.valeur,
    this.precision,
    this.onTap,
  });

  final String libelle;
  final String valeur;
  final String? precision;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Carte(
      onTap: onTap,
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(libelle, style: context.typo.corpsDiscret),
          const SizedBox(height: 6),
          Text(valeur, style: context.typo.chiffre),
          if (precision != null) ...[
            const SizedBox(height: 4),
            Text(precision!, style: context.typo.legende),
          ],
        ],
      ),
    );
  }
}

/// Carte d'acces a un autre ecran : pictogramme dans un carre teinte,
/// titre, precision, chevron. « Rapports et statistiques », « Où investir ».
///
/// Toute la carte est la cible tactile, et elle s'annonce comme un bouton
/// aux lecteurs d'ecran.
class CarteAcces extends StatelessWidget {
  const CarteAcces({
    super.key,
    required this.icone,
    required this.titre,
    this.detail,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Carte(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        enfant: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.couleurs.fondMarquePale,
                borderRadius: BorderRadius.circular(Dim.rayon),
              ),
              child: Icon(icone, color: context.couleurs.marque, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: context.typo.corpsFort),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: context.typo.legende),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.couleurs.texteDiscret),
          ],
        ),
      ),
    );
  }
}
