# MonCheptel — application Flutter (espaces éleveur et vétérinaire)

Version 1.0 du 7 octobre 2026 : les espaces éleveur et vétérinaire sont complets et branchés sur le
back. Un compte administrateur se connecte et arrive sur un écran qui le renvoie vers la console web
d'administration : l'application mobile n'a pas d'espace administrateur.

`flutter analyze` ne signale aucun problème et `flutter test` passe (Flutter 3.38). Les tests
unitaires sont dans `test/` : mise en forme des montants et des dates, lecture des réponses du back
propres à l'espace vétérinaire.

---

## 1. Première installation (une seule fois)

Le dossier `android/` est fourni, déjà configuré (permission Internet, icône MonCheptel, nom
affiché). Il n'y a rien à générer :

```powershell
cd app
flutter pub get
flutter analyze
flutter test
```

**HTTP en clair :** le back de développement parle en `http`. Il n'est autorisé que dans les
builds debug et profile (`android/app/src/debug` et `src/profile/AndroidManifest.xml`). La version
de publication (`flutter build apk --release`) exige une API en **HTTPS** :
`flutter build apk --release --dart-define=API_URL=https://api.votre-domaine.ml`.

**Signature de publication :** créez une clé (`keytool -genkey -v -keystore moncheptel.jks
-keyalg RSA -keysize 2048 -validity 10000 -alias moncheptel`), puis un fichier
`android/key.properties` (jamais commité) :

```properties
storeFile=C:/chemin/vers/moncheptel.jks
storePassword=...
keyAlias=moncheptel
keyPassword=...
```

Modèle : `android/key.properties.exemple`. Sans ce fichier complet, ou avec une `API_URL` qui
n'est pas en `https://`, la construction `--release` **s'arrête** avec un message qui dit quoi
faire : plus de version de publication signée avec la clé de débogage. Pas à pas sous Windows :
`GUIDE-ESSAI.md`, section 8.

## 2. Lancer

Le back doit tourner (`.\lancer.ps1` dans `back\api`).

| Appareil | Commande |
|---|---|
| Émulateur Android | `flutter run` (l'adresse par défaut `10.0.2.2:8080` est le PC vu depuis l'émulateur) |
| Vrai téléphone, même Wi-Fi que le PC | `flutter run --dart-define=API_URL=http://192.168.X.Y:8080` |

Sur un vrai téléphone :
- trouvez l'adresse IP du PC avec `ipconfig` ;
- si le téléphone n'arrive pas à joindre le back, c'est presque toujours le **pare-feu Windows** :
  autorisez Java sur les réseaux privés, ou ouvrez le port 8080.

**Comptes de démonstration :** ceux du jeu V4 du back.

**Pas de Chrome :** le back n'autorise (CORS) que `localhost:4200`. `flutter run -d chrome` serait
refusé, et l'application est conçue pour le téléphone.

---

## 3. Architecture : trois couches, et c'est tout

```
lib/
  config.dart          adresse du back, délais, numéro de l'administration
  libelles.dart        codes du back → mots français  ('SOINS_VACCINATION' → « Soins et vaccination »)
  api/
    client_api.dart    LE SEUL fichier qui fait du HTTP : jetons, renouvellement, erreurs
    modeles.dart       une classe Dart par record Java de dto/reponse, mêmes noms de champs
    services.dart      une fonction par route du back, avec la route en commentaire
  theme/               palette, typographie, dimensions mesurées dans la maquette
  widgets/             composants réutilisés : cartes, boutons, champs, pop-ups, chargement
  ecrans/
    demarrage.dart     relit la session et oriente selon le rôle
    auth/              connexion, inscription, mot de passe oublié / imposé
    eleveur/           les 5 onglets et tous leurs écrans
    veterinaire/       les 4 onglets du vétérinaire et leurs écrans
    commun/            écran du rôle administrateur (renvoi vers la console web)
```

**Règle :** un écran ne fait jamais d'HTTP lui-même. Il appelle `services.dart` et reçoit des objets
Dart, ou une `ApiException` qui porte le message du back.

### Pourquoi aucune bibliothèque de gestion d'état (Riverpod, Bloc…)

