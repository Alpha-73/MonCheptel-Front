/// Une fonction par route du back utilisee par l'application (espaces
/// eleveur et veterinaire).
///
/// Chaque fonction porte en commentaire la route qu'elle appelle : c'est le
/// fil a tirer pour retrouver le controleur Java correspondant.
///
/// Rien ici ne decide d'un ecran : ces fonctions envoient, recoivent et
/// traduisent. Les erreurs remontent en [ApiException].
library;

import 'client_api.dart';
import 'modeles.dart';

ClientApi get _api => ClientApi.instance;

List<Map<String, dynamic>> _objets(Object? json) =>
    ((json as List?) ?? const []).cast<Map<String, dynamic>>();

// ── authentification ──────────────────────────────────────────────────────

abstract final class AuthApi {
  /// POST /api/auth/connexion
  static Future<Session> connexion(String email, String motDePasse) async {
    final j = await _api.post('/api/auth/connexion',
        corps: {'email': email.trim(), 'motDePasse': motDePasse},
        authentifie: false);
    return _api.ouvrirSession(j as Map<String, dynamic>);
  }

  /// POST /api/auth/inscription
  static Future<Session> inscription({
    required String nom,
    required String email,
    String? telephone,
    required int zoneId,
    required Set<String> filieres,
    required String motDePasse,
  }) async {
    final j = await _api.post('/api/auth/inscription',
        corps: {
          'nom': nom.trim(),
          'email': email.trim(),
          if (telephone != null && telephone.trim().isNotEmpty)
            'telephone': telephone.trim(),
          'zoneId': zoneId,
          'filieres': filieres.toList(),
          'motDePasse': motDePasse,
        },
        authentifie: false);
    return _api.ouvrirSession(j as Map<String, dynamic>);
  }

  /// POST /api/auth/mot-de-passe/oublie — toujours 202, compte existant ou
  /// non : le back ne dit jamais si une adresse est inscrite.
  static Future<void> demanderCode(String email) =>
      _api.post('/api/auth/mot-de-passe/oublie',
          corps: {'email': email.trim()}, authentifie: false);

  /// POST /api/auth/mot-de-passe/reinitialiser
  ///
  /// Le back verifie le code ET change le mot de passe en un seul appel :
  /// il n'existe pas de route « verifier le code seul ». Un mauvais code
  /// n'est donc detecte qu'a cette etape.
  static Future<void> reinitialiser(
          String email, String code, String nouveauMotDePasse) =>
      _api.post('/api/auth/mot-de-passe/reinitialiser',
          corps: {
            'email': email.trim(),
            'code': code.replaceAll(' ', ''),
            'nouveauMotDePasse': nouveauMotDePasse,
          },
          authentifie: false);

  /// GET /api/auth/moi
  static Future<Profil> moi() async =>
      Profil.json(await _api.get('/api/auth/moi') as Map<String, dynamic>);

  /// PUT /api/auth/moi
  static Future<Profil> modifierProfil({
    required String nom,
    required String email,
    String? telephone,
    required int zoneId,
    required String langue,
    required Set<String> filieres,
    // Exige par le back seulement si l'adresse change (audit du 10 octobre).
    String? motDePasseActuel,
  }) async =>
      Profil.json(await _api.put('/api/auth/moi', corps: {
        'nom': nom.trim(),
        'email': email.trim(),
        'telephone': (telephone == null || telephone.trim().isEmpty)
            ? null
            : telephone.trim(),
        'zoneId': zoneId,
        'langue': langue,
        'filieres': filieres.toList(),
        if (motDePasseActuel != null) 'motDePasseActuel': motDePasseActuel,
      }) as Map<String, dynamic>);

  /// POST /api/auth/mot-de-passe — invalide TOUTES les sessions, y compris
  /// celle-ci : il faut se reconnecter ensuite.
  static Future<void> changerMotDePasse(String ancien, String nouveau) =>
      _api.post('/api/auth/mot-de-passe',
          corps: {'ancienMotDePasse': ancien, 'nouveauMotDePasse': nouveau});
}

