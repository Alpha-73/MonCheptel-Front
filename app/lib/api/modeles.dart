/// Les reponses du back, traduites en objets Dart.
///
/// Un modele par record Java de `dto/reponse`, MEMES NOMS DE CHAMPS : on
/// passe de l'un a l'autre sans table de correspondance. Seuls les champs
/// dont l'application se sert (espaces eleveur et
/// veterinaire) sont repris.
///
/// Le back omet les champs nuls du JSON (`default-property-inclusion:
/// non_null`) : tout champ facultatif est donc lu comme nullable.
///
/// Les enumerations restent des chaines (`'VOLAILLE'`, `'ACTIF'`) : ce sont
/// les valeurs exactes que le back envoie et attend. Leurs libelles
/// francais sont dans `libelles.dart`.
library;

// ── lecture tolerante ─────────────────────────────────────────────────────

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
int? _intN(Object? v) => (v as num?)?.toInt();
double? _decN(Object? v) => (v as num?)?.toDouble();
String _txt(Object? v) => (v as String?) ?? '';
bool _bool(Object? v) => (v as bool?) ?? false;

/// `LocalDate` « 2026-09-03 » : date sans heure, lue en heure locale.
DateTime? _jour(Object? v) => v == null ? null : DateTime.parse(v as String);

/// `Instant` « 2026-09-28T14:30:00Z » : instant UTC, ramene a l'heure locale.
DateTime? _instant(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

List<T> _liste<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const [])
        .map((e) => f(e as Map<String, dynamic>))
        .toList();

List<String> _chaines(Object? v) =>
    ((v as List?) ?? const []).map((e) => e as String).toList();

/// « 2026-09-03 », le format `LocalDate` qu'attend le back.
String versJour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── referentiel ───────────────────────────────────────────────────────────

class ZoneGeo {
  ZoneGeo.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        nom = _txt(j['nom']),
        region = j['region'] as String?;
  final int id;
  final String nom;
  final String? region;
}

class PosteCout {
  PosteCout.json(Map<String, dynamic> j)
      : libelle = _txt(j['libelle']),
        montant = _int(j['montant']),
        unite = j['unite'] as String?,
        phase = _txt(j['phase']);
  final String libelle;
  final int montant;
  final String? unite;

  /// `INSTALLATION` ou `CYCLE`.
  final String phase;
}

class TypeElevage {
  TypeElevage.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        filiere = _txt(j['filiere']),
        libelle = _txt(j['libelle']),
        modeEvaluation = _txt(j['modeEvaluation']),
        dureeCycleJours = _intN(j['dureeCycleJours']),
        capaciteReference = _int(j['capaciteReference']),
        espaceParSujetM2 = _decN(j['espaceParSujetM2']),
        temperatureMin = _intN(j['temperatureMin']),
        temperatureMax = _intN(j['temperatureMax']),
        alimentParSujetKg = _decN(j['alimentParSujetKg']),
        eauParSujetJourL = _decN(j['eauParSujetJourL']),
        vaccinsObligatoires = j['vaccinsObligatoires'] as String?,
        tauxMortalite = _decN(j['tauxMortalite']),
        difficulte = _txt(j['difficulte']),
        postesCout = _liste(j['postesCout'], PosteCout.json);
  final int id;
  final String filiere;
  final String libelle;

  /// `PAR_PERIODE` : jugé sur son cycle, le type porte `dureeCycleJours`
  /// (poulet de chair, 45 jours). `PAR_ENTREE` : sans cycle, de l'entrée à
  /// la sortie (chèvre). Voir ModeEvaluation côté back.
  final String modeEvaluation;
  final int? dureeCycleJours;
  final int capaciteReference;
  final double? espaceParSujetM2;
  final int? temperatureMin;
  final int? temperatureMax;
  final double? alimentParSujetKg;
  final double? eauParSujetJourL;
  final String? vaccinsObligatoires;
  final double? tauxMortalite;
  final String difficulte;
  final List<PosteCout> postesCout;
}

class Symptome {
  Symptome.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        libelle = _txt(j['libelle']);
  final int id;
  final String libelle;
}

