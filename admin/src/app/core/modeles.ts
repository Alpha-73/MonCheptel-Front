// Types des échanges avec l'API MonCheptel.
// Ils reprennent les DTO Java (back/api/.../dto) et le contrat
// CONTRAT-API-AJOUTS.md. Les champs nuls sont omis par le serveur : ils sont
// donc marqués facultatifs ici.

export type Filiere = 'VOLAILLE' | 'BOVINS' | 'OVINS' | 'CAPRINS';
export type NiveauGravite = 'FAIBLE' | 'MOYEN' | 'ELEVE';
export type StatutSignalement = 'NOUVEAU' | 'ORIENTE' | 'EN_COURS' | 'TRAITE';
export type StatutConseil = 'BROUILLON' | 'EN_MODERATION' | 'PUBLIE' | 'RETIRE';
export type CategorieConseil = 'SANTE' | 'PRODUCTION' | 'HYGIENE';
export type StatutAlerte = 'ACTIVE' | 'TERMINEE';
export type Role = 'ELEVEUR' | 'VETERINAIRE' | 'ADMINISTRATEUR';
export type Langue = 'FR' | 'BM';

export const FILIERES: Filiere[] = ['VOLAILLE', 'BOVINS', 'OVINS', 'CAPRINS'];
export const GRAVITES: NiveauGravite[] = ['FAIBLE', 'MOYEN', 'ELEVE'];
export const CATEGORIES: CategorieConseil[] = ['SANTE', 'PRODUCTION', 'HYGIENE'];
export const LANGUES: Langue[] = ['FR', 'BM'];

// ── Authentification ────────────────────────────────────────────────────

export interface JetonReponse {
  jetonAcces: string;
  jetonRafraichissement: string;
  expireDansSecondes: number;
  utilisateurId: number;
  nom: string;
  role: Role;
  doitChangerMotDePasse: boolean;
}

export interface ErreurReponse {
  horodatage?: string;
  statut?: number;
  erreur?: string;
  message?: string;
  chemin?: string;
  champs?: Record<string, string>;
  details?: string[];
}

// ── Référentiel ─────────────────────────────────────────────────────────

export interface ZoneReponse {
  id: number;
  nom: string;
  region?: string;
}

export interface SymptomeReponse {
  id: number;
  libelle: string;
}

export interface PageReponse<T> {
  elements: T[];
  page: number;
  taille: number;
  total: number;
  nombrePages: number;
  derniere: boolean;
}

/** TypeNotification côté back (modele/enumeration/TypeNotification.java). */
export type TypeNotification = 'ALERTE' | 'RAPPEL' | 'MODERATION' | 'ORIENTATION' | 'SYSTEME';

/** NotificationReponse : GET /api/notifications. */
export interface NotificationAdmin {
  id: number;
  type: TypeNotification;
  titre: string;
  corps: string;
  lue: boolean;
  /** MALADIE, SIGNALEMENT, ALERTE… : l'écran à ouvrir au clic. */
  referenceType: string | null;
  referenceId: number | null;
  dateCreation: string;
}

export interface LigneStatistique {
  libelle: string;
  valeur: number;
}

// ── Tableau de bord et statistiques ─────────────────────────────────────

export interface SignalementResume {
  id: number;
  eleveurNom: string;
  zone?: string;
  maladie?: string;
  gravite?: NiveauGravite;
  statut: StatutSignalement;
  dateSignalement: string;
}

export interface TableauDeBordAdmin {
  utilisateurs: number;
  inscritsCeMois: number;
  tetesVivantes: number;
  tetesVolaille: number;
  alertesActives: number;
  zonesSousAlerte: string[];
  veterinaires: number;
  zonesCouvertes: number;
  signalements30j: number;
  alertes30j: number;
  orientesEnAttente: number;
  casSansVeterinaire: number;
  conseilsPublies: number;
  conseilsEnModeration: number;
  derniersSignalements: SignalementResume[];
  parFiliere: LigneStatistique[];
}

export interface Statistiques {
  utilisateurs: number;
  inscritsCeMois: number;
  tauxRetention30j: number;
  partSignalementsTraites: number;
  signalementsTraitesSur: number;
  delaiMoyenPriseEnChargeHeures?: number | null;
  parZone: LigneStatistique[];
  parRole: LigneStatistique[];
  maladiesLesPlusSignalees: LigneStatistique[];
}

// ── Utilisateurs ────────────────────────────────────────────────────────

