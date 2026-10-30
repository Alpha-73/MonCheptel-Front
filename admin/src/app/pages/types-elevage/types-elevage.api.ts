import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { CouleurBadge } from '../../core/format';
import { Filiere } from '../../core/modeles';

// Référentiel des types d'élevage : il alimente le simulateur d'investissement
// (chaque chiffre saisi ici sort en FCFA chez un éleveur) et la liste
// déroulante à la création d'un élevage. Types repris des DTO Java
// TypeElevageRequete / TypeElevageReponse / PosteCout*.

/** PAR_PERIODE : cycle à durée fixe (poulet de chair, 45 j) ; PAR_ENTREE : sans durée de cycle. */
export type ModeEvaluation = 'PAR_PERIODE' | 'PAR_ENTREE';
export type NiveauDifficulte = 'ACCESSIBLE' | 'MOYEN' | 'EXIGEANT';
/** INSTALLATION : payée une fois, réutilisable ; CYCLE : à chaque cycle. */
export type PhaseCout = 'INSTALLATION' | 'CYCLE';
/** Sur quoi se multiplie le prix unitaire : sujets achetés, capacité de référence, ou une fois. */
export type ModeQuantite = 'PAR_SUJET' | 'PAR_CAPACITE' | 'FORFAIT';

export const MODES_EVALUATION: ModeEvaluation[] = ['PAR_PERIODE', 'PAR_ENTREE'];
export const DIFFICULTES: NiveauDifficulte[] = ['ACCESSIBLE', 'MOYEN', 'EXIGEANT'];
export const PHASES_COUT: PhaseCout[] = ['INSTALLATION', 'CYCLE'];
export const MODES_QUANTITE: ModeQuantite[] = ['PAR_SUJET', 'PAR_CAPACITE', 'FORFAIT'];

export const LIBELLES_MODE_EVALUATION: Record<ModeEvaluation, string> = { PAR_PERIODE: 'Par période', PAR_ENTREE: 'Par entrée' };
export const LIBELLES_DIFFICULTE: Record<NiveauDifficulte, string> = { ACCESSIBLE: 'Accessible', MOYEN: 'Moyen', EXIGEANT: 'Exigeant' };
export const LIBELLES_PHASE: Record<PhaseCout, string> = { INSTALLATION: 'Installation', CYCLE: 'Chaque cycle' };
export const LIBELLES_MODE_QUANTITE: Record<ModeQuantite, string> = {
  PAR_SUJET: 'Par sujet',
  PAR_CAPACITE: 'Par capacité',
  FORFAIT: 'Forfait',
};

/** Accessible en vert, Moyen en orange, Exigeant en rouge (comme la gravité). */
export function couleurDifficulte(d: NiveauDifficulte | null | undefined): CouleurBadge {
  return d === 'EXIGEANT' ? 'rouge' : d === 'MOYEN' ? 'orange' : d === 'ACCESSIBLE' ? 'vert' : 'gris';
}

/** Taux de mortalité prévisionnel maximal accepté par l'API (fraction). */
export const TAUX_MORTALITE_MAX = 0.9;

export interface PosteCout {
  id?: number;
  libelle: string;
  montant: number;
  unite?: string;
  phase: PhaseCout;
  modeQuantite: ModeQuantite;
  coefficient: number;
  ordre: number;
}

export interface TypeElevageAdmin {
  id: number;
  filiere: Filiere;
  libelle: string;
  modeEvaluation: ModeEvaluation;
  dureeCycleJours?: number | null;
  capaciteReference: number;
  espaceParSujetM2?: number | null;
  temperatureMin?: number | null;
  temperatureMax?: number | null;
  alimentParSujetKg?: number | null;
  eauParSujetJourL?: number | null;
  vaccinsObligatoires?: string | null;
  /** FRACTION : 0,08 pour 8 %. */
  tauxMortalite: number;
  difficulte: NiveauDifficulte;
  actif: boolean;
  postesCout: PosteCout[];
}

export type PosteCoutRequete = Omit<PosteCout, 'id'>;