class Maladie {
  Maladie.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        nom = _txt(j['nom']),
        gravite = _txt(j['gravite']),
        filieres = _chaines(j['filieres']),
        symptomesTexte = j['symptomesTexte'] as String?,
        traitement = j['traitement'] as String?,
        orienteVersVeterinaire = _bool(j['orienteVersVeterinaire']);
  final int id;
  final String nom;
  final String gravite;
  final List<String> filieres;
  final String? symptomesTexte;

  /// Masque par le back pour l'eleveur quand la maladie oriente vers un
  /// veterinaire : un traitement « maison » serait dangereux.
  final String? traitement;
  final bool orienteVersVeterinaire;
}

// ── personnes ─────────────────────────────────────────────────────────────

class VeterinaireResume {
  VeterinaireResume.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        nom = _txt(j['nom']),
        titre = j['titre'] as String?,
        specialite = j['specialite'] as String?,
        zoneIntervention = j['zoneIntervention'] as String?,
        telephone = j['telephone'] as String?,
        disponible = _bool(j['disponible']);
  final int id;
  final String nom;
  final String? titre;
  final String? specialite;
  final String? zoneIntervention;
  final String? telephone;
  final bool disponible;
}

class Profil {
  Profil.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        nom = _txt(j['nom']),
        telephone = j['telephone'] as String?,
        email = _txt(j['email']),
        role = _txt(j['role']),
        zone = j['zone'] == null ? null : ZoneGeo.json(j['zone'] as Map<String, dynamic>),
        langue = (j['langue'] as String?) ?? 'FR',
        dateInscription = _jour(j['dateInscription']),
        filieresPratiquees = _chaines(j['filieresPratiquees']),
        titre = j['titre'] as String?,
        specialite = j['specialite'] as String?,
        zoneIntervention = j['zoneIntervention'] == null
            ? null
            : ZoneGeo.json(j['zoneIntervention'] as Map<String, dynamic>),
        disponible = j['disponible'] as bool?;
  final int id;
  final String nom;
  final String? telephone;
  final String email;
  final String role;
  final ZoneGeo? zone;
  final String langue;
  final DateTime? dateInscription;

  /// Renseignees pour un eleveur, vides sinon.
  final List<String> filieresPratiquees;

  // Les quatre suivants ne sont renseignes que pour un VETERINAIRE.

  /// « Dr ».
  final String? titre;
  final String? specialite;
  final ZoneGeo? zoneIntervention;
  final bool? disponible;

  /// « Dr Aissata Traore » : le titre devant le nom, sans le doubler si
  /// l'administration l'a deja saisi dans le nom.
  String get nomAffiche {
    final t = titre?.trim();
    if (t == null || t.isEmpty || nom.startsWith('$t ')) return nom;
    return '$t $nom';
  }
}

// ── cheptel ───────────────────────────────────────────────────────────────

/// Un lot OU un animal : le back les rend sous une seule forme.
class Unite {
  Unite.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        code = _txt(j['code']),
        modeSuivi = _txt(j['modeSuivi']),
        filiere = _txt(j['filiere']),
        typeElevage = _txt(j['typeElevage']),
        statut = _txt(j['statut']),
        dateEntree = _jour(j['dateEntree']),
        effectifInitial = _int(j['effectifInitial']),
        effectifRestant = _int(j['effectifRestant']),
        dateCloturePrevue = _jour(j['dateCloturePrevue']),
        joursRestants = _intN(j['joursRestants']),
        typeElevageId = _intN(j['typeElevageId']),
        race = j['race'] as String?,
        sexe = j['sexe'] as String?,
        dateNaissance = _jour(j['dateNaissance']),
        note = j['note'] as String?;
  final int id;
  final String code;

  /// `LOT` ou `INDIVIDUEL`.
  final String modeSuivi;
  final String filiere;
  final String typeElevage;
  final String statut;
  final DateTime? dateEntree;
  final int effectifInitial;
  final int effectifRestant;
  final DateTime? dateCloturePrevue;
  final int? joursRestants;
  final int? typeElevageId;
  final String? race;
  final String? sexe;
  final DateTime? dateNaissance;
  final String? note;

