import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { NiveauGravite, PageReponse, StatutSignalement } from '../../core/modeles';

/** Les vues de l'écran, dans l'ordre des onglets. */
export type VueSignalements = 'A_ATTRIBUER' | 'ORIENTES' | 'EN_SUIVI' | 'TRAITES' | 'TOUS';

export const VUES: { valeur: VueSignalements; libelle: string }[] = [
  { valeur: 'A_ATTRIBUER', libelle: 'À attribuer' },
  /** Confiés à un vétérinaire qui n'a pas encore accepté ni refusé (statut ORIENTE). */
  { valeur: 'ORIENTES', libelle: 'En attente de réponse' },
  { valeur: 'EN_SUIVI', libelle: 'En suivi' },
  { valeur: 'TRAITES', libelle: 'Traités' },
  { valeur: 'TOUS', libelle: 'Tous' },
];

/**
 * Le candidat conseillé : le premier disponible qui ne suit pas déjà le cas
 * et ne l'a pas refusé (le serveur range les mieux placés d'abord), à défaut
 * le premier libre.
 */
export function candidatConseille(liste: CandidatVeterinaire[]): CandidatVeterinaire | null {
  return (
    liste.find((c) => !c.actuel && c.disponible && !c.aRefuse) ??
    liste.find((c) => !c.actuel && !c.aRefuse) ??
    liste.find((c) => !c.actuel) ??
    null
  );
}

export function lireVue(valeur: string | null | undefined): VueSignalements {
  return VUES.some((v) => v.valeur === valeur) ? (valeur as VueSignalements) : 'TOUS';
}

/** Une ligne de GET /api/admin/signalements. */
export interface SignalementAdmin {
  id: number;
  eleveurId: number;
  eleveurNom: string;
  zone?: string | null;
  uniteCode: string;
  /** Proposée par le moteur de diagnostic. */
  maladieProposee?: string | null;
  /** Retenue par le vétérinaire à la clôture. */
  maladieConfirmee?: string | null;
  gravite?: NiveauGravite | null;
  statut: StatutSignalement;
  /** Cas grave que personne ne suit. */
  aAttribuer: boolean;
  veterinaireId?: number | null;
  veterinaireNom?: string | null;
  dateSignalement: string;
  dateOrientation?: string | null;
  datePriseEnCharge?: string | null;
  dateTraitement?: string | null;
  /** Refus de ce cas par des vétérinaires (V14), du plus récent au plus ancien. */
  refus?: RefusCas[];
}

/** Un vétérinaire a refusé un cas qui lui était confié (V14). */
export interface RefusCas {
  veterinaireNom: string;
  motif?: string | null;
  dateRefus: string;
}

/** « Refusé par Dr Sow (en déplacement) » : le dernier refus, pour la liste. */
export function resumeRefus(s: SignalementAdmin): string | null {
  const r = s.refus?.[0];
  if (!r) return null;
  const autres = (s.refus?.length ?? 0) - 1;
  return `Refusé par ${r.veterinaireNom}${r.motif ? ` (${r.motif})` : ''}${autres > 0 ? ` et ${autres} autre${autres > 1 ? 's' : ''}` : ''}`;
}

/** GET /api/admin/signalements/{id}/candidats : les mieux placés d'abord. */
export interface CandidatVeterinaire {
  id: number;
  nom: string;
  zone?: string | null;
  competent: boolean;
  memeZone: boolean;
  disponible: boolean;
  casOuverts: number;
  actuel: boolean;
  /** Il a déjà refusé ce cas (V14) : l'administration peut passer outre. */
  aRefuse?: boolean;
}

/** « Spécialiste · même zone · 2 cas en cours ». */
export function argumentsCandidat(c: CandidatVeterinaire): string {
  const morceaux: string[] = [];
  if (c.competent) morceaux.push('compétent pour cette maladie');
  morceaux.push(c.memeZone ? 'même zone' : (c.zone ?? 'zone inconnue'));
  morceaux.push(c.casOuverts === 0 ? 'aucun cas en cours' : c.casOuverts === 1 ? '1 cas en cours' : `${c.casOuverts} cas en cours`);
  if (!c.disponible) morceaux.push('indisponible');
  if (c.aRefuse) morceaux.push('a déjà refusé ce cas');
  return morceaux.join(' · ');
}

@Injectable({ providedIn: 'root' })
export class SignalementsApi {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiUrl}/api/admin/signalements`;

  liste(vue: VueSignalements, page: number): Observable<PageReponse<SignalementAdmin>> {
    return this.http.get<PageReponse<SignalementAdmin>>(this.base, { params: { vue, page } });
  }

  candidats(id: number): Observable<CandidatVeterinaire[]> {
    return this.http.get<CandidatVeterinaire[]>(`${this.base}/${id}/candidats`);
  }

  attribuer(id: number, veterinaireId: number): Observable<SignalementAdmin> {
    return this.http.post<SignalementAdmin>(`${this.base}/${id}/orientation`, { veterinaireId });
  }
}
