/// Mots et pictogrammes de la sante, cote eleveur : statut d'un
/// signalement dit simplement, couleur de gravite, pictogramme d'un
/// symptome ou d'une filiere.
library;

import 'package:flutter/material.dart';

import '../../../theme/palette.dart';

/// Minuscules, sans accents : « Diarrhée verdâtre » → « diarrhee verdatre ».
String normaliser(String s) {
  const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
  const sans = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i < 0 ? c : sans[i]);
  }
  return b.toString();
}

/// Pictogramme d'un symptome, d'apres son libelle.
IconData iconeSymptome(String libelle) {
  final s = normaliser(libelle);
  if (s.contains('sang')) return Icons.bloodtype_outlined;
  if (s.contains('diarrhee')) return Icons.water_drop_outlined;
  if (s.contains('deshydrat')) return Icons.local_drink_outlined;
  if (s.contains('toux')) return Icons.air_rounded;
  if (s.contains('nasal') || s.contains('nez')) return Icons.masks_outlined;
  if (s.contains('torticolis') || s.contains('tete')) return Icons.rotate_right_rounded;
  if (s.contains('abattement') || s.contains('fatigue')) return Icons.bedtime_outlined;
  if (s.contains('ponte') || s.contains('oeuf')) return Icons.egg_outlined;
  if (s.contains('mort')) return Icons.heart_broken_outlined;
  if (s.contains('fievre') || s.contains('chaud')) return Icons.thermostat_rounded;
  if (s.contains('boiter') || s.contains('patte')) return Icons.directions_walk_rounded;
  if (s.contains('appetit') || s.contains('mange')) return Icons.no_food_outlined;
  if (s.contains('vesicule') || s.contains('bouche') || s.contains('buccal')) {
    return Icons.sick_outlined;
  }
  if (s.contains('plume') || s.contains('peau')) return Icons.texture_rounded;
  return Icons.visibility_outlined;
}

/// Pictogramme d'une filiere.
IconData iconeFiliere(String filiere) => switch (filiere) {
      'VOLAILLE' => Icons.egg_alt_outlined,
      'BOVINS' => Icons.agriculture_outlined,
      'OVINS' => Icons.cloud_outlined,
      'CAPRINS' => Icons.grass_outlined,
      _ => Icons.pets_outlined,
    };

/// Statut d'un signalement, dit a l'eleveur (pas le vocabulaire du
/// veterinaire : « Orienté » ne parle a personne).
String statutPourEleveur(String statut) => switch (statut) {
      'NOUVEAU' => 'Envoyé',
      'ORIENTE' => 'En attente de réponse',
      'EN_COURS' => 'Accepté',
      'TRAITE' => 'Réponse reçue',
      _ => statut,
    };

Color couleurStatut(BuildContext context, String statut) => switch (statut) {
      'NOUVEAU' => context.couleurs.texteDiscret,
      'ORIENTE' => context.couleurs.graviteMoyenne,
      'EN_COURS' => context.couleurs.sante,
      'TRAITE' => context.couleurs.graviteFaible,
      _ => context.couleurs.texteDiscret,
    };

/// Rang du statut dans le suivi (0 a 3).
int rangStatut(String statut) => switch (statut) {
      'NOUVEAU' => 0,
      'ORIENTE' => 1,
      'EN_COURS' => 2,
      'TRAITE' => 3,
      _ => 0,
    };

/// Couleur pleine d'une gravite (bandeau du resultat).
Color couleurGravite(BuildContext context, String? gravite) => switch (gravite) {
      'ELEVE' => context.couleurs.graviteHaute,
      'MOYEN' => context.couleurs.attentionTexte,
      'FAIBLE' => context.couleurs.graviteFaible,
      _ => context.couleurs.marque,
    };

/// « Grave », « À surveiller », « Peu grave » : la gravite en un mot.
String graviteSimple(String? gravite) => switch (gravite) {
      'ELEVE' => 'Grave',
      'MOYEN' => 'À surveiller',
      'FAIBLE' => 'Peu grave',
      _ => 'À vérifier',
    };

IconData iconeGravite(String? gravite) => switch (gravite) {
      'ELEVE' => Icons.error_rounded,
      'MOYEN' => Icons.warning_rounded,
      'FAIBLE' => Icons.check_circle_rounded,
      _ => Icons.help_rounded,
    };

/// Conduite a tenir, en phrases courtes, selon la gravite et
/// l'orientation.
List<String> conduiteATenir({required String? gravite, required bool orientation}) {
  if (gravite == 'ELEVE') {
    return const [
      'Séparez les animaux malades des autres.',
      'Ne vendez et ne déplacez aucun animal.',
      "Appelez un vétérinaire aujourd'hui.",
    ];
  }
  if (orientation) {
    return const [
      'Séparez les animaux malades.',
      'Appelez un vétérinaire rapidement.',
    ];
  }
  return const [
    'Surveillez les animaux chaque jour.',
    'Gardez l’eau et le local propres.',
    'Si ça empire, appelez un vétérinaire.',
  ];
}