// ── referentiel ───────────────────────────────────────────────────────────

abstract final class ReferentielApi {
  /// GET /api/zones (publique : sert a l'inscription)
  static Future<List<ZoneGeo>> zones() async =>
      _objets(await _api.get('/api/zones')).map(ZoneGeo.json).toList();

  /// GET /api/types-elevage — types ACTIFS seulement.
  static Future<List<TypeElevage>> typesElevage({String? filiere}) async =>
      _objets(await _api.get('/api/types-elevage', requete: {'filiere': filiere}))
          .map(TypeElevage.json)
          .toList();

  /// GET /api/veterinaires — par defaut, la zone de l'eleveur.
  static Future<List<VeterinaireResume>> veterinaires({int? zoneId}) async =>
      _objets(await _api.get('/api/veterinaires', requete: {'zoneId': zoneId}))
          .map(VeterinaireResume.json)
          .toList();
}

// ── tableau de bord ───────────────────────────────────────────────────────

abstract final class TableauDeBordApi {
  /// GET /api/tableau-de-bord
  static Future<TableauDeBord> charger({String? filiere}) async =>
      TableauDeBord.json(await _api.get('/api/tableau-de-bord',
          requete: {'filiere': filiere}) as Map<String, dynamic>);
}

// ── cheptel ───────────────────────────────────────────────────────────────

abstract final class CheptelApi {
  /// GET /api/cheptel
  static Future<List<Unite>> lister({String? filiere, String? statut}) async =>
      _objets(await _api.get('/api/cheptel',
              requete: {'filiere': filiere, 'statut': statut}))
          .map(Unite.json)
          .toList();

  /// GET /api/cheptel/{id}
  static Future<DetailUnite> detail(int id) async =>
      DetailUnite.json(await _api.get('/api/cheptel/$id') as Map<String, dynamic>);

  /// POST /api/cheptel/lots — volaille.
  static Future<Unite> creerLot({
    String? code,
    required int typeElevageId,
    required int effectifInitial,
    required DateTime dateMiseEnPlace,
  }) async =>
      Unite.json(await _api.post('/api/cheptel/lots', corps: {
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        'typeElevageId': typeElevageId,
        'effectifInitial': effectifInitial,
        'dateMiseEnPlace': versJour(dateMiseEnPlace),
      }) as Map<String, dynamic>);

  /// POST /api/cheptel/animaux — bovins, ovins, caprins.
  static Future<Unite> creerAnimal({
    String? code,
    required int typeElevageId,
    required DateTime dateEntree,
    String? race,
    String? sexe,
    DateTime? dateNaissance,
  }) async =>
      Unite.json(await _api.post('/api/cheptel/animaux', corps: {
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        'typeElevageId': typeElevageId,
        'dateEntree': versJour(dateEntree),
        if (race != null && race.trim().isNotEmpty) 'race': race.trim(),
        if (sexe != null) 'sexe': sexe,
        if (dateNaissance != null) 'dateNaissance': versJour(dateNaissance),
      }) as Map<String, dynamic>);

  /// PUT /api/cheptel/{id}
  static Future<Unite> modifier(
    int id, {
    required String code,
    required int typeElevageId,
    required DateTime dateEntree,
    String? note,
    String? race,
    String? sexe,
    DateTime? dateNaissance,
  }) async =>
      Unite.json(await _api.put('/api/cheptel/$id', corps: {
        'code': code.trim(),
        'typeElevageId': typeElevageId,
        'dateEntree': versJour(dateEntree),
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'race': (race == null || race.trim().isEmpty) ? null : race.trim(),
        'sexe': sexe,
        'dateNaissance': dateNaissance == null ? null : versJour(dateNaissance),
      }) as Map<String, dynamic>);

  /// DELETE /api/cheptel/{id} — refuse (422) des que l'unite a une histoire.
  static Future<void> supprimer(int id) => _api.delete('/api/cheptel/$id');

