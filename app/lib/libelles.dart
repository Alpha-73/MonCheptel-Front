/// Libelles francais des valeurs d'enumeration du back.
///
/// Le back envoie des codes (`'SOINS_VACCINATION'`) ; l'ecran montre des
/// mots (« Soins et vaccination »). Toute la traduction est ici, nulle part
/// ailleurs : si un libelle change, il change une fois.
///
/// Code inconnu (le back a gagne une valeur que l'application ne connait
/// pas encore) : on affiche le code brut plutot que de planter.
library;

import 'widgets/pastille.dart';

abstract final class L {
  // ── filieres ────────────────────────────────────────────────────────────

  /// Ordre d'affichage, celui de la maquette et de l'enum Java.
  static const List<String> filieres = ['VOLAILLE', 'BOVINS', 'OVINS', 'CAPRINS'];

  static String filiere(String? c) => switch (c) {
        'VOLAILLE' => 'Volaille',
        'BOVINS' => 'Bovins',
        'OVINS' => 'Ovins',
        'CAPRINS' => 'Caprins',
        null => 'Toutes filières',
        _ => c,
      };

  /// Trie une liste de filieres dans l'ordre canonique.
  static List<String> trierFilieres(Iterable<String> f) =>
      filieres.where(f.contains).toList();

  /// Le back suit la volaille par lots, le reste animal par animal.
  static bool suiviParLot(String filiere) => filiere == 'VOLAILLE';

  /// Libelle du compteur de tetes de l'accueil : « Têtes de volaille »,
  /// « Têtes de bovins », « Têtes d'ovins », « Têtes de caprins ».
  static String tetesDe(String? c) => switch (c) {
        'VOLAILLE' => 'Têtes de volaille',
        'BOVINS' => 'Têtes de bovins',
        'OVINS' => 'Têtes d’ovins',
        'CAPRINS' => 'Têtes de caprins',
        _ => 'Têtes en élevage',
      };

  /// Initiale de la pastille de filiere dans les listes (« V », « B »...).
  static String initialeFiliere(String c) {
    final l = filiere(c);
    return l.isEmpty ? '?' : l.substring(0, 1);
  }

  // ── cheptel ─────────────────────────────────────────────────────────────

  static String statutUnite(String c) => switch (c) {
        'ACTIF' => 'Actif',
        'CLOTURE' => 'Clôturé',
        'VENDU' => 'Vendu',
        'MORT' => 'Mort',
        'TRANSFERE' => 'Transféré',
        _ => c,
      };

  static TonPastille tonStatutUnite(String c) => switch (c) {
        'ACTIF' => TonPastille.marque,
        'MORT' => TonPastille.erreur,
        _ => TonPastille.neutre,
      };

  static String sexe(String? c) => switch (c) {
        'MALE' => 'Mâle',
        'FEMELLE' => 'Femelle',
        _ => 'Non renseigné',
      };

  static String typeMouvement(String c) => switch (c) {
        'MISE_EN_PLACE' => 'Mise en place',
        'ACQUISITION' => 'Acquisition',
        'NAISSANCE' => 'Naissance',
        'VENTE' => 'Vente',
        'MORT' => 'Mort',
        'TRANSFERT' => 'Transfert',
        _ => c,
      };

  /// Les trois sorties possibles, et ce que chacune fait de l'effectif.
  static const List<(String, String, String)> sorties = [
    ('VENTE', 'Vente', "déduit l'effectif vendu"),
    ('MORT', 'Mort', "déduit l'effectif perdu"),
    ('TRANSFERT', 'Transfert', "déduit l'effectif cédé"),
  ];

  // ── sante ───────────────────────────────────────────────────────────────

  static const List<String> typesEvenement = [
    'VACCINATION', 'TRAITEMENT', 'MALADIE', 'CONSULTATION',
  ];

  static String typeEvenement(String c) => switch (c) {
        'VACCINATION' => 'Vaccination',
        'TRAITEMENT' => 'Traitement',
        'MALADIE' => 'Maladie',
        'CONSULTATION' => 'Consultation',
        _ => c,
      };