/** Acte d'une étape de protocole (TypeEvenement côté serveur, sans « Maladie »). */
export type ActeProtocole = 'VACCINATION' | 'TRAITEMENT' | 'CONSULTATION';
export const ACTES_PROTOCOLE: ActeProtocole[] = ['VACCINATION', 'TRAITEMENT', 'CONSULTATION'];
export const LIBELLES_ACTE: Record<ActeProtocole, string> = {
  VACCINATION: 'Vaccination',
  TRAITEMENT: 'Traitement',
  CONSULTATION: 'Consultation',
};

/** Étape du protocole sanitaire : elle devient un rappel à la création d'un élevage. */
export interface EtapeProtocole {
  id: number | null;
  libelle: string;
  typeEvenement: ActeProtocole;
  jourDuCycle: number;
  obligatoire: boolean;
}

export interface TypeElevageRequete {
  filiere: Filiere;
  libelle: string;
  modeEvaluation: ModeEvaluation;
  /** Obligatoire en PAR_PERIODE, nul en PAR_ENTREE (règle vérifiée par le serveur). */
  dureeCycleJours: number | null;
  capaciteReference: number;
  espaceParSujetM2: number | null;
  temperatureMin: number | null;
  temperatureMax: number | null;
  alimentParSujetKg: number | null;
  eauParSujetJourL: number | null;
  vaccinsObligatoires: string | null;
  tauxMortalite: number;
  difficulte: NiveauDifficulte;
  /** Au moins un poste ; ils sont remplacés en bloc à chaque modification. */
  postesCout: PosteCoutRequete[];
}

// ── Aides pures (testées dans types-elevage.spec.ts) ─────────────────────