  /// POST /api/cheptel/{id}/sorties — vente, mort, transfert.
  static Future<Unite> sortie(
    int id, {
    required String type,
    required int nombreTetes,
    required DateTime date,
    int? montant,
    String? motif,
  }) async =>
      Unite.json(await _api.post('/api/cheptel/$id/sorties', corps: {
        'type': type,
        'nombreTetes': nombreTetes,
        'date': versJour(date),
        // Le back EXIGE un montant pour une vente et le REFUSE sinon.
        if (type == 'VENTE') 'montant': montant,
        if (motif != null && motif.trim().isNotEmpty) 'motif': motif.trim(),
      }) as Map<String, dynamic>);
}

// ── sanitaire ─────────────────────────────────────────────────────────────

abstract final class SanitaireApi {
  /// POST /api/sanitaire/unites/{uniteId}/evenements
  static Future<Evenement> ajouterEvenement(
    int uniteId, {
    required String type,
    required DateTime date,
    String? produitObservation,
    int? rappelDansJours,
  }) async =>
      Evenement.json(await _api.post('/api/sanitaire/unites/$uniteId/evenements',
          corps: _evenement(type, date, produitObservation, rappelDansJours))
          as Map<String, dynamic>);

  /// PUT /api/sanitaire/evenements/{id}
  static Future<Evenement> modifierEvenement(
    int id, {
    required String type,
    required DateTime date,
    String? produitObservation,
  }) async =>
      Evenement.json(await _api.put('/api/sanitaire/evenements/$id',
          corps: _evenement(type, date, produitObservation, null))
          as Map<String, dynamic>);

  /// DELETE /api/sanitaire/evenements/{id}
  static Future<void> supprimerEvenement(int id) =>
      _api.delete('/api/sanitaire/evenements/$id');

  static Map<String, Object?> _evenement(
          String type, DateTime date, String? produit, int? rappel) =>
      {
        'type': type,
        'dateEvenement': versJour(date),
        if (produit != null && produit.trim().isNotEmpty)
          'produitObservation': produit.trim(),
        if (rappel != null) 'rappelDansJours': rappel,
      };

  /// GET /api/sanitaire/rappels
  static Future<List<Rappel>> rappels({int? horizonJours}) async =>
      _objets(await _api.get('/api/sanitaire/rappels',
              requete: {'horizonJours': horizonJours}))
          .map(Rappel.json)
          .toList();

  /// POST /api/sanitaire/rappels/{id}/ignorer
  static Future<void> ignorerRappel(int id) =>
      _api.post('/api/sanitaire/rappels/$id/ignorer');
}

// ── signalement ───────────────────────────────────────────────────────────

abstract final class SignalementApi {
  /// GET /api/signalements/symptomes
  static Future<List<Symptome>> symptomes(String filiere) async =>
      _objets(await _api.get('/api/signalements/symptomes',
              requete: {'filiere': filiere}))
          .map(Symptome.json)
          .toList();

  /// GET /api/signalements/symptomes sans filiere — toute la liste
  /// (formulaire « Ajouter une maladie » du veterinaire).
  static Future<List<Symptome>> tousLesSymptomes() async =>
      _objets(await _api.get('/api/signalements/symptomes')).map(Symptome.json).toList();

  /// GET /api/signalements/maladies — catalogue vu par l'eleveur.
  static Future<List<Maladie>> maladies({String? filiere}) async =>
      _objets(await _api.get('/api/signalements/maladies',
              requete: {'filiere': filiere}))
          .map(Maladie.json)
          .toList();

  /// GET /api/signalements/maladies-catalogue — toutes les maladies
  /// actives, pour que le veterinaire coche celles qu'il traite.
  static Future<List<Maladie>> catalogueComplet() async =>
      _objets(await _api.get('/api/signalements/maladies-catalogue'))
          .map(Maladie.json)
          .toList();

  /// POST /api/signalements
  static Future<Signalement> signaler({
    required int uniteId,
    required Set<int> symptomeIds,
    required String trancheEffectif,
    String? precision,
  }) async =>
      Signalement.json(await _api.post('/api/signalements', corps: {
        'uniteId': uniteId,
        'symptomeIds': symptomeIds.toList(),
        'trancheEffectif': trancheEffectif,
        if (precision != null && precision.trim().isNotEmpty)
          'precision': precision.trim(),
      }) as Map<String, dynamic>);