  /// « Élevé », pour une pastille de catalogue.
  static String gravite(String? c) => switch (c) {
        'FAIBLE' => 'Faible',
        'MOYEN' => 'Moyen',
        'ELEVE' => 'Élevé',
        _ => c ?? '—',
      };

  /// « Gravité élevée », pour une phrase.
  static String graviteLongue(String? c) => switch (c) {
        'FAIBLE' => 'Gravité faible',
        'MOYEN' => 'Gravité moyenne',
        'ELEVE' => 'Gravité élevée',
        _ => 'Gravité inconnue',
      };

  static TonPastille tonGravite(String? c) => switch (c) {
        'ELEVE' => TonPastille.erreur,
        'MOYEN' => TonPastille.attention,
        _ => TonPastille.marque,
      };

  static const List<(String, String)> tranches = [
    ('MOINS_DE_10', 'Moins de 10'),
    ('DE_10_A_50', '10 à 50'),
    ('PLUS_DE_50', 'Plus de 50'),
  ];

  static String tranche(String c) =>
      tranches.firstWhere((t) => t.$1 == c, orElse: () => (c, c)).$2;

  // ── finances ────────────────────────────────────────────────────────────

  /// Categories par type. Le back refuse (422) une categorie de revenu sur
  /// une depense et inversement : on ne propose que les bonnes.
  static const Map<String, List<String>> categoriesParType = {
    'DEPENSE': ['ALIMENT', 'SOINS_VACCINATION', 'MAIN_D_OEUVRE', 'TRANSPORT', 'EQUIPEMENT'],
    'REVENU': ['VENTE_ANIMAUX', 'VENTE_PRODUITS'],
  };

  static String categorieOperation(String c) => switch (c) {
        'ALIMENT' => 'Aliment',
        'SOINS_VACCINATION' => 'Soins et vaccination',
        'MAIN_D_OEUVRE' => "Main-d'œuvre",
        'TRANSPORT' => 'Transport',
        'EQUIPEMENT' => 'Équipement',
        'VENTE_ANIMAUX' => "Vente d'animaux",
        'VENTE_PRODUITS' => 'Vente de produits',
        _ => c,
      };

  // ── investissement ──────────────────────────────────────────────────────

  static String difficulte(String c) => switch (c) {
        'ACCESSIBLE' => 'Accessible',
        'MOYEN' => 'Moyen',
        'EXIGEANT' => 'Exigeant',
        _ => c,
      };

  static TonPastille tonDifficulte(String c) => switch (c) {
        'ACCESSIBLE' => TonPastille.marque,
        'MOYEN' => TonPastille.attention,
        _ => TonPastille.erreur,
      };

  // ── conseils, notifications ─────────────────────────────────────────────

  static String categorieConseil(String c) => switch (c) {
        'SANTE' => 'Santé',
        'PRODUCTION' => 'Production',
        'HYGIENE' => 'Hygiène',
        _ => c,
      };

  static const List<String> categoriesConseil = ['SANTE', 'PRODUCTION', 'HYGIENE'];

  static String statutConseil(String? c) => switch (c) {
        'BROUILLON' => 'Brouillon',
        'EN_MODERATION' => 'En modération',
        'PUBLIE' => 'Publié',
        'RETIRE' => 'Retiré',
        _ => c ?? '—',
      };

  static TonPastille tonStatutConseil(String? c) => switch (c) {
        'PUBLIE' => TonPastille.marque,
        'EN_MODERATION' => TonPastille.attention,
        'RETIRE' => TonPastille.erreur,
        _ => TonPastille.neutre,
      };

  static String statutSignalement(String c) => switch (c) {
        'NOUVEAU' => 'Nouveau',
        'ORIENTE' => 'En attente de réponse',
        'EN_COURS' => 'Pris en charge',
        'TRAITE' => 'Traité',
        _ => c,
      };

  static String role(String c) => switch (c) {
        'ELEVEUR' => 'Éleveur',
        'VETERINAIRE' => 'Vétérinaire',
        'ADMINISTRATEUR' => 'Administrateur',
        _ => c,
      };
}
