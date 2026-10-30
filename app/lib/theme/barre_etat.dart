/// Couleur des icones de la barre d'etat (heure, batterie, reseau) et de la
/// barre de navigation systeme d'Android.
///
/// LE DEFAUT CORRIGE ICI. Seul l'en-tete `AppBar` declarait un style
/// (icones claires, pour le fond vert). Flutter ne retablit PAS le style
/// quand on quitte cet ecran : un ecran sans declaration garde celui du
/// precedent. Sur la connexion, au fond clair, les icones restaient donc
/// blanches sur blanc — invisibles.
///
/// La regle desormais : CHAQUE zone declare son style.
///  - [surClair] couvre toute l'application (pose dans `main.dart`) : c'est
///    le defaut, pour tout ecran dont le haut est clair ;
///  - [surMarque] est pose par tout en-tete vert (`AppBar` via le theme,
///    `EnteteMarque` explicitement) et l'emporte sur le defaut, parce que
///    Flutter retient la declaration la plus profonde sous la barre d'etat.
///
/// Depuis Android 15, l'application s'affiche bord a bord : la barre d'etat
/// est transparente et ce qui est dessous (en-tete vert ou fond clair) se
/// voit au travers. Seule la couleur des ICONES est donc a choisir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'couleurs.dart';
import 'palette.dart';

abstract final class BarreEtat {
  /// Icones sombres, pour un haut d'ecran clair.
  static const SystemUiOverlayStyle surClair = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS : decrit le FOND, pas les icones
    systemNavigationBarColor: Couleurs.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Couleurs.filet,
  );

  /// Icones claires, pour l'en-tete vert.
  static const SystemUiOverlayStyle surMarque = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Couleurs.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Couleurs.filet,
  );

  /// Le style du fond de l'ecran : icones sombres sur le sable du theme
  /// clair, claires sur le vert-noir du theme sombre. La barre systeme
  /// d'Android prend la couleur des surfaces du theme.
  static SystemUiOverlayStyle pourFond(PaletteMonCheptel c) => c.sombre
      ? SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: c.fond,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: c.filetLeger,
        )
      : surClair;

  /// Le style sous un en-tete vert : icones claires dans les deux themes.
  static SystemUiOverlayStyle pourEntete(PaletteMonCheptel c) => c.sombre
      ? pourFond(c)
      : surMarque;
}