  /// GET /api/signalements/{id}/veterinaires — les veterinaires de la zone
  /// de l'eleveur qui traitent la maladie, dans un ordre aleatoire.
  static Future<List<VeterinaireResume>> veterinairesProposes(int signalementId) async =>
      _objets(await _api.get('/api/signalements/$signalementId/veterinaires'))
          .map(VeterinaireResume.json)
          .toList();

  /// POST /api/signalements/{id}/veterinaire/{veterinaireId} — l'eleveur
  /// confie son signalement au veterinaire choisi.
  static Future<SuiviSignalement> choisirVeterinaire(int signalementId, int veterinaireId) async =>
      SuiviSignalement.json(await _api.post(
              '/api/signalements/$signalementId/veterinaire/$veterinaireId')
          as Map<String, dynamic>);

  /// POST /api/signalements/symptomes — ajoute un symptome a la liste
  /// (veterinaire). Un libelle deja present rend le symptome existant.
  static Future<Symptome> creerSymptome(String libelle) async => Symptome.json(
      await _api.post('/api/signalements/symptomes', corps: {'libelle': libelle.trim()})
          as Map<String, dynamic>);

  // ── cote veterinaire ────────────────────────────────────────────────────

  /// GET /api/signalements/file?statut=&page= — les signalements orientes
  /// vers le veterinaire connecte, 20 par page.
  static Future<PageApi<Signalement>> file({String? statut, int page = 0}) async =>
      PageApi<Signalement>.json(
          await _api.get('/api/signalements/file',
              requete: {'statut': statut, 'page': page}) as Map<String, dynamic>,
          Signalement.json);

  /// POST /api/signalements/{id}/prise-en-charge — le veterinaire ACCEPTE
  /// le cas : ORIENTE devient EN_COURS, l'eleveur est prevenu.
  static Future<Signalement> prendreEnCharge(int id) async => Signalement.json(
      await _api.post('/api/signalements/$id/prise-en-charge') as Map<String, dynamic>);

  /// POST /api/signalements/{id}/refus — le veterinaire REFUSE le cas (V14).
  /// Le cas redevient NOUVEAU et l'eleveur choisit un autre veterinaire.
  static Future<Signalement> refuser(int id, {String? motif}) async => Signalement.json(
      await _api.post('/api/signalements/$id/refus', corps: {
        if (motif != null && motif.trim().isNotEmpty) 'motif': motif.trim(),
      }) as Map<String, dynamic>);

  // cloturer : voir VeterinaireGardeApi.cloturer (doublon retire).
}

// ── espace veterinaire ────────────────────────────────────────────────────

abstract final class VeterinaireApi {
  /// GET /api/veterinaires/accueil — compteurs de l'ecran d'accueil.
  static Future<AccueilVeterinaire> accueil() async => AccueilVeterinaire.json(
      await _api.get('/api/veterinaires/accueil') as Map<String, dynamic>);

  /// GET /api/veterinaires/competences — les maladies que le veterinaire
  /// connecte declare traiter.
  static Future<List<Maladie>> competences() async =>
      _objets(await _api.get('/api/veterinaires/competences'))
          .map(Maladie.json)
          .toList();

  /// POST /api/veterinaires/competences/{maladieId} — 409 si deja declaree.
  static Future<void> declarerCompetence(int maladieId) =>
      _api.post('/api/veterinaires/competences/$maladieId');

  /// DELETE /api/veterinaires/competences/{maladieId} — idempotent.
  static Future<void> retirerCompetence(int maladieId) =>
      _api.delete('/api/veterinaires/competences/$maladieId');