Chaque écran charge ses données avec le widget `Chargeur` (`widgets/etats.dart`), qui gère trois
états : chargement, erreur avec « Réessayer », et données. L'écran se recharge au retour d'un
formulaire. À cette taille, c'est suffisant, et chaque ligne s'explique sans prérequis.

**Le prix :** un onglet recharge ses données à chaque visite, donc un appel réseau de plus. En
échange, il n'y a aucun cache à invalider et aucune donnée périmée affichée.

### La session (`api/client_api.dart`) : ce que le jury peut demander

| Question | Réponse dans le code |
|---|---|
| Où sont les jetons ? | `flutter_secure_storage` : Keystore Android, Keychain iOS. Jamais en clair : le jeton de rafraîchissement vaut 30 jours d'accès. |
| Jeton d'accès expiré ? | Renouvelé **avant** l'appel s'il expire dans moins d'une minute. Sinon, sur un 401 (jeton absent, expiré ou révoqué) : un seul renouvellement, puis une seule reprise. Un 403 est un refus de droits : il n'est jamais rejoué. |
| Deux requêtes en même temps ? | Elles attendent **le même** renouvellement (`_rafraichissement`). Le back fait tourner les jetons (usage unique) : deux renouvellements parallèles déconnecteraient l'utilisateur. |
| Renouvellement refusé (422) ? | Session effacée, retour à la connexion avec « Votre session a expiré ». |
| Réseau coupé pendant un renouvellement ? | On ne déconnecte **pas** : l'erreur réseau remonte et l'écran propose de réessayer. |
| Déconnexion ? | Le back révoque le jeton de rafraîchissement, puis la session locale est effacée. Si le back ne répond pas, on déconnecte quand même localement. |
| Accents ? | La réponse est toujours décodée en UTF-8 depuis les octets. `response.body` retombe sur latin-1 sans charset et afficherait « Ã‰levÃ© ». |

---

## 4. Correspondance maquette → back (espace éleveur)

| Maquette | Écran (fichier) | Routes |
|---|---|---|
| Connexion | `auth/connexion.dart` | POST /api/auth/connexion |
| CreerCompte (2 étapes) | `auth/inscription.dart` | GET /api/zones, POST /api/auth/inscription |
| MotDePasse oublié (4 écrans) | `auth/mot_de_passe_oublie.dart` | POST …/oublie, POST …/reinitialiser |
| MotDePasse – Modifier | `auth/mot_de_passe_impose.dart` | POST /api/auth/mot-de-passe |
| Dashboard ×4 | `eleveur/tableau_de_bord.dart` | GET /api/tableau-de-bord |
| MesAnimaux ×5 | `eleveur/animaux/mes_animaux.dart` | GET /api/cheptel, GET /api/auth/moi |
| AjouterAnimal | `eleveur/animaux/ajouter_unite.dart` | GET /api/types-elevage, POST /api/cheptel/lots ou /animaux |
| Carnet ×2 + Historique | `eleveur/animaux/carnet.dart` | GET /api/cheptel/{id} |
| ModifierAnimal | `eleveur/animaux/modifier_unite.dart` | PUT et DELETE /api/cheptel/{id} |
| AjouterEvenement + Sortie, Evenement – Modifier | `eleveur/animaux/evenement.dart` | POST /api/sanitaire/…/evenements, POST /api/cheptel/{id}/sorties, PUT et DELETE …/evenements/{id} |
| Rentabilité ×2 | `eleveur/animaux/rentabilite.dart` | GET /api/finances/rentabilite/{id}, …/operations |
| Santé – Accueil | `eleveur/sante/sante_accueil.dart` | GET /api/sanitaire/rappels, POST …/ignorer |
| Signalement ×4 | `eleveur/sante/signalement.dart` | GET …/symptomes, POST /api/signalements |
| Catalogue, Maladie – Fiche | `eleveur/sante/maladies.dart` | GET /api/signalements/maladies |
| Vétérinaires, Fiche | `eleveur/sante/veterinaires.dart` | GET /api/veterinaires |
| Alerte – Détail | `eleveur/sante/alerte.dart` | GET /api/cheptel, GET …/maladies |
| Conseils ×5, Lecture | `eleveur/conseils/conseils.dart` | GET /api/conseils, GET /api/conseils/{id} |
| Dépenses – Liste | `eleveur/finances/operations.dart` | GET /api/finances/solde, …/operations |
| Opération (×6) | `eleveur/finances/operation_form.dart` | POST, PUT et DELETE /api/finances/operations |
| Rapports ×3 | `eleveur/finances/rapports.dart` | GET /api/finances/rapport |
| Investir ×3 | `eleveur/investir/investir.dart` | POST /api/investissement/simulation[/{id}] |
| Logistique ×4 | `eleveur/investir/logistique.dart` | GET /api/types-elevage |
| Profil, Langue | `eleveur/profil/profil.dart` | GET /api/auth/moi |
| Mes informations | `eleveur/profil/mes_informations.dart` | PUT /api/auth/moi |
| Notifications | `eleveur/profil/notifications.dart` | GET /api/notifications, POST …/lecture |

