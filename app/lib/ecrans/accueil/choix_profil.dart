/// Maquette « Splash - Choix du profil » : bandeau du logo et ses ondes,
/// « Bienvenue sur MonCheptel », puis Éleveur ou Vétérinaire.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../theme/barre_etat.dart';
import '../../theme/palette.dart';
import '../../widgets/marque.dart';
import '../auth/connexion.dart';
import '../../widgets/mise_en_page.dart';

class ChoixProfil extends StatelessWidget {
  const ChoixProfil({super.key});

  void _ouvrir(BuildContext context, EspaceConnexion espace) {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EcranConnexion(espace: espace)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarreEtat.pourFond(context.couleurs),
      child: Scaffold(
        body: FondMarque(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(padding: lisible(context), 
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BandeauLogo(),
                      const SizedBox(height: 56),
                      Text('Bienvenue sur MonCheptel',
                          textAlign: TextAlign.center,
                          style: context.typo.chiffre.copyWith(height: 1.25)),
                      const SizedBox(height: 12),
                      const Center(child: TraitMarque()),
                      const SizedBox(height: 14),
                      Text('Choisissez votre profil pour continuer',
                          textAlign: TextAlign.center, style: context.typo.legende),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BoutonProfil(
                              libelle: 'Éleveur',
                              detail: "J'élève des animaux",
                              icone: Icons.agriculture_outlined,
                              plein: true,
                              onTap: () => _ouvrir(context, EspaceConnexion.eleveur),
                            ),
                            const SizedBox(height: 20),
                            _BoutonProfil(
                              libelle: 'Vétérinaire',
                              detail: 'Je soigne les animaux',
                              icone: Icons.medical_services_outlined,
                              plein: false,
                              onTap: () => _ouvrir(context, EspaceConnexion.veterinaire),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 32),
                      Text('Mali · Version ${Config.version}',
                          textAlign: TextAlign.center,
                          style: context.typo.legende),
                      SizedBox(height: 20 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le haut des ecrans d'accueil et de connexion : un panneau vert pale
/// arrondi en bas, les ondes du logo derriere lui, deux bulles (blanche en
/// haut a droite, peche a gauche) et le logo au centre.
class BandeauLogo extends StatelessWidget {
  const BandeauLogo(
      {super.key, this.hauteur = 296, this.largeurLogo = 220, this.anime = true});
  final double hauteur;
  final double largeurLogo;

  /// Ondes animees. Immobiles sur la connexion : on y lit et on y tape.
  final bool anime;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: hauteur + haut,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: ColoredBox(
          color: context.couleurs.fondMarquePale.withAlpha(0x99),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: -60, top: -70 + haut * 0.3, width: 200, height: 200,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.couleurs.surface.withAlpha(0x59))),
              ),
              Positioned(
                left: -46, bottom: -20, width: 120, height: 120,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.couleurs.fondAttentionPale.withAlpha(0xBF))),
              ),
              Positioned(
                top: haut + hauteur / 2 - 180,
                child: OndesSignal(taille: 340, point: false, anime: anime),
              ),
              Positioned(
                top: haut + (hauteur - largeurLogo * LogoMonCheptel.proportion) / 2,
                child: LogoMonCheptel(largeur: largeurLogo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonProfil extends StatelessWidget {
  const _BoutonProfil({
    required this.libelle,
    required this.detail,
    required this.icone,
    required this.plein,
    required this.onTap,
  });

  final String libelle;
  final String detail;
  final IconData icone;
  final bool plein;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final encre = plein ? context.couleurs.surEntete : context.couleurs.marque;
    return Semantics(
      button: true,
      label: 'Je suis $libelle. $detail',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: plein
              ? LinearGradient(colors: [context.couleurs.enteteDebut, context.couleurs.enteteFin])
              : null,
          color: plein ? null : context.couleurs.surface,
          borderRadius: BorderRadius.circular(18),
          border: plein ? null : Border.all(color: context.couleurs.marque, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x1F146B66), offset: Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            // 80 px au moins ; plus haut si le texte est agrandi.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: plein ? context.couleurs.accent : context.couleurs.fondMarquePale,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icone,
                        color: plein ? context.couleurs.surAccent : context.couleurs.marque, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(libelle,
                            style: context.typo.titreSection.copyWith(color: encre, height: 1.1)),
                        Text(detail,
                            style: context.typo.corps.copyWith(
                                color: plein ? context.couleurs.surMarqueDiscret : context.couleurs.texteDiscret)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: encre),
                  const SizedBox(width: 16),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