  /// POST /api/veterinaires/maladies — le veterinaire ajoute une maladie au
  /// catalogue avec ses symptomes ponderes ; il en devient competent.
  static Future<Maladie> creerMaladie({
    required String nom,
    required String gravite,
    required Set<String> filieres,
    String? traitement,
    required bool orienteVersVeterinaire,
    required Map<int, double> poidsSymptomes,
  }) async =>
      Maladie.json(await _api.post('/api/veterinaires/maladies', corps: {
        'nom': nom.trim(),
        'gravite': gravite,
        'filieres': filieres.toList(),
        if (traitement != null && traitement.trim().isNotEmpty) 'traitement': traitement.trim(),
        'orienteVersVeterinaire': orienteVersVeterinaire,
        'symptomes': [
          for (final e in poidsSymptomes.entries) {'symptomeId': e.key, 'poids': e.value},
        ],
      }) as Map<String, dynamic>);
}

// ── conseils ──────────────────────────────────────────────────────────────

abstract final class ConseilApi {
  // lister : voir ConseilEleveurApi.lister (doublon retire).

  /// GET /api/conseils/{id}
  static Future<ConseilDetail> lire(int id) async =>
      ConseilDetail.json(await _api.get('/api/conseils/$id') as Map<String, dynamic>);

  // ── cote veterinaire ────────────────────────────────────────────────────

  /// GET /api/conseils/mes-conseils — tous statuts, du plus recent au plus
  /// ancien.
  static Future<List<ConseilDetail>> mesConseils() async =>
      _objets(await _api.get('/api/conseils/mes-conseils'))
          .map(ConseilDetail.json)
          .toList();

  static Map<String, Object?> _conseil(
          String titre, String contenu, String filiere, String categorie) =>
      {
        'titre': titre.trim(),
        'contenu': contenu.trim(),
        'filiere': filiere,
        'categorie': categorie,
      };

  /// POST /api/conseils — cree un BROUILLON. Il faut ensuite [soumettre].
  static Future<ConseilDetail> rediger({
    required String titre,
    required String contenu,
    required String filiere,
    required String categorie,
  }) async =>
      ConseilDetail.json(await _api.post('/api/conseils',
          corps: _conseil(titre, contenu, filiere, categorie)) as Map<String, dynamic>);

  /// PUT /api/conseils/{id} — un conseil PUBLIE modifie repasse EN_MODERATION.
  static Future<ConseilDetail> modifier(
    int id, {
    required String titre,
    required String contenu,
    required String filiere,
    required String categorie,
  }) async =>
      ConseilDetail.json(await _api.put('/api/conseils/$id',
          corps: _conseil(titre, contenu, filiere, categorie)) as Map<String, dynamic>);

  /// POST /api/conseils/{id}/soumission — brouillon ou conseil retire vers
  /// la moderation.
  static Future<ConseilDetail> soumettre(int id) async => ConseilDetail.json(
      await _api.post('/api/conseils/$id/soumission') as Map<String, dynamic>);

  /// DELETE /api/conseils/{id} — definitif, auteur seulement.
  static Future<void> supprimer(int id) => _api.delete('/api/conseils/$id');
}

// ── notifications ─────────────────────────────────────────────────────────

abstract final class NotificationApi {
  /// GET /api/notifications
  static Future<PageApi<NotificationApp>> lister({int page = 0}) async =>
      PageApi<NotificationApp>.json(
          await _api.get('/api/notifications', requete: {'page': page})
              as Map<String, dynamic>,
          NotificationApp.json);

  /// POST /api/notifications/lecture — tout marquer comme lu.
  static Future<void> toutMarquerLu() => _api.post('/api/notifications/lecture');
}

// ── finances ──────────────────────────────────────────────────────────────

abstract final class FinanceApi {
  /// GET /api/finances/operations — `debut` et `fin` OBLIGATOIRES.
  static Future<List<Operation>> operations({
    required DateTime debut,
    required DateTime fin,
    String? filiere,
  }) async =>
      _objets(await _api.get('/api/finances/operations', requete: {
        'debut': versJour(debut),
        'fin': versJour(fin),
        'filiere': filiere,
      }))
          .map(Operation.json)
          .toList();

