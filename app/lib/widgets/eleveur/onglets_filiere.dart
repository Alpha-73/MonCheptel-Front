/// Onglets de filiere de l'espace eleveur : pictogramme + nom, 48 px de
/// haut (cible tactile pleine), onglet actif en vert plein avec le point
/// orange du logo. Distincts des onglets de periode ou de type, qui gardent
/// la forme [Onglets].
library;

import 'package:flutter/material.dart';

import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import 'pictos.dart';

class OngletsFiliere extends StatelessWidget {
  const OngletsFiliere({
    super.key,
    required this.filieres,
    required this.active,
    required this.onChange,
  });

  /// Codes du back ; `null` = « Toutes ».
  final List<String?> filieres;
  final String? active;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Dim.hauteurTactile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
        itemCount: filieres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filieres[i];
          final actif = f == active;
          final encre = actif ? context.couleurs.surMarque : context.couleurs.encreFonce;
          return Semantics(
            selected: actif,
            button: true,
            label: f == null ? 'Toutes' : L.filiere(f),
            excludeSemantics: true,
            child: Material(
              color: actif ? context.couleurs.marque : context.couleurs.surface,
              shape: StadiumBorder(
                  side: actif ? BorderSide.none : BorderSide(color: context.couleurs.filetLeger)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: actif ? null : () => onChange(f),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (f != null) ...[
                        PictoAnimal.filiere(f, taille: 22, couleur: encre, plein: actif),
                        const SizedBox(width: 8),
                      ],
                      Text(f == null ? 'Toutes' : L.filiere(f),
                          style: context.typo.corpsFort.copyWith(color: encre)),
                      if (actif) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: context.couleurs.accent, shape: BoxShape.circle),
                        ),
                      ],
                    ],
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