export interface UtilisateurResume {
  id: number;
  nom: string;
  email?: string;
  telephone?: string;
  role: Role;
  zone?: string;
  filieres?: Filiere[];
  dateInscription?: string;
  actif: boolean;
  verrouille: boolean;
  doitChangerMotDePasse: boolean;
}

export interface ProfilReponse {
  id: number;
  nom: string;
  telephone?: string;
  email?: string;
  role: Role;
  zone?: ZoneReponse;
  langue?: Langue;
  dateInscription?: string;
  filieresPratiquees?: Filiere[];
  titre?: string;
  specialite?: string;
  zoneIntervention?: ZoneReponse;
  disponible?: boolean;
}

export interface ActiviteUtilisateur {
  date: string;
  libelle: string;
}

export interface FicheUtilisateur {
  profil: ProfilReponse;
  actif: boolean;
  verrouille: boolean;
  unites: number;
  tetes: number;
  signalements: number;
  signalementsEnCours: number;
  activite: ActiviteUtilisateur[];
}

export interface ProfilRequete {
  nom: string;
  email: string;
  telephone?: string;
  zoneId: number;
  langue: Langue;
  filieres: Filiere[];
}

export interface FiltresUtilisateurs {
  recherche?: string;
  filiere?: Filiere | null;
  zoneId?: number | null;
  actif?: boolean | null;
  page?: number;
}

// ── Vétérinaires ────────────────────────────────────────────────────────

export interface VeterinaireAdmin {
  id: number;
  nom: string;
  titre?: string;
  specialite?: string;
  telephone?: string;
  email?: string;
  zone?: ZoneReponse;
  zoneIntervention?: ZoneReponse;
  actif: boolean;
  disponible: boolean;
  /** Trop d'échecs de connexion : compte bloqué pour quelques minutes. */
  verrouille?: boolean;
  filieres: Filiere[];
  competences: number[];
  nombreCompetences: number;
}

export interface VeterinaireRequete {
  nom: string;
  telephone: string;
  email: string;
  zoneId: number;
  zoneInterventionId: number;
  titre?: string;
  specialite?: string;
}

/** Auteur d'un conseil (VeterinaireResumeReponse côté Java). */
export interface VeterinaireResume {
  id: number;
  nom: string;
  titre?: string;
  specialite?: string;
  zoneIntervention?: string;
  telephone?: string;
  disponible: boolean;
}

// ── Maladies ────────────────────────────────────────────────────────────

export interface PoidsSymptome {
  symptomeId: number;
  libelle?: string;
  poids: number;
}

export interface MaladieAdmin {
  id: number;
  nom: string;
  gravite: NiveauGravite;
  filieres: Filiere[];
  symptomesTexte?: string;
  traitement?: string;
  orienteVersVeterinaire: boolean;
  active: boolean;
  symptomes: PoidsSymptome[];
  veterinairesCompetents: number;
  /** Vétérinaire qui l'a ajoutée ; absent pour le catalogue de référence. */
  ajouteePar?: string;
}

export interface MaladieRequete {
  nom: string;
  gravite: NiveauGravite;
  filieres: Filiere[];
  symptomesTexte?: string;
  traitement?: string;
  orienteVersVeterinaire: boolean;
  symptomes: { symptomeId: number; poids: number }[];
}

// ── Conseils ────────────────────────────────────────────────────────────

export interface ConseilDetail {
  id: number;
  titre: string;
  contenu: string;
  filiere: Filiere;
  categorie: CategorieConseil;
  auteur?: VeterinaireResume;
  datePublication?: string;
  nombreLectures: number;
  statut: StatutConseil;
  motifRetrait?: string;
  dateCreation?: string;
  dateSoumission?: string;
}

export interface ConseilRequete {
  titre: string;
  contenu: string;
  filiere: Filiere;
  categorie: CategorieConseil;
}

// ── Alertes ─────────────────────────────────────────────────────────────

export interface AlerteReponse {
  id: number;
  maladie: string;
  zone: string;
  filiere?: Filiere;
  message: string;
  portee: number;
  dateDeclenchement: string;
  statut: StatutAlerte;
  /** Dernier jour de l'alerte, « 2026-10-20 » ; nulle = jusqu'à clôture manuelle. */
  dateFin?: string | null;
  dateCloture?: string | null;
}

export interface AlerteRequete {
  maladieId: number;
  zoneId: number;
  filiere?: Filiere | null;
  message: string;
  dateFin?: string | null;
}

export interface ApercuAlerte {
  signalementsRecents: number;
  eleveursCibles: number;
}