### Écarts avec la maquette : tous voulus, tous dictés par le back

L'écran montre ce que le back sait. Ces données manquent au back : plutôt que d'inventer une
valeur, l'élément est retiré.

| Maquette | Ce que fait l'application | Raison |
|---|---|---|
| Inscription : Nom + Prénom | Envoie « Prénom Nom » | Le back n'a qu'un champ `nom` |
| Inscription : choix de langue | Retiré | Pas de champ langue à l'inscription, bambara non traduit |
| Inscription | **Ajout** d'un téléphone facultatif | Le vétérinaire orienté appelle l'éleveur à ce numéro |
| Ajouter un animal : « État » | Retiré | Un élevage naît actif et sort par une **sortie**, qui laisse une trace |
| Modifier le lot : Effectif | Lecture seule | Correction demandée : l'effectif suit les sorties |
| Carnet + Historique | Réunis en un écran | Une seule route rend les deux |
| Santé : « Derniers événements » | Remplacé par les rappels à 30 jours | Aucune route ne rassemble les événements de tout le cheptel |
| Maladie : « 3 vétérinaires, 38 cas ce mois » | Retiré | Aucune route éleveur ne rend ces chiffres |
| Vétérinaire : délai de réponse, maladies traitées | Retiré | Absents de `VeterinaireResumeReponse` |
| Rapports : « ↑ 18 % vs semestre précédent » | Retiré | Demanderait un second rapport ; pas inventé |
| Investir : Accessible / Limite / Hors budget | Difficulté + « Dans le budget / Hors budget » + écart exact | Le seuil de « Limite » n'existe nulle part |
| Rentabilité « période ouverte le 1 juil. » | « depuis l'entrée de l'élevage » | C'est ce que le back calcule |
| Numéro de l'administration | +223 73 53 87 94 | Le même que dans le modèle de courriel |

---

## 5. Espace vétérinaire

Même architecture que l'éleveur : `veterinaire/coquille_veterinaire.dart` porte la barre du bas
(Accueil, Éleveurs, Conseils, Profil) et reconstruit l'onglet à chaque visite. La maquette de ce
parcours a des en-têtes **clairs** (titre noir sur le fond gris), pas l'en-tête vert de l'éleveur :
`EnteteClair` pour les onglets, `EcranSecondaire(clair: true)` et `Chargeur(clair: true)` pour les
écrans secondaires.

### Correspondance maquette → écran → routes