  bool get estLot => modeSuivi == 'LOT';
  bool get estActif => statut == 'ACTIF';
}

class Mouvement {
  Mouvement.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        type = _txt(j['type']),
        nombreTetes = _int(j['nombreTetes']),
        dateMouvement = _jour(j['dateMouvement']),
        motif = j['motif'] as String?;
  final int id;
  final String type;
  final int nombreTetes;
  final DateTime? dateMouvement;
  final String? motif;

  bool get estEntree =>
      type == 'MISE_EN_PLACE' || type == 'ACQUISITION' || type == 'NAISSANCE';
}

class Evenement {
  Evenement.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        type = _txt(j['type']),
        dateEvenement = _jour(j['dateEvenement']),
        produitObservation = j['produitObservation'] as String?,
        auteur = j['auteur'] as String?,
        veterinaire = j['veterinaire'] as String?;
  final int id;
  final String type;
  final DateTime? dateEvenement;
  final String? produitObservation;
  final String? auteur;
  final String? veterinaire;
}

class Rappel {
  Rappel.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        uniteId = _intN(j['uniteId']),
        uniteCode = j['uniteCode'] as String?,
        libelle = _txt(j['libelle']),
        dateEcheance = _jour(j['dateEcheance']),
        joursRestants = _int(j['joursRestants']),
        statut = _txt(j['statut']);
  final int id;
  final int? uniteId;
  final String? uniteCode;
  final String libelle;
  final DateTime? dateEcheance;
  final int joursRestants;
  final String statut;
}

class Solde {
  Solde.json(Map<String, dynamic> j)
      : revenus = _int(j['revenus']),
        depenses = _int(j['depenses']),
        solde = _int(j['solde']);
  const Solde.vide()
      : revenus = 0,
        depenses = 0,
        solde = 0;
  final int revenus;
  final int depenses;
  final int solde;
}

class DetailUnite {
  DetailUnite.json(Map<String, dynamic> j)
      : unite = Unite.json(j['unite'] as Map<String, dynamic>),
        mouvements = _liste(j['mouvements'], Mouvement.json),
        evenements = _liste(j['evenements'], Evenement.json),
        rappels = _liste(j['rappels'], Rappel.json),
        rentabilite = j['rentabilite'] == null
            ? const Solde.vide()
            : Solde.json(j['rentabilite'] as Map<String, dynamic>);
  final Unite unite;
  final List<Mouvement> mouvements;
  final List<Evenement> evenements;
  final List<Rappel> rappels;
  final Solde rentabilite;
}

// ── tableau de bord, alertes, notifications ───────────────────────────────

class Alerte {
  Alerte.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        maladie = _txt(j['maladie']),
        zone = _txt(j['zone']),
        filiere = j['filiere'] as String?,
        message = _txt(j['message']),
        portee = _int(j['portee']),
        dateDeclenchement = _instant(j['dateDeclenchement']),
        statut = _txt(j['statut']),
        // ajout éleveur B : fin prevue de l'alerte.
        dateFin = _jour(j['dateFin']);
  final int id;
  final String maladie;
  final String zone;

  /// Nulle : l'alerte vise toutes les filieres.
  final String? filiere;
  final String message;

  /// Nombre d'eleveurs prevenus.
  final int portee;
  final DateTime? dateDeclenchement;
  final String statut;

  /// Fin prevue de l'alerte ; nulle si elle court jusqu'a sa cloture
  /// (ajout eleveur B).
  final DateTime? dateFin;
}

class TableauDeBord {
  TableauDeBord.json(Map<String, dynamic> j)
      : nomEleveur = _txt(j['nomEleveur']),
        zone = j['zone'] as String?,
        filieres = _chaines(j['filieres']),
        filiereAffichee = j['filiereAffichee'] as String?,
        unitesActives = _int(j['unitesActives']),
        tetesRestantes = _int(j['tetesRestantes']),
        unitesCloturees = _int(j['unitesCloturees']),
        tetesSorties = _int(j['tetesSorties']),
        soldeDuMois = j['soldeDuMois'] == null
            ? const Solde.vide()
            : Solde.json(j['soldeDuMois'] as Map<String, dynamic>),
        moisCourant = j['moisCourant'] as String?,
        alertes = _liste(j['alertes'], Alerte.json),
        rappels = _liste(j['rappels'], Rappel.json),
        notificationsNonLues = _int(j['notificationsNonLues']);
  final String nomEleveur;
  final String? zone;
  final List<String> filieres;
  final String? filiereAffichee;
  final int unitesActives;
  final int tetesRestantes;
  final int unitesCloturees;
  final int tetesSorties;
  final Solde soldeDuMois;
  final String? moisCourant;
  final List<Alerte> alertes;
  final List<Rappel> rappels;
  final int notificationsNonLues;
}