  static Map<String, Object?> _operation({
    required String type,
    required String categorie,
    required int montant,
    required DateTime date,
    required String filiere,
    int? uniteId,
    String? libelle,
  }) =>
      {
        'type': type,
        'categorie': categorie,
        'montant': montant,
        'dateOperation': versJour(date),
        'filiere': filiere,
        'uniteId': uniteId,
        if (libelle != null && libelle.trim().isNotEmpty) 'libelle': libelle.trim(),
      };

  /// POST /api/finances/operations
  static Future<Operation> creer({
    required String type,
    required String categorie,
    required int montant,
    required DateTime date,
    required String filiere,
    int? uniteId,
    String? libelle,
  }) async =>
      Operation.json(await _api.post('/api/finances/operations',
          corps: _operation(
              type: type, categorie: categorie, montant: montant, date: date,
              filiere: filiere, uniteId: uniteId, libelle: libelle))
          as Map<String, dynamic>);

  /// PUT /api/finances/operations/{id}
  static Future<Operation> modifier(
    int id, {
    required String type,
    required String categorie,
    required int montant,
    required DateTime date,
    required String filiere,
    int? uniteId,
    String? libelle,
  }) async =>
      Operation.json(await _api.put('/api/finances/operations/$id',
          corps: _operation(
              type: type, categorie: categorie, montant: montant, date: date,
              filiere: filiere, uniteId: uniteId, libelle: libelle))
          as Map<String, dynamic>);

  /// DELETE /api/finances/operations/{id}
  static Future<void> supprimer(int id) => _api.delete('/api/finances/operations/$id');

  /// GET /api/finances/solde — le mois en cours, toutes filieres si nulle.
  static Future<Solde> soldeDuMois({String? filiere}) async =>
      Solde.json(await _api.get('/api/finances/solde', requete: {'filiere': filiere})
          as Map<String, dynamic>);

  /// GET /api/finances/rapport
  static Future<Rapport> rapport({
    required DateTime debut,
    required DateTime fin,
    String? filiere,
  }) async =>
      Rapport.json(await _api.get('/api/finances/rapport', requete: {
        'debut': versJour(debut),
        'fin': versJour(fin),
        'filiere': filiere,
      }) as Map<String, dynamic>);

  /// GET /api/finances/rentabilite/{uniteId}
  static Future<Solde> rentabilite(int uniteId) async =>
      Solde.json(await _api.get('/api/finances/rentabilite/$uniteId')
          as Map<String, dynamic>);
}

// ── investissement : voir SimulateurApi (InvestissementApi, doublon
// inutilise, retire) ──────────────────────────────────────────────────────

// ── ajouts éleveur A (animaux, carnet) ───────────────────────────────────

abstract final class CarnetApi {
  /// GET /api/cheptel/{id}, avec la liste `sorties` (annulables).
  static Future<({DetailUnite detail, List<SortieUnite> sorties})> detail(int id) async {
    final j = await _api.get('/api/cheptel/$id') as Map<String, dynamic>;
    return (detail: DetailUnite.json(j), sorties: SortieUnite.depuisDetail(j));
  }

  /// DELETE /api/cheptel/{uniteId}/sorties/{sortieId} : annule une sortie
  /// ou une vente (effectif rétabli, revenu lié supprimé).
  static Future<void> annulerSortie(int uniteId, int sortieId) =>
      _api.delete('/api/cheptel/$uniteId/sorties/$sortieId');

  /// POST /api/cheptel/{uniteId}/cloture : termine le lot ou l'animal.
  static Future<Unite> cloturer(int uniteId) async =>
      Unite.json(await _api.post('/api/cheptel/$uniteId/cloture') as Map<String, dynamic>);
}

/// Simulateur avec un objectif de sujets (`sujetsVises`) : « combien pour
/// 100 poulets ? ». Sans lui, le back part du budget.
abstract final class SimulateurApi {
  static Map<String, Object?> _requete(int budget, bool installation, int? sujetsVises) => {
        'budget': budget,
        'inclureInstallation': installation,
        if (sujetsVises != null) 'sujetsVises': sujetsVises,
      };

