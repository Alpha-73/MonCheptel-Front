/// Rythme et formes, mesures dans la maquette.
library;

abstract final class Dim {
  /// Gouttiere laterale. 16 px, la marge la plus frequente de la maquette.
  static const double gouttiere = 16;

  /// Marge interieure d'une carte.
  static const double padCarte = 13;

  /// Espace entre deux blocs de meme niveau.
  static const double ecart = 12;

  /// Espace avant un titre de section.
  static const double ecartSection = 24;

  /// Hauteur minimale d'un bouton et d'un champ. 48 px, 436 fois dans la
  /// maquette — c'est aussi le minimum recommande pour une cible tactile.
  static const double hauteurTactile = 48;

  /// Hauteur d'un onglet de filiere. 40 (36 dans la maquette) : avec
  /// l'espace autour, la zone tactile atteint les 48 recommandes.
  static const double hauteurOnglet = 40;

  /// Hauteur de la barre de navigation du bas.
  static const double hauteurBarreBas = 98;

  /// Hauteur de la barre de navigation fixe, hors zone sure.
  static const double hauteurBarre = 64;

  /// Rayon des cartes, boutons et champs. 12 depuis la revision du
  /// 6 octobre (8 dans la maquette) : angle plus doux, plus actuel.
  static const double rayon = 12;

  /// Rayon du haut du panneau d'historique / d'alertes.
  static const double rayonPanneau = 24;

  /// Rayon des pastilles et des onglets.
  static const double rayonPastille = 16;

  /// Epaisseur du filet des cartes.
  static const double filet = 1;

  /// Bordure gauche des encarts contextuels.
  static const double bordureEncart = 3;
}