| Maquette | Écran (fichier `ecrans/veterinaire/`) | Routes |
|---|---|---|
| Veto - Connexion | `auth/connexion.dart` (commun à tous les rôles) | POST /api/auth/connexion |
| Veto - Accueil | `accueil_veterinaire.dart` | GET /api/veterinaires/accueil, GET /api/auth/moi, GET /api/veterinaires/competences, GET /api/signalements/file |
| Veto - Eleveurs orientes | `demandes.dart` (`EleveursOrientes`) | GET /api/signalements/file?statut=ORIENTE, EN_COURS, TRAITE |
| Veto - Demande detail + pop-up Cas traité | `demandes.dart` (`EcranDemande`) | POST /api/signalements/{id}/prise-en-charge, POST /api/signalements/{id}/cloture |
| Veto - Mes conseils | `mes_conseils.dart` (`MesConseils`) | GET /api/conseils/mes-conseils |
| Veto - Conseil rediger + pop-up Publié | `mes_conseils.dart` (`EcranConseilVeto`) | GET /api/veterinaires/competences, POST /api/conseils, POST /api/conseils/{id}/soumission |
| Veto - Conseil modifier + pop-up Supprimer | `mes_conseils.dart` (`EcranConseilVeto`) | PUT /api/conseils/{id} (+ soumission si brouillon ou retiré), DELETE /api/conseils/{id} |
| Veto - Profil | `profil_veterinaire.dart` (`ProfilVeterinaire`) | GET /api/auth/moi, GET /api/veterinaires/competences ; changer le mot de passe : `auth/mot_de_passe_impose.dart` ; notifications : `eleveur/profil/notifications.dart` |
| Veto - Competences + pop-up Enregistré | `profil_veterinaire.dart` (`EcranCompetences`) | GET /api/signalements/maladies-catalogue, POST et DELETE /api/veterinaires/competences/{maladieId} |

**« En attente »** = signalements ORIENTE + EN_COURS (deux appels fusionnés, triés par gravité puis
ancienneté) ; **« Traités »** = TRAITE, le plus récent en tête. Chaque liste lit jusqu'à 10 pages de
20 (200 demandes) : au-delà, il faudra paginer à l'écran.

**Prise en charge :** ouvrir une demande ORIENTE la prend en charge (POST …/prise-en-charge), sans
bouton de plus que la maquette : l'éleveur sait que son cas a été lu. Si cet appel échoue (réseau),
« Marquer comme traité » le refait avant la clôture.

**Marquer comme traité :** le back exige un compte rendu. Une pop-up le demande (obligatoire,
2 000 caractères au plus), puis la pop-up « Cas marqué comme traité » de la maquette s'affiche ;
ses deux boutons ramènent à l'onglet Éleveurs ou à l'Accueil.

**Publier un conseil :** un vétérinaire ne se publie pas lui-même. « Publier » crée un brouillon
(POST /api/conseils) puis l'envoie en modération (POST …/soumission). Si le second appel échoue, le
brouillon reste dans « Mes conseils », et l'enregistrer depuis « Modifier » le renvoie.

### Écarts avec la maquette vétérinaire

| Maquette | Ce que fait l'application | Raison |
|---|---|---|
| Connexion : écran « Espace vétérinaire », champ « Téléphone ou e-mail » | Écran de connexion commun, champ e-mail, plus une ligne « Vétérinaire ? Connectez-vous avec les identifiants fournis par l'administrateur. » | Un seul écran pour tous les rôles ; le back connecte par e-mail seulement |
| Connexion : « Accéder à l'espace éleveur » | Retiré | Le rôle vient du compte, pas d'un choix à l'écran |
| Accueil, Profil : « Vos filières » | Déduites des maladies que le vétérinaire traite | Le back ne stocke pas de filières pour un vétérinaire |
| Demande : « Sujets touchés 255 — 30 % du lot » | La tranche déclarée (« 10 à 50 ») | L'éleveur déclare une tranche, pas un nombre ; le back ne connaît ni 255 ni 30 % |
| Demande : « Propagation rapide… intervention urgente recommandée » | La précision saisie par l'éleveur, si elle existe | Pas de texte d'urgence calculé par le back |
| Demande : un seul « Signalée il y a… » | Idem ; les cas traités montrent en plus le compte rendu et sa date | Le compte rendu existe dans `SignalementReponse` |
| Mes conseils : « ✓ Publié » | « Publié » (sans coche) ; aussi « Brouillon » et « Retiré » avec son motif | Statuts du back ; la coche n'est pas garantie dans toutes les polices Android |
| Conseil modifier : pas de catégorie | Catégorie affichée et modifiable | Le PUT exige la catégorie ; autant permettre de la corriger |
| Rédiger / Modifier : filières « Volaille, Bovins » | Les filières des compétences (les quatre si aucune) | Même raison que « Vos filières » |
| Profil : crayon de modification | Retiré | Aucune route ne permet au vétérinaire de modifier son profil (c'est l'administration) |
| Profil : « Zone d'intervention » cliquable | Affichée, non cliquable | Fixée par l'administration |
| Profil : interrupteur « Notifications — Nouvelles orientations » | Ouvre la liste des notifications | Aucune préférence de notification dans le back |
| Profil : « À propos — Aide et conditions » | Retiré | Aucun écran ni texte de conditions n'existe |
| Profil : « Se déconnecter » | Déconnecte sans confirmation, comme la maquette | — |
| Compétences : « Bamako et environs » | Nom de la zone d'intervention (« Koutiala ») | Le back rend une zone, pas une description |
| Compétences : « Enregistrer » toujours actif | Actif dès qu'une case change | Rien à envoyer sinon |
| Barre du bas sur Compétences | Absente (écran secondaire, flèche retour) | Comme tous les écrans secondaires de l'application |

