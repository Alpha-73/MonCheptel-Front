/// Mots et pictogrammes de l'argent, cote eleveur : pas d'« opération »,
/// de « sortie » ni de « dépense partagée » sans explication.
library;

import 'package:flutter/material.dart';

import '../../../libelles.dart';
import '../../../theme/palette.dart';

IconData iconeCategorie(String c) => switch (c) {
      'ALIMENT' => Icons.inventory_2_outlined,
      'SOINS_VACCINATION' => Icons.vaccines_outlined,
      'MAIN_D_OEUVRE' => Icons.engineering_outlined,
      'TRANSPORT' => Icons.local_shipping_outlined,
      'EQUIPEMENT' => Icons.handyman_outlined,
      'VENTE_ANIMAUX' => Icons.sell_outlined,
      'VENTE_PRODUITS' => Icons.egg_outlined,
      _ => Icons.payments_outlined,
    };

/// Libelle court d'une categorie, pour une tuile (« Soins », « Ouvriers »).
String libelleCategorieCourt(String c) => switch (c) {
      'ALIMENT' => 'Aliment',
      'SOINS_VACCINATION' => 'Soins, vaccins',
      'MAIN_D_OEUVRE' => 'Ouvriers',
      'TRANSPORT' => 'Transport',
      'EQUIPEMENT' => 'Matériel',
      'VENTE_ANIMAUX' => 'Vente d’animaux',
      'VENTE_PRODUITS' => 'Œufs, lait…',
      _ => L.categorieOperation(c),
    };

Color couleurType(BuildContext context, String type) =>
    type == 'REVENU' ? context.couleurs.graphiqueRevenus : context.couleurs.graphiqueDepenses;

/// Les libelles generes par le back sont sans accents (« Vente LOT-014 —
/// 30 tete(s) ») : on les corrige a l'affichage.
String corrigerLibelle(String s) => s
    .replaceAllMapped(RegExp(r'(\d+) tete\(s\)'),
        (m) => '${m[1]} tête${int.parse(m[1]!) > 1 ? 's' : ''}')
    .replaceAll('tete(s)', 'têtes')
    .replaceAll(RegExp(r'\btete\b'), 'tête');
