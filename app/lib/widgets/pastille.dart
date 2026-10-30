/// Pastilles d'etat et onglets de filiere.
library;

import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/typographie.dart';

enum TonPastille { neutre, marque, attention, erreur }

/// Etiquette d'etat : « Actif », « Élevé », « En modération ».
class Pastille extends StatelessWidget {
  const Pastille(this.libelle, {super.key, this.ton = TonPastille.neutre});

  final String libelle;
  final TonPastille ton;

  (Color, Color) _couleurs(BuildContext context) => switch (ton) {
        TonPastille.neutre => (context.couleurs.filet, context.couleurs.texte),
        TonPastille.marque => (context.couleurs.fondMarquePale, context.couleurs.marque),
        // texte fonce, pas l'orange de fond : #F4A259 sur #FDEEE1 est illisible
        TonPastille.attention => (context.couleurs.fondAttentionPale, context.couleurs.attentionTexte),
        TonPastille.erreur => (context.couleurs.fondErreurPale, context.couleurs.erreur),
      };

  @override
  Widget build(BuildContext context) {
    final (fond, encre) = _couleurs(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(Dim.rayonPastille),
      ),
      child: Text(libelle, style: Typo.pastille.copyWith(color: encre)),
    );
  }
}

/// Barre d'onglets de filiere : Volaille · Bovins · Ovins · Caprins.
///
/// Defile horizontalement : quatre onglets tiennent sur un ecran de 402 px,
/// pas forcement sur un plus etroit, et le projet peut gagner une filiere.
class Onglets extends StatelessWidget {
  const Onglets({
    super.key,
    required this.libelles,
    required this.indexActif,
    required this.onChange,
  });

  final List<String> libelles;
  final int indexActif;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Dim.hauteurOnglet,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
        itemCount: libelles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final actif = i == indexActif;
          return Material(
            color: actif ? context.couleurs.marque : context.couleurs.surface,
            borderRadius: BorderRadius.circular(Dim.rayonPastille),
            child: InkWell(
              onTap: actif ? null : () => onChange(i),
              borderRadius: BorderRadius.circular(Dim.rayonPastille),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dim.rayonPastille),
                  border: actif
                      ? null
                      : Border.all(color: context.couleurs.filet, width: Dim.filet),
                ),
                child: Text(
                  libelles[i],
                  style: (actif ? Typo.pastille : context.typo.legendeForte).copyWith(
                    color: actif ? context.couleurs.surMarque : context.couleurs.texteDiscret,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rond d'initiales, en tete d'une ligne de liste ou d'une fiche.
class Avatar extends StatelessWidget {
  const Avatar(this.initiales,
      {super.key, this.taille = 40, this.ton = TonPastille.marque, this.pale = false});

  final String initiales;
  final double taille;
  final TonPastille ton;

  /// Fond vert pale et initiales vertes (maquette du parcours veterinaire),
  /// au lieu du rond plein.
  final bool pale;

  @override
  Widget build(BuildContext context) {
    final (fond, encre) = pale
        ? (context.couleurs.fondMarquePale, context.couleurs.marque)
        : switch (ton) {
      TonPastille.marque => (context.couleurs.marque, context.couleurs.surMarque),
      TonPastille.erreur => (context.couleurs.erreur, context.couleurs.surMarque),
      TonPastille.attention => (context.couleurs.attention, context.couleurs.surAccent),
      TonPastille.neutre => (context.couleurs.filet, context.couleurs.texte),
          };
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
      child: Text(
        initiales,
        style: TextStyle(
          fontFamily: Typo.police,
          fontSize: taille * 0.36,
          fontWeight: FontWeight.w700,
          color: encre,
        ),
      ),
    );
  }
}