/** Lit un nombre saisi (« 8,5 » ou 8.5) ; null si vide ou illisible. */
export function lireNombre(valeur: unknown): number | null {
  if (valeur === null || valeur === undefined || valeur === '') {
    return null;
  }
  const n = typeof valeur === 'number' ? valeur : parseFloat(String(valeur).replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

/** 0,08 → 8 (pourcentage affiché, au centième). */
export function pourcentageDepuisTaux(taux: number | null | undefined): number | null {
  const n = lireNombre(taux);
  return n === null ? null : Math.round(n * 10000) / 100;
}

/**
 * 8 (%) → 0,08 envoyé à l'API. Null hors de [0, 90 %] : un pourcentage saisi
 * comme une fraction (0,08) passe, mais compterait cent fois moins de sujets
 * à racheter — d'où l'unité « % » toujours affichée à côté du champ.
 */
export function tauxDepuisPourcentage(pourcentage: unknown): number | null {
  const n = lireNombre(pourcentage);
  if (n === null || n < 0 || n > TAUX_MORTALITE_MAX * 100) {
    return null;
  }
  return Math.round(n * 100) / 10000;
}

/** Règle du serveur (ReferentielService.exigerCoherenceDuCycle), vérifiée avant l'envoi. */
export function erreurCycle(mode: ModeEvaluation, dureeCycleJours: number | null | undefined): string | null {
  const duree = lireNombre(dureeCycleJours);
  if (mode === 'PAR_PERIODE') {
    if (duree === null) {
      return 'Un suivi par période demande une durée de cycle en jours.';
    }
    if (duree <= 0 || !Number.isInteger(duree)) {
      return 'La durée du cycle est un nombre entier de jours, supérieur à zéro.';
    }
  }
  return null;
}

/** La durée envoyée : toujours nulle en PAR_ENTREE, même si un champ masqué en garde une. */
export function dureeCyclePourRequete(mode: ModeEvaluation, dureeCycleJours: number | null | undefined): number | null {
  return mode === 'PAR_PERIODE' ? lireNombre(dureeCycleJours) : null;
}

/**
 * Sujets à acheter pour en garder `capacite` (TypeElevage.sujetsAAcheter) :
 * la mortalité ne se provisionne que sur une bande (volaille) ; une filière
 * suivie bête par bête achète ce qu'elle vise.
 */
export function sujetsAchetes(filiere: Filiere, capacite: number, tauxMortalite: number): number {
  if (!capacite || capacite <= 0) {
    return 0;
  }
  if (filiere !== 'VOLAILLE') {
    return capacite;
  }
  // Arrondi au millionième avant le plafond : 100 × 1,08 vaut 108,00000000000001 en flottant.
  return Math.ceil(Math.round(capacite * (1 + (tauxMortalite || 0)) * 1e6) / 1e6);
}

/** Coût d'un poste (PosteCout.calculer) : base × coefficient × montant, arrondi au franc. */
export function coutPoste(
  poste: Pick<PosteCout, 'modeQuantite' | 'coefficient' | 'montant'>,
  achetes: number,
  capacite: number,
): number {
  const base = poste.modeQuantite === 'PAR_SUJET' ? achetes : poste.modeQuantite === 'PAR_CAPACITE' ? capacite : 1;
  const total = base * (lireNombre(poste.coefficient) ?? 0) * (lireNombre(poste.montant) ?? 0);
  return Math.round(total);
}

export interface EstimationCouts {
  sujetsAchetes: number;
  installation: number;
  cycle: number;
}

/** Ce que le simulateur annoncerait pour la capacité de référence. */
export function estimerCouts(
  type: Pick<TypeElevageAdmin, 'filiere' | 'capaciteReference' | 'tauxMortalite'> & {
    postesCout: Pick<PosteCout, 'phase' | 'modeQuantite' | 'coefficient' | 'montant'>[];
  },
): EstimationCouts {
  const capacite = lireNombre(type.capaciteReference) ?? 0;
  const achetes = sujetsAchetes(type.filiere, capacite, lireNombre(type.tauxMortalite) ?? 0);
  const estimation: EstimationCouts = { sujetsAchetes: achetes, installation: 0, cycle: 0 };
  for (const p of type.postesCout ?? []) {
    const cout = coutPoste(p, achetes, capacite);
    if (p.phase === 'INSTALLATION') {
      estimation.installation += cout;
    } else {
      estimation.cycle += cout;
    }
  }
  return estimation;
}

// ── Appels HTTP ─────────────────────────────────────────────────────────

/**
 * GET/POST/PUT/DELETE /api/admin/types-elevage. La liste rend les types
 * actifs ET retirés. DELETE = suppression DÉFINITIVE (409 si un élevage
 * emploie le type) ; POST …/{id}/retrait = retrait réversible (actif = false).
 */
@Injectable({ providedIn: 'root' })
export class TypesElevageApi {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/api/admin/types-elevage`;

  liste(filiere?: Filiere | null): Observable<TypeElevageAdmin[]> {
    const params = filiere ? new HttpParams().set('filiere', filiere) : undefined;
    return this.http.get<TypeElevageAdmin[]>(this.url, { params });
  }

  lire(id: number): Observable<TypeElevageAdmin> {
    return this.http.get<TypeElevageAdmin>(`${this.url}/${id}`);
  }

  /** 409 si le libellé existe déjà dans cette filière. */
  creer(requete: TypeElevageRequete): Observable<TypeElevageAdmin> {
    return this.http.post<TypeElevageAdmin>(this.url, requete);
  }

  /** 422 si la filière change alors que des élevages emploient ce type. */
  modifier(id: number, requete: TypeElevageRequete): Observable<TypeElevageAdmin> {
    return this.http.put<TypeElevageAdmin>(`${this.url}/${id}`, requete);
  }

  /** Retrait logique (réversible) : le type sort du simulateur et des listes éleveur. */
  retirer(id: number): Observable<void> {
    return this.http.post<void>(`${this.url}/${id}/retrait`, null);
  }

  /** Suppression définitive ; 409 si un élevage emploie ce type. */
  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}/${id}`);
  }

  reactiver(id: number): Observable<TypeElevageAdmin> {
    return this.http.post<TypeElevageAdmin>(`${this.url}/${id}/reactivation`, null);
  }

  protocole(id: number): Observable<EtapeProtocole[]> {
    return this.http.get<EtapeProtocole[]>(`${this.url}/${id}/protocole`);
  }

  /** Remplace le protocole ; vaut pour les élevages créés ensuite. 422 si une étape dépasse le cycle. */
  remplacerProtocole(id: number, etapes: EtapeProtocole[]): Observable<EtapeProtocole[]> {
    return this.http.put<EtapeProtocole[]>(`${this.url}/${id}/protocole`, { etapes });
  }
}