class NotificationApp {
  NotificationApp.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        type = _txt(j['type']),
        titre = _txt(j['titre']),
        corps = j['corps'] as String?,
        lue = _bool(j['lue']),
        dateCreation = _instant(j['dateCreation']),
        // ajout vétérinaire : ce que la notification ouvre au toucher.
        referenceType = j['referenceType'] as String?,
        referenceId = _intN(j['referenceId']);
  final int id;
  final String type;
  final String titre;
  final String? corps;
  final bool lue;
  final DateTime? dateCreation;

  /// `SIGNALEMENT`, `ALERTE`, `CONSEIL`… et l'identifiant visé (ajout
  /// veterinaire).
  final String? referenceType;
  final int? referenceId;
}

/// `PageReponse<T>` du back.
class PageApi<T> {
  PageApi.json(Map<String, dynamic> j, T Function(Map<String, dynamic>) f)
      : elements = _liste(j['elements'], f),
        page = _int(j['page']),
        total = _int(j['total']),
        derniere = (j['derniere'] as bool?) ?? true;
  final List<T> elements;
  final int page;
  final int total;
  final bool derniere;
}

// ── sante ─────────────────────────────────────────────────────────────────

class Diagnostic {
  Diagnostic.json(Map<String, dynamic> j)
      : probable = j['probable'] == null
            ? null
            : Maladie.json(j['probable'] as Map<String, dynamic>),
        alternative = j['alternative'] == null
            ? null
            : Maladie.json(j['alternative'] as Map<String, dynamic>),
        gravite = j['gravite'] as String?,
        orientationRequise = _bool(j['orientationRequise']),
        veterinaire = j['veterinaire'] == null
            ? null
            : VeterinaireResume.json(j['veterinaire'] as Map<String, dynamic>);

  /// Nulle : les symptomes ne designent aucune maladie du catalogue.
  final Maladie? probable;
  final Maladie? alternative;
  final String? gravite;
  final bool orientationRequise;

  /// Nul : aucun veterinaire competent et disponible dans la zone.
  final VeterinaireResume? veterinaire;
}

/// `SignalementReponse` : vu par l'eleveur qui le cree, et par le
/// veterinaire a qui il est oriente.
///
/// Le telephone et la zone de l'eleveur ne sont rendus qu'au veterinaire en
/// charge ; l'eleveur, lui, les recoit nuls.
class Signalement {
  Signalement.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        uniteId = _intN(j['uniteId']),
        uniteCode = j['uniteCode'] as String?,
        eleveurNom = j['eleveurNom'] as String?,
        eleveurTelephone = j['eleveurTelephone'] as String?,
        eleveurZone = j['eleveurZone'] as String?,
        symptomes = _liste(j['symptomes'], Symptome.json),
        trancheEffectif = _txt(j['trancheEffectif']),
        precision = j['precision'] as String?,
        dateSignalement = _instant(j['dateSignalement']),
        diagnostic = j['diagnostic'] == null
            ? null
            : Diagnostic.json(j['diagnostic'] as Map<String, dynamic>),
        statut = _txt(j['statut']),
        dateTraitement = _instant(j['dateTraitement']),
        compteRendu = j['compteRendu'] as String?,
        uniteType = j['uniteType'] as String?,
        uniteEffectif = _intN(j['uniteEffectif']),
        // ajout vétérinaire : diagnostic retenu à la clôture (nom).
        maladieConfirmee = j['maladieConfirmee'] as String?,
        // ajout audit global (G6) : filiere de l'unite, pour filtrer le
        // catalogue de cloture.
        uniteFiliere = j['uniteFiliere'] as String?,
        // V14 : veterinaires qui ont refuse ce cas (detail seulement).
        refus = _liste(j['refus'], RefusCas.json);
  final int id;
  final int? uniteId;

