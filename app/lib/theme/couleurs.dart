/// Palette MonCheptel.
///
/// Chaque valeur est MESUREE dans la maquette, pas choisie ici : les huit
/// couleurs de texte ci-dessous sont exactement celles que portent les 115
/// ecrans, et quatre d'entre elles couvrent 95 % des occurrences.
///
/// Ne pas ajouter de couleur sans l'ajouter d'abord a la maquette.
///
/// Revision du 6 octobre (passe d'accessibilite WCAG 2.1 AA) : deux textes
/// de la maquette n'atteignaient pas le contraste 4,5:1 exige pour un texte
/// courant. Ils sont fonces/eclaircis ci-dessous, la teinte ne change pas.
library;

import 'package:flutter/material.dart';

abstract final class Couleurs {
  // ── marque ────────────────────────────────────────────────────────────
  /// Vert de marque. En-tetes, boutons principaux, liens, etats actifs.
  static const Color marque = Color(0xFF146B66);

  /// Vert sombre. Menu lateral de l'administration, fonds appuyes.
  static const Color marqueSombre = Color(0xFF0E3F3C);

  /// Vert pale sur fond vert : sous-titre d'en-tete, texte secondaire clair.
  /// 4,9:1 sur [marque]. La maquette portait #B7CDCB : 3,8:1, sous le
  /// seuil AA.
  static const Color surMarqueDiscret = Color(0xFFD6E6E4);

  /// Les deux couleurs du logo. [logoVert] pour les grands aplats de marque
  /// (en-tete de l'accueil), [accent] pour les touches orange : trait sous
  /// un titre, ondes, point de signal. [accent] n'est JAMAIS une couleur de
  /// texte sur fond clair (2,3:1).
  static const Color logoVert = Color(0xFF0B5653);
  static const Color accent = Color(0xFFEF9429);

  /// Fonds des ecrans d'accueil (maquettes « Splash anime » et « Choix du
  /// profil ») et de la connexion (« Espace éleveur »).
  static const Color fondAccueilHaut = Color(0xFFF7FBFA);
  static const Color fondAccueilBas = Color(0xFFDCEAE7);
  static const Color fondConnexion = Color(0xFFF2F7F5);

  // ── semantique ────────────────────────────────────────────────────────
  /// Sante et information.
  static const Color sante = Color(0xFF2A6F97);

  /// Attention. Reserve aux FONDS et aux bordures.
  /// Pour du TEXTE sur fond clair, utiliser [attentionTexte] : #F4A259 sur
  /// blanc donne un contraste de 2,07, illisible.
  static const Color attention = Color(0xFFF4A259);

  /// Attention, version texte. Contraste 4,85 sur blanc — conforme AA.
  static const Color attentionTexte = Color(0xFFA8500A);

  /// Destructif et erreurs. Jamais decoratif.
  static const Color erreur = Color(0xFFC43D3D);

  // ── gravite d'un cas (liseré des cartes de l'espace veterinaire) ─────
  static const Color graviteHaute = Color(0xFFC43D3D);
  static const Color graviteMoyenne = Color(0xFFEF9429);
  static const Color graviteFaible = Color(0xFF2A8C6E);

  // ── surfaces ──────────────────────────────────────────────────────────
  /// Fond des ecrans : sable tres clair (refonte du 7 octobre, etait le
  /// gris neutre #F4F4F2). Chaud sans etre jaune ; [texteDiscret] y garde
  /// 5:1.
  static const Color fond = Color(0xFFF7F4EE);

  /// Sable plus soutenu : fonds de tuiles, pistes de jauge, squelettes.
  static const Color sable = Color(0xFFEDE6DA);

  /// Terre cuite : touches decoratives, rien d'autre. Jamais texte.
  static const Color terre = Color(0xFFB98A5E);

  /// Orange pale : fond du bouton d'action central et des moments cles.
  static const Color fondAccentPale = Color(0xFFFFF1E0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color filet = Color(0xFFD8D8D5);
  static const Color filetLeger = Color(0xFFE8E8E5);

  /// Fonds teintes des encarts contextuels, avec bordure gauche de 3 px.
  static const Color fondMarquePale = Color(0xFFE4EFEE);
  static const Color fondMarquePale2 = Color(0xFFE1F0EE);
  static const Color fondAttentionPale = Color(0xFFFDEEE1);
  static const Color fondErreurPale = Color(0xFFFAE8E8);

  // ── textes ────────────────────────────────────────────────────────────
  /// Titres d'ecran.
  static const Color titre = Color(0xFF000000);

  /// Corps de texte.
  static const Color texte = Color(0xFF333333);

  /// Texte secondaire, legendes.
  ///
  /// 4,9:1 sur [fond], 5,4:1 sur blanc : conforme AA. La maquette portait
  /// #767674, a 4,13:1 sur [fond].
  static const Color texteDiscret = Color(0xFF6A6A68);

  /// Texte indicatif des champs vides. Contraste 2,82 sur blanc : reserve
  /// aux placeholders, jamais a une information utile.
  static const Color texteIndicatif = Color(0xFF9A9A98);

  static const Color surMarque = Color(0xFFFFFFFF);

  // ── ombres ────────────────────────────────────────────────────────────
  /// Ombre douce des cartes : noir a 6 %. Ecrite en ARGB plutot qu'avec
  /// `withOpacity`, deprecie a partir de Flutter 3.27.
  static const Color ombre = Color(0x0F000000);

  /// Ombre du panneau qui porte l'historique et les alertes : noir a 10 %.
  static const Color ombrePanneau = Color(0x1A000000);

  // ── graphiques ────────────────────────────────────────────────────────
  /// Revenus et depenses dans les graphiques de l'ecran Rapports.
  ///
  /// Pas le vert de marque ni l'orange d'attention : verifies avec un
  /// validateur de palette (daltonismes protan, deutan, tritan ; contraste
  /// >= 3:1 sur blanc pour une marque graphique), #146B66 « se lit gris »
  /// une fois reduit a une barre fine, et #F4A259 tombe a 2,1:1 sur blanc.
  /// Ces deux-la passent les six controles. Jamais employes pour du texte.
  static const Color graphiqueRevenus = Color(0xFF00897B);
  static const Color graphiqueDepenses = Color(0xFFD9731F);

  /// Les memes a 35 % : colonnes NON selectionnees. La colonne choisie
  /// ressort sans changer de couleur — l'identite revenus/depenses reste.
  static const Color graphiqueRevenusAttenue = Color(0x5900897B);
  static const Color graphiqueDepensesAttenue = Color(0x59D9731F);
}