---

## 6. Ce qui a changé dans le back pour ce front

**Espace vétérinaire (7 octobre) :** les routes du contrat `CONTRAT-API-AJOUTS.md` — accueil et
compétences du vétérinaire, catalogue complet des maladies, `uniteType` et `uniteEffectif` dans
`SignalementReponse`, `dateCreation` et `dateSoumission` dans `ConseilDetailReponse`, modification
d'un conseil publié (il repasse en modération) et suppression d'un conseil par son auteur.

**Espace éleveur (6 octobre) :**

Deux trous bloquaient l'écran « Ajouter un animal » et la fiche animal.

1. `GET /api/types-elevage?filiere=` (`AnnuaireControleur`) : l'éleveur n'avait aucun moyen de lister
   les types d'élevage, alors que `typeElevageId` est obligatoire pour créer un lot ou un animal.
   La route ne rend que les types **actifs**.
2. `UniteResumeReponse` gagne 5 champs en fin de record : `typeElevageId`, `race`, `sexe`,
   `dateNaissance`, `note`. C'est un ajout pur : les clients existants ne sont pas affectés.

**Défaut connu du back, non corrigé :** `/api/finances/rapport?filiere=X` filtre le total mais pas
la répartition des dépenses (`repartirDepenses` ignore la filière). Les pourcentages seraient alors
faux. L'écran Rapports n'envoie donc pas de filière tant que ce n'est pas corrigé.

---

## 7. Tester en 10 minutes (parcours de démonstration)

1. Créer un compte : Volaille + Bovins.
2. Animaux → Ajouter un lot : 100 poulets de chair.
3. Carnet → Ajouter un événement : vaccination, rappel dans 14 jours. Le rappel apparaît sur
   l'Accueil et dans Santé.
4. Accueil → Opération : dépense d'aliment de 8 500, rattachée au lot. Le solde du mois bouge.
5. Carnet → Enregistrer une sortie : vente de 20 têtes pour 60 000. Le lot passe à 80 têtes, le revenu
   apparaît dans Dépenses & revenus et ne s'y modifie pas.
6. Accueil → Déclarer une maladie : choisir le lot, puis toux, diarrhée verdâtre et torticolis.
   Lire le résultat et le vétérinaire proposé.
7. Profil → Changer mon mot de passe : retour forcé à la connexion.
8. Couper le Wi-Fi et tirer pour actualiser : message « Impossible de joindre le serveur » et
   bouton « Réessayer ».

### Côté vétérinaire (compte `aissata.traore@example.ml`, jeu V4)

1. Accueil : compteurs, demande en attente, filières.
2. Éleveurs → ouvrir la demande : elle passe « pris en charge ». « Appeler l'éleveur » ouvre le
   composeur.
3. « Marquer comme traité » : saisir un compte rendu. La demande passe dans « Traités » et l'éleveur
   reçoit une notification.
4. Conseils → « Rédiger un conseil » → Publier : il apparaît « En modération ».
5. Profil → Maladies que je traite : cocher une maladie, Enregistrer.