  /// `VOLAILLE`, `BOVINS`... : filiere de l'unite signalee (ajout audit
  /// global G6). Nulle sur une reponse ancienne.
  final String? uniteFiliere;
  final String? uniteCode;
  final String? eleveurNom;
  final String? eleveurTelephone;
  final String? eleveurZone;
  final List<Symptome> symptomes;

  /// `MOINS_DE_10`, `DE_10_A_50` ou `PLUS_DE_50` : l'eleveur declare une
  /// tranche, pas un nombre exact de sujets touches.
  final String trancheEffectif;

  /// Ce que l'eleveur a ajoute en texte libre.
  final String? precision;
  final DateTime? dateSignalement;
  final Diagnostic? diagnostic;

  /// `NOUVEAU`, `ORIENTE`, `EN_COURS` ou `TRAITE`.
  final String statut;
  final DateTime? dateTraitement;
  final String? compteRendu;

  /// Libelle du type d'elevage (« Poulets de chair »).
  final String? uniteType;

  /// Tetes vivantes de l'unite, au moment de la lecture.
  final int? uniteEffectif;

  /// Maladie retenue par le veterinaire a la cloture, nulle s'il n'en a
  /// pas pose (ajout veterinaire).
  final String? maladieConfirmee;

  /// Les veterinaires qui ont refuse ce cas, du plus recent au plus ancien
  /// (V14). Vide dans les listes : seul le detail le porte.
  final List<RefusCas> refus;

  /// Gravite retenue : croisement de la maladie et de l'ampleur declaree.
  String? get gravite => diagnostic?.gravite;

  /// Nom de la maladie probable, nul si les symptomes n'en designent aucune.
  String? get maladie => diagnostic?.probable?.nom;

  bool get enAttente => statut == 'ORIENTE' || statut == 'EN_COURS';
  bool get traite => statut == 'TRAITE';
}

/// Un refus de cas par un veterinaire (V14) : qui, pourquoi, quand.
class RefusCas {
  RefusCas.json(Map<String, dynamic> j)
      : veterinaireNom = _txt(j['veterinaireNom']),
        motif = j['motif'] as String?,
        dateRefus = _instant(j['dateRefus']);
  final String veterinaireNom;
  final String? motif;
  final DateTime? dateRefus;
}

// ── conseils ──────────────────────────────────────────────────────────────

class ConseilResume {
  ConseilResume.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        titre = _txt(j['titre']),
        extrait = j['extrait'] as String?,
        filiere = _txt(j['filiere']),
        categorie = _txt(j['categorie']),
        auteur = j['auteur'] as String?,
        datePublication = _instant(j['datePublication']);
  final int id;
  final String titre;
  final String? extrait;
  final String filiere;
  final String categorie;
  final String? auteur;
  final DateTime? datePublication;
}

class ConseilDetail {
  ConseilDetail.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        titre = _txt(j['titre']),
        contenu = _txt(j['contenu']),
        filiere = _txt(j['filiere']),
        categorie = _txt(j['categorie']),
        auteur = j['auteur'] == null
            ? null
            : VeterinaireResume.json(j['auteur'] as Map<String, dynamic>),
        datePublication = _instant(j['datePublication']),
        nombreLectures = _int(j['nombreLectures']),
        statut = j['statut'] as String?,
        motifRetrait = j['motifRetrait'] as String?,
        dateCreation = _instant(j['dateCreation']),
        dateSoumission = _instant(j['dateSoumission']);
  final int id;
  final String titre;
  final String contenu;
  final String filiere;
  final String categorie;

  /// Absent pour un conseil publie directement par l'administration.
  final VeterinaireResume? auteur;
  final DateTime? datePublication;
  final int nombreLectures;