  /// POST /api/investissement/simulation
  static Future<SimulationInvestissement> simuler(int budget,
          {required bool inclureInstallation, int? sujetsVises}) async =>
      SimulationInvestissement.json(await _api.post('/api/investissement/simulation',
              corps: _requete(budget, inclureInstallation, sujetsVises))
          as Map<String, dynamic>);

  /// POST /api/investissement/simulation/{typeElevageId}
  static Future<DetailSimulation> detail(int typeElevageId, int budget,
          {required bool inclureInstallation, int? sujetsVises}) async =>
      DetailSimulation.json(await _api.post('/api/investissement/simulation/$typeElevageId',
              corps: _requete(budget, inclureInstallation, sujetsVises))
          as Map<String, dynamic>);
}

// ── ajouts vétérinaire ────────────────────────────────────────────────────

abstract final class VeterinaireGardeApi {
  /// POST /api/signalements/{id}/cloture avec le diagnostic retenu.
  /// [maladieConfirmeeId] nul : « diagnostic non posé ». 422 si le cas est
  /// deja clos, 403 s'il a ete confie a un confrere, 409 en cas de conflit.
  static Future<Signalement> cloturer(int id, String compteRendu,
          {int? maladieConfirmeeId}) async =>
      Signalement.json(await _api.post('/api/signalements/$id/cloture', corps: {
        'compteRendu': compteRendu.trim(),
        if (maladieConfirmeeId != null) 'maladieConfirmeeId': maladieConfirmeeId,
      }) as Map<String, dynamic>);

  /// GET /api/signalements/{id} — un cas confie au veterinaire (404 sinon).
  static Future<Signalement> lire(int id) async =>
      Signalement.json(await _api.get('/api/signalements/$id') as Map<String, dynamic>);

  /// PUT /api/veterinaires/disponibilite — rend l'etat enregistre.
  static Future<bool> changerDisponibilite(bool disponible) async {
    final j = await _api.put('/api/veterinaires/disponibilite',
        corps: {'disponible': disponible});
    return j is Map<String, dynamic> ? ((j['disponible'] as bool?) ?? disponible) : disponible;
  }

  /// GET /api/notifications/non-lues — un nombre.
  static Future<int> notificationsNonLues() async {
    final j = await _api.get('/api/notifications/non-lues');
    if (j is num) return j.toInt();
    if (j is Map<String, dynamic>) return ((j['nombre'] ?? j['nonLues'] ?? 0) as num).toInt();
    return 0;
  }
}

// ── ajouts éleveur B (santé, notifications, argent) ──────────────────────

abstract final class SuiviSignalementApi {
  /// GET /api/signalements/mes — les signalements de l'eleveur connecte,
  /// du plus recent au plus ancien.
  static Future<List<SuiviSignalement>> mes() async =>
      _objets(await _api.get('/api/signalements/mes')).map(SuiviSignalement.json).toList();

  /// GET /api/signalements/{id} — meme route que
  /// [VeterinaireGardeApi.lire], lue avec le veterinaire oriente.
  static Future<SuiviSignalement> detail(int id) async => SuiviSignalement.json(
      await _api.get('/api/signalements/$id') as Map<String, dynamic>);
}

abstract final class AlerteEleveurApi {
  /// Les alertes en cours de l'eleveur. Le back ne les rend que dans
  /// GET /api/tableau-de-bord (pas de route alerte).
  static Future<List<Alerte>> enCours() async => (await TableauDeBordApi.charger()).alertes;
}

abstract final class ConseilEleveurApi {
  /// GET /api/conseils?filiere=&categorie=&page= — publies seulement.
  static Future<PageApi<ConseilResume>> lister(
          {String? filiere, String? categorie, int page = 0}) async =>
      PageApi<ConseilResume>.json(
          await _api.get('/api/conseils',
                  requete: {'filiere': filiere, 'categorie': categorie, 'page': page})
              as Map<String, dynamic>,
          ConseilResume.json);
}
