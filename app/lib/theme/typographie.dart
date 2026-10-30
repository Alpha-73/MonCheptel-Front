/// Echelle typographique MonCheptel.
///
/// Cinq tailles, trois graisses : 14 · 16 · 18 · 20 · 24 px, en 500 · 600 ·
/// 700. Si vous avez besoin d'un 17 px semi-gras, c'est presque toujours que
/// le composant est mal choisi.
///
/// Deux voix depuis la refonte du 7 octobre : [titres] (Baloo 2, ronde,
/// chaleureuse) pour les titres et les chiffres, [police] (Nunito) pour le
/// reste. Baloo 2 dessine plus petit que Nunito a taille egale : ses tailles
/// sont relevees de 2 px.
library;

import 'package:flutter/material.dart';
import 'couleurs.dart';

abstract final class Typo {
  static const String police = 'Nunito';
  static const String titres = 'Baloo2';

  /// Grand titre d'accueil (« Bonjour Awa »). 26/800.
  static const TextStyle accroche = TextStyle(
    fontFamily: titres, fontSize: 26, fontWeight: FontWeight.w800,
    color: Couleurs.surMarque, height: 1.1,
  );

  /// Tres grand chiffre (jauge, solde de l'accueil). 34/800.
  static const TextStyle chiffreHeros = TextStyle(
    fontFamily: titres, fontSize: 34, fontWeight: FontWeight.w800,
    color: Couleurs.titre, height: 1.0,
  );

  // ── titres ────────────────────────────────────────────────────────────

  /// Titre d'ecran. 20/700 blanc dans l'en-tete vert.
  static const TextStyle titreEcran = TextStyle(
    fontFamily: titres, fontSize: 22, fontWeight: FontWeight.w700,
    color: Couleurs.surMarque, height: 1.2,
  );

  /// Titre de section dans le corps. 18/700 noir.
  static const TextStyle titreSection = TextStyle(
    fontFamily: titres, fontSize: 20, fontWeight: FontWeight.w700,
    color: Couleurs.titre, height: 1.3,
  );

  /// Chiffre mis en avant. 24/700 noir — les soldes, les effectifs.
  static const TextStyle chiffre = TextStyle(
    fontFamily: titres, fontSize: 26, fontWeight: FontWeight.w700,
    color: Couleurs.titre, height: 1.15,
  );

  // ── corps ─────────────────────────────────────────────────────────────

  /// Corps courant. 16/500.
  static const TextStyle corps = TextStyle(
    fontFamily: police, fontSize: 16, fontWeight: FontWeight.w600,
    color: Couleurs.texte, height: 1.35,
  );

  /// Corps secondaire. 16/500 gris — libelles de carte, sous-titres.
  static const TextStyle corpsDiscret = TextStyle(
    fontFamily: police, fontSize: 16, fontWeight: FontWeight.w600,
    color: Couleurs.texteDiscret, height: 1.35,
  );

  /// Corps appuye. 16/700 — titre d'une ligne de liste, d'un encart.
  static const TextStyle corpsFort = TextStyle(
    fontFamily: police, fontSize: 16, fontWeight: FontWeight.w700,
    color: Couleurs.texte, height: 1.35,
  );

  /// Libelle de bouton. 16/700.
  static const TextStyle bouton = TextStyle(
    fontFamily: police, fontSize: 16, fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // ── legendes ──────────────────────────────────────────────────────────

  /// Legende. 14/500 gris — la taille la plus employee de la maquette.
  static const TextStyle legende = TextStyle(
    fontFamily: police, fontSize: 14, fontWeight: FontWeight.w600,
    color: Couleurs.texteDiscret, height: 1.35,
  );

  /// Legende appuyee. 14/600 — onglets, entrees de barre de navigation.
  static const TextStyle legendeForte = TextStyle(
    fontFamily: police, fontSize: 14, fontWeight: FontWeight.w600,
    color: Couleurs.texteDiscret, height: 1.3,
  );

  /// Etiquette d'etat dans une pastille. 14/700.
  static const TextStyle pastille = TextStyle(
    fontFamily: police, fontSize: 14, fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Ligne de contexte sous un titre d'ecran. 15/600 vert.
  static const TextStyle contexte = TextStyle(
    fontFamily: police, fontSize: 15, fontWeight: FontWeight.w600,
    color: Couleurs.marque, height: 1.3,
  );
}
