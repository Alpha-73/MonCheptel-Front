# MonCheptel — console d'administration (Angular)

Console web de l'administration MonCheptel : tableau de bord, éleveurs, vétérinaires,
catalogue des maladies, modération des conseils, alertes sanitaires et statistiques.
Elle suit la maquette `maquettes/MonCheptel-Parcours-Administration/` et parle à l'API
Spring Boot (`back/api`) selon `CONTRAT-API-AJOUTS.md`.

- Angular **21.2** (composants standalone, signaux, sans zone.js), SCSS, routeur, sans SSR.
- Tests unitaires : **Vitest** (runner par défaut d'Angular 21, environnement jsdom).

> **Pourquoi Angular 21 et pas 22 ?** `npx @angular/cli@latest` installe Angular 22.2, qui
> exige Node ≥ 22.22.3 (ou ≥ 24.15). La machine de développement a Node 22.22.0 : la CLI 22
> refuse de démarrer. Angular 21.2 est la dernière version compatible avec ce Node. Après une
> mise à jour de Node, `npx ng update @angular/core @angular/cli` fait passer en 22 sans
> changement de code (tout est déjà en standalone + signaux + contrôle de flux `@if/@for`).

## Installation et lancement

```bash
cd admin
npm install
npm start            # ng serve → http://localhost:4200
```

Le back doit tourner sur `http://localhost:8080` (profil `dev`). Il autorise l'origine
`http://localhost:4200` en CORS : aucun proxy n'est nécessaire, mais **la console doit être
servie sur le port 4200** (une autre origine serait refusée par le navigateur).

| Commande | Effet |
|---|---|
| `npm start` | serveur de développement (configuration `development`) |
| `npm run build` | build de production dans `dist/admin/browser` |
| `npx ng test --watch=false` | tests unitaires Vitest, une passe |

URL de l'API : `src/environments/environment.development.ts` (dev : `http://localhost:8080`)
et `src/environments/environment.ts` (production : vide = même origine derrière un reverse
proxy `/api` ; à renseigner sinon).

### Compte de démonstration

| E-mail | Mot de passe | Rôle |
|---|---|---|
| `admin@moncheptel.ml` | `admin2026` | ADMINISTRATEUR |

Un compte éleveur ou vétérinaire est **refusé** (« Cet espace est réservé à l'administration ») :
sa session est aussitôt révoquée côté serveur.

## Architecture

```
src/app/
  core/
    modeles.ts            types des DTO (JetonReponse, MaladieAdminReponse, …)
    api.service.ts        toutes les routes utilisées
    session.service.ts    jetons en sessionStorage, renouvellement partagé, déconnexion
    auth.interceptor.ts   Bearer, renouvellement avant expiration ou sur 401
    gardes.ts             accès admin / mot de passe imposé / page de connexion
    format.ts             nombres « 1 248 », dates « 18 sept. », libellés des énumérations
    erreurs.ts            message français du back (ErreurReponse) → texte affiché
    chargement.ts         état chargement / données / erreur d'un écran
  shared/                 icônes (tracés de la maquette), pop-up, en-tête, filtres, pipes
  layout/coque.*          menu latéral 280 px + bloc « AD / Administrateur / e-mail » + Se déconnecter
  pages/…                 un dossier par rubrique
```

### Session et jetons

- `POST /api/auth/connexion` → les jetons sont gardés en **`sessionStorage`** (clé
  `moncheptel.admin.session`) : fermer l'onglet ferme la session.
- L'intercepteur ajoute `Authorization: Bearer …` aux seules URL de l'API.
- Le jeton d'accès est renouvelé **30 s avant son expiration** (`POST /api/auth/rafraichir`),
  ou après un **401** (jeton révoqué ou expiré côté serveur) puis la requête est rejouée une fois.
- Le back fait tourner le jeton de rafraîchissement (usage unique) : **un seul renouvellement
  est partagé** entre toutes les requêtes concurrentes ; une requête qui reçoit un 401 alors que
  le jeton a déjà changé est rejouée sans nouveau renouvellement.
- **422** au renouvellement = session expirée → retour à `/connexion?expiree=1`.
- `doitChangerMotDePasse` → écran `/mot-de-passe` imposé. Le back révoque toutes les sessions
  après le changement : la console se reconnecte aussitôt avec le nouveau mot de passe.

## Correspondance maquette → composant → routes

| Écran de la maquette | Composant | Route console | Routes API |
|---|---|---|---|
| *(Admin - Connexion, absent de l'export)* | `pages/connexion/connexion.ts` | `/connexion` | `POST /api/auth/connexion`, `POST /api/auth/deconnexion` |
| *(changement imposé, absent)* | `pages/connexion/mot-de-passe.ts` | `/mot-de-passe` | `POST /api/auth/mot-de-passe` puis connexion |
| Admin - Tableau de bord | `pages/tableau-de-bord/tableau-de-bord.ts` | `/tableau-de-bord` | `GET /api/admin/tableau-de-bord` |
| Admin - Utilisateurs liste | `pages/utilisateurs/utilisateurs-liste.ts` | `/utilisateurs` | `GET /api/admin/utilisateurs?recherche&filiere&zoneId&actif&page`, `GET /api/zones` |
| Admin - Utilisateur fiche (+ POPUP Désactiver) | `pages/utilisateurs/utilisateur-fiche.ts` | `/utilisateurs/:id` | `GET /api/admin/utilisateurs/{id}/fiche`, `POST …/{id}/activation?actif=` |
| Admin - Utilisateur modifier | `pages/utilisateurs/utilisateur-modifier.ts` | `/utilisateurs/:id/modifier` | `GET …/fiche`, `PUT /api/admin/utilisateurs/{id}` |
| Admin - Vétérinaires liste | `pages/veterinaires/veterinaires-liste.ts` | `/veterinaires` | `GET /api/admin/veterinaires?zoneId=` |
| Admin - Vétérinaire créer | `pages/veterinaires/veterinaire-formulaire.ts` | `/veterinaires/nouveau` | `GET /api/admin/maladies`, `POST /api/admin/veterinaires`, `POST …/competences/{maladieId}` |
| Admin - Vétérinaire modifier (+ POPUP Désactiver) | `pages/veterinaires/veterinaire-formulaire.ts` | `/veterinaires/:id` | `GET /api/admin/veterinaires/{id}`, `PUT …`, `POST/DELETE …/competences/{maladieId}`, `POST /api/admin/utilisateurs/{id}/activation` |
| Admin - Maladies catalogue | `pages/maladies/maladies-catalogue.ts` | `/maladies` | `GET /api/admin/maladies` |
| Admin - Maladie créer | `pages/maladies/maladie-formulaire.ts` | `/maladies/nouvelle` | `GET /api/signalements/symptomes`, `POST /api/admin/maladies` |
| Admin - Maladie modifier (+ POPUP Supprimer) | `pages/maladies/maladie-formulaire.ts` | `/maladies/:id` | `GET /api/admin/maladies/{id}`, `PUT …`, `DELETE …` |
| Admin - Conseils modération (+ POPUP Valider, Publié, Retirer) | `pages/conseils/conseils-moderation.ts` | `/conseils` | `GET /api/admin/conseils`, `POST /api/admin/moderation/{id}` |
| Admin - Conseil créer | `pages/conseils/conseil-creer.ts` | `/conseils/nouveau` | `POST /api/admin/conseils` |
| Admin - Alertes liste (+ POPUP Clôturer) | `pages/alertes/alertes-liste.ts` | `/alertes` | `GET /api/admin/alertes`, `POST /api/admin/alertes/{id}/cloture` |
| Admin - Alerte déclencher | `pages/alertes/alerte-declencher.ts` | `/alertes/nouvelle` | `GET /api/admin/maladies`, `GET /api/zones`, `GET /api/admin/alertes/apercu`, `POST /api/admin/alertes` |
| Admin - Alerte modifier (+ POPUP Clôturer) | `pages/alertes/alerte-modifier.ts` | `/alertes/:id` | `GET /api/admin/alertes`, `PUT /api/admin/alertes/{id}`, `POST …/cloture` |
| Admin - Statistiques | `pages/statistiques/statistiques.ts` | `/statistiques` | `GET /api/admin/statistiques`, `GET /api/admin/maladies` |

La navigation suit `liens/liens-administration.txt` : tuiles du tableau de bord cliquables
(Utilisateurs, Alertes actives, Alertes envoyées, Vétérinaires, Maladies signalées, Conseils
publiés), lignes des listes → fiche ou formulaire, « Retour à … », boutons Annuler/Enregistrer
→ écran indiqué, pop-up centrés sur fond noir à 35 % qui se ferment au clic extérieur (et à
Échap). Couleurs, tailles et police (Roboto) sont relevées dans les SVG (`ecrans/`).

## Écarts avec la maquette, et pourquoi

Données factices remplacées par l'API ; **ce qui n'existe pas dans l'API a été retiré plutôt
qu'inventé** :

- **Tableau de bord** : « dans 9 régions » devient « dans N zones » (`zonesCouvertes` compte des
  zones). « Derniers signalements » n'est pas cliquable (pas d'identifiant d'éleveur dans
  `SignalementResumeReponse`) et il n'y a pas de « Voir tout ».
- **Fiche utilisateur** : la tuile « Animaux / lots » affiche le nombre de têtes et « N unités
  d'élevage » (le détail « 1 lot + 24 bovins » n'est pas dans `FicheUtilisateurReponse`).
  Un compte désactivé affiche « Réactiver ce compte » (absent de la maquette, nécessaire pour
  annuler une désactivation) ; un badge « Verrouillé » apparaît si `verrouille`.
- **Utilisateur modifier** : l'adresse e-mail, obligatoire dans `ProfilRequete`, n'est pas dans
  la maquette : elle est renvoyée inchangée.
- **Vétérinaires** : la maquette n'a qu'une « Zone d'intervention » ; à la création, la zone de
  rattachement (`zoneId`) prend la même valeur, en modification on conserve l'existante, ainsi
  que `titre` et `specialite` (non éditables dans la maquette). Les cases « Maladies traitées »
  sont le catalogue réel (pas « Gale », « Autre »…). Pop-up Désactiver : la phrase « Ses 3
  éleveurs orientés seront réaffectés… » est **retirée** (l'API ne donne ni ce nombre ni de
  réaffectation). Un compte désactivé affiche « Réactiver ce compte ».
- **Maladies** : « Filière concernée » est une liste à choix multiples (une maladie peut toucher
  plusieurs filières, `filieres[]`). **Ajout** de la section « Symptômes pondérés » : symptômes de
  `GET /api/signalements/symptomes`, un poids de 0 à 1 par symptôme coché (le back en exige au
  moins un). **Ajout** de la case « Orienter directement vers un vétérinaire »
  (`orienteVersVeterinaire`), cochée automatiquement pour une gravité Élevé. Dans « Modifier », la
  phrase « Cette maladie est signalée 38 fois ce mois » est retirée (donnée absente). Les maladies
  retirées (retrait logique) ne sont plus listées.
- **Conseils** : bouton « Ajouter un conseil » ajouté dans l'en-tête (le plugin prévoit le lien,
  l'export SVG n'a pas le bouton). Tuile « Retirés » : « au total » au lieu de « ces 30 jours »
  (pas de date de retrait dans l'API). Les tuiles filtrent la liste par statut. Pop-up Valider :
  « visible par les éleveurs de la filière X » sans le nombre d'éleveurs (non fourni). Pop-up
  Retirer : **champ « Motif du retrait » obligatoire** (exigé par le back), bouton désactivé tant
  qu'il est vide. Auteur absent = « Administration » (conseil publié par l'admin).