  /// `BROUILLON`, `EN_MODERATION`, `PUBLIE` ou `RETIRE`. Rendu a l'auteur et
  /// a l'administration seulement : nul pour un eleveur.
  final String? statut;
  final String? motifRetrait;
  final DateTime? dateCreation;
  final DateTime? dateSoumission;

  /// La date qui compte pour l'auteur : publication, sinon envoi en
  /// moderation, sinon creation.
  DateTime? get dateReference => datePublication ?? dateSoumission ?? dateCreation;
}

// ── espace veterinaire ────────────────────────────────────────────────────

/// GET /api/veterinaires/accueil : les compteurs de l'ecran d'accueil.
class AccueilVeterinaire {
  AccueilVeterinaire.json(Map<String, dynamic> j)
      : enAttente = _int(j['enAttente']),
        enAttenteGraves = _int(j['enAttenteGraves']),
        traitesCeMois = _int(j['traitesCeMois']),
        conseilsPublies = _int(j['conseilsPublies']),
        conseilsEnModeration = _int(j['conseilsEnModeration']);

  /// Signalements orientes ou pris en charge, pas encore traites.
  final int enAttente;

  /// Parmi eux, ceux de gravite elevee.
  final int enAttenteGraves;
  final int traitesCeMois;
  final int conseilsPublies;
  final int conseilsEnModeration;
}

// ── finances ──────────────────────────────────────────────────────────────

class Operation {
  Operation.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        type = _txt(j['type']),
        categorie = _txt(j['categorie']),
        montant = _int(j['montant']),
        montantSigne = _int(j['montantSigne']),
        dateOperation = _jour(j['dateOperation']),
        filiere = _txt(j['filiere']),
        uniteId = _intN(j['uniteId']),
        uniteCode = j['uniteCode'] as String?,
        libelle = j['libelle'] as String?,
        issueDUnMouvement = _bool(j['issueDUnMouvement']);
  final int id;

  /// `DEPENSE` ou `REVENU`.
  final String type;
  final String categorie;
  final int montant;

  /// Negatif pour une depense : pret a additionner.
  final int montantSigne;
  final DateTime? dateOperation;
  final String filiere;
  final int? uniteId;
  final String? uniteCode;
  final String? libelle;

  /// Creee par une vente enregistree comme sortie : elle se corrige depuis
  /// la sortie, pas ici.
  final bool issueDUnMouvement;
}

class LigneRepartition {
  LigneRepartition.json(Map<String, dynamic> j)
      : categorie = _txt(j['categorie']),
        montant = _int(j['montant']),
        pourcentage = _decN(j['pourcentage']) ?? 0;
  final String categorie;
  final int montant;
  final double pourcentage;
}

class PointMensuel {
  PointMensuel.json(Map<String, dynamic> j)
      : mois = _txt(j['mois']),
        revenus = _int(j['revenus']),
        depenses = _int(j['depenses']),
        solde = _int(j['solde']);

  /// « 2026-09 ».
  final String mois;
  final int revenus;
  final int depenses;
  final int solde;
}

class Rapport {
  Rapport.json(Map<String, dynamic> j)
      : debut = _jour(j['debut']),
        fin = _jour(j['fin']),
        total = j['total'] == null
            ? const Solde.vide()
            : Solde.json(j['total'] as Map<String, dynamic>),
        repartitionDepenses = _liste(j['repartitionDepenses'], LigneRepartition.json),
        evolution = _liste(j['evolution'], PointMensuel.json);
  final DateTime? debut;
  final DateTime? fin;
  final Solde total;
  final List<LigneRepartition> repartitionDepenses;
  final List<PointMensuel> evolution;
}

// ── investissement ────────────────────────────────────────────────────────

class OptionInvestissement {
  OptionInvestissement.json(Map<String, dynamic> j)
      : typeElevageId = _int(j['typeElevageId']),
        libelle = _txt(j['libelle']),
        filiere = _txt(j['filiere']),
        difficulte = _txt(j['difficulte']),
        dureeCycleJours = _intN(j['dureeCycleJours']),
        sujetsVises = _int(j['sujetsVises']),
        sujetsAAcheter = _int(j['sujetsAAcheter']),
        coutInstallation = _int(j['coutInstallation']),
        coutCycle = _int(j['coutCycle']),
        coutTotal = _int(j['coutTotal']),
        ecartBudget = _int(j['ecartBudget']),
        realisable = _bool(j['realisable']);
  final int typeElevageId;
  final String libelle;
  final String filiere;
  final String difficulte;
  final int? dureeCycleJours;
  final int sujetsVises;
  final int sujetsAAcheter;
  final int coutInstallation;
  final int coutCycle;
  final int coutTotal;

