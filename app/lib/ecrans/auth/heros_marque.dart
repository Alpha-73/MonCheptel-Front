/// Le haut des ecrans de connexion, d'inscription et de mot de passe
/// oublie : degrade vert du logo, ondes du signal qui
/// respirent, logo blanc, bord inferieur droit.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/barre_etat.dart';
import '../../theme/palette.dart';
import '../../theme/typographie.dart';
import '../../widgets/marque.dart';
import '../../widgets/vivant.dart';

class HerosMarque extends StatelessWidget {
  const HerosMarque({super.key, this.compact = false, this.titre, this.retour = false});

  /// Logo en ligne et titre, au lieu du grand logo (formulaires longs).
  final bool compact;
  final String? titre;

  /// Fleche de retour en haut a gauche.
  final bool retour;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final ecran = MediaQuery.sizeOf(context);
    // Ecran bas (telephone en paysage, petit Android) : le heros se tasse
    // pour laisser le formulaire visible sans defiler.
    final bas = ecran.height < 640;
    final hauteur = (compact ? (bas ? 118.0 : 150.0) : (bas ? 170.0 : 250.0)) + haut;
    final largeur = ecran.width;
    final largeurLogo = (largeur * 0.62).clamp(150.0, bas ? 180.0 : 230.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarreEtat.pourEntete(context.couleurs),
      // Bord inferieur droit, comme les en-tetes de l'application (10 octobre).
      child: ClipRect(
        child: Container(
          height: hauteur,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.couleurs.enteteSombreDebut,
                context.couleurs.enteteDebut,
                context.couleurs.enteteFin,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: -largeur * 0.25,
                top: -60,
                child: OndesSignal(
                  taille: compact || bas ? 240 : 340,
                  anime: !mouvementReduit(context),
                  couleur: const Color(0xFFFFFFFF),
                ),
              ),
              Positioned(
                left: -50,
                bottom: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0x1FEF9429)),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: haut, bottom: 18),
                child: compact
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const LogoEnLigne(hauteur: 30, clair: true),
                          if (titre != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              header: true,
                              child: Text(titre!,
                                  style: Typo.titreEcran.copyWith(fontSize: 24)),
                            ),
                          ],
                        ],
                      )
                    : LogoMonCheptel(largeur: largeurLogo, clair: true),
              ),
              if (retour)
                Positioned(
                  left: 4,
                  top: haut + 4,
                  child: BackButton(color: context.couleurs.surEntete),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Largeur maximale d'un formulaire d'accueil : au-dela, les champs
/// s'etirent et l'ecran parait vide (tablette, paysage).
const double largeurFormulaire = 480;

/// Centre son contenu dans une colonne d'au plus [largeurFormulaire] px,
/// en respectant l'encoche du telephone en paysage.
class ColonneFormulaire extends StatelessWidget {
  const ColonneFormulaire({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sur = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(left: sur.left, right: sur.right),
      // heightFactor 1 : la colonne prend la hauteur de son contenu, meme
      // dans une barre du bas (Center s'etirerait sur toute la hauteur).
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: largeurFormulaire),
          child: child,
        ),
      ),
    );
  }
}

/// Carte blanche du formulaire, qui chevauche le bas du heros.
class CarteFormulaire extends StatelessWidget {
  const CarteFormulaire({super.key, required this.enfants});
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x1F0B5653), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
      );
}