- **Alertes** : sous-titre « La portée est recalculée en direct » (pas de coût : la notification
  est gratuite). Filière facultative (« Toutes les filières »), comme `AlerteRequete`. Le message
  est pré-rempli avec le texte de la maquette. Le panneau « Avant de confirmer » ajoute le nombre
  de signalements récents (`signalementsRecents` de l'aperçu). Dans « Modifier », maladie, filière
  et zone sont affichées mais **non modifiables** (le back n'accepte que le message ; la portée est
  figée au déclenchement). Une alerte terminée s'ouvre en lecture seule.
- **Statistiques** : « + 5 pts » (évolution de la rétention) est retiré (non fourni) et remplacé
  par « comptes actifs ces 30 jours ». Les zones au-delà de la 5ᵉ sont regroupées en « Autres ».
  Couleur des barres « Maladies les plus signalées » : selon la gravité de la maladie du
  catalogue (rouge Élevé, orange Moyen).
- **Ajouts hors maquette** : pagination « Précédent / Suivant » de la liste des éleveurs (20 par
  page côté serveur) ; filtres affichant leur valeur (« Zone : Bamako ») ; bouton « Se déconnecter »
  sous le bloc administrateur ; écrans de connexion et de mot de passe imposé dessinés dans la
  même charte ; états de chargement, d'erreur (message du back + « Réessayer ») et de liste vide.

## Tests

```bash
npx ng test --watch=false
```

- `core/format.spec.ts`, `shared/pipes.spec.ts` : nombres, dates, libellés, pluriels, initiales.
- `core/auth.interceptor.spec.ts` : en-tête Bearer, renouvellement anticipé, 401 → renouvellement
  + rejeu, **un seul renouvellement pour des requêtes concurrentes**, 422 → connexion, second 401
  propagé.
- `core/erreurs.spec.ts`, `pages/aides.spec.ts` : messages d'erreur, poids des symptômes,
  regroupement « Autres », délai, noms de vétérinaires.

Le runner d'Angular 21 est Vitest avec jsdom : aucun navigateur n'est nécessaire (l'option Karma
`--browsers=ChromeHeadless` n'existe plus ; le mode navigateur de Vitest demanderait
`@vitest/browser-playwright`).