  /// Budget moins cout total : positif = il reste, negatif = il manque.
  final int ecartBudget;
  final bool realisable;
}

class SimulationInvestissement {
  SimulationInvestissement.json(Map<String, dynamic> j)
      : budget = _int(j['budget']),
        installationIncluse = _bool(j['installationIncluse']),
        options = _liste(j['options'], OptionInvestissement.json);
  final int budget;
  final bool installationIncluse;
  final List<OptionInvestissement> options;
}

class LignePoste {
  LignePoste.json(Map<String, dynamic> j)
      : libelle = _txt(j['libelle']),
        phase = _txt(j['phase']),
        quantite = _decN(j['quantite']) ?? 0,
        unite = j['unite'] as String?,
        montantUnitaire = _int(j['montantUnitaire']),
        montant = _int(j['montant']);
  final String libelle;
  final String phase;
  final double quantite;
  final String? unite;
  final int montantUnitaire;
  final int montant;
}

class DetailSimulation {
  DetailSimulation.json(Map<String, dynamic> j)
      : option = OptionInvestissement.json(j['option'] as Map<String, dynamic>),
        postesInstallation = _liste(j['postesInstallation'], LignePoste.json),
        postesCycle = _liste(j['postesCycle'], LignePoste.json);
  final OptionInvestissement option;
  final List<LignePoste> postesInstallation;
  final List<LignePoste> postesCycle;
}

// ── ajouts éleveur A (animaux, carnet) ───────────────────────────────────

/// Une sortie annulable du carnet (`sorties[]` du détail d'unité) : vente,
/// mort ou transfert. [id] est celui qu'attend
/// `DELETE /api/cheptel/{uniteId}/sorties/{sortieId}`.
class SortieUnite {
  SortieUnite.json(Map<String, dynamic> j)
      : id = _int(j['id']),
        date = _jour(j['date']),
        nature = _txt(j['nature'] ?? j['type']),
        nombre = _int(j['nombre'] ?? j['nombreTetes']),
        montant = _intN(j['montant']);
  final int id;
  final DateTime? date;
  final String nature;
  final int nombre;
  final int? montant;

  /// Les sorties du détail d'unité ; liste vide si le back ne les rend pas.
  static List<SortieUnite> depuisDetail(Map<String, dynamic> j) =>
      _liste(j['sorties'], SortieUnite.json);
}

// ── ajouts éleveur B (santé, notifications, argent) ──────────────────────

/// Un signalement relu par l'eleveur (« Mes signalements »), avec le
/// veterinaire a qui il a ete confie.
///
/// Le veterinaire est cherche, dans l'ordre : un objet `veterinaire` a la
/// racine, puis `veterinaireNom` / `veterinaireTelephone`, puis
/// `diagnostic.veterinaire` (seul endroit ou le back le mettait avant la
/// route `GET /api/signalements/mes`, et nul sans maladie probable).
class SuiviSignalement {
  SuiviSignalement.json(Map<String, dynamic> j)
      : signalement = Signalement.json(j),
        veterinaire = _veterinaireDe(j);

  final Signalement signalement;
  final VeterinaireResume? veterinaire;

  static VeterinaireResume? _veterinaireDe(Map<String, dynamic> j) {
    final racine = j['veterinaire'];
    if (racine is Map<String, dynamic>) return VeterinaireResume.json(racine);
    final nom = j['veterinaireNom'];
    if (nom is String && nom.trim().isNotEmpty) {
      return VeterinaireResume.json({
        'id': j['veterinaireId'] ?? 0,
        'nom': nom,
        'telephone': j['veterinaireTelephone'],
        'disponible': true,
      });
    }
    return Signalement.json(j).diagnostic?.veterinaire;
  }
}
