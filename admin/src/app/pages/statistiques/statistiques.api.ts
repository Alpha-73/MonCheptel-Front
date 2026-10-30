import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { NiveauGravite } from '../../core/modeles';

/** Une semaine ISO (début le lundi) : signalements par gravité de la maladie proposée. */
export interface SemaineSignalements {
  /** Lundi de la semaine, « 2026-07-20 ». */
  debut: string;
  faible: number;
  moyen: number;
  eleve: number;
}

/** Un mois civil : comptes créés par rôle. */
export interface MoisInscriptions {
  /** « 2025-11 ». */
  mois: string;
  eleveurs: number;
  veterinaires: number;
}

/** Parcours des signalements des 30 derniers jours, étape par étape. */
export interface Entonnoir {
  signales: number;
  aOrienter: number;
  orientes: number;
  prisEnCharge: number;
  traites: number;
}

/** Tranche de délai signalement → prise en charge (90 j), toujours les 5 mêmes, dans l'ordre. */
export interface TrancheDelai {
  tranche: string;
  nombre: number;
}

/**
 * Maladie parmi les plus signalées (90 j). Un cas compte pour la maladie
 * confirmée par le vétérinaire quand il en a saisi une (`confirmes`), sinon
 * pour la proposition du moteur (`proposes`).
 */
export interface MaladieSignalee {
  maladie: string;
  gravite: NiveauGravite;
  confirmes: number;
  proposes: number;
}

/** Cas (90 j) où un vétérinaire a saisi un diagnostic, et combien rejoignent la proposition du moteur. */
export interface PrecisionMoteur {
  verifies: number;
  concordants: number;
}

export interface SeriesStatistiques {
  semaines: SemaineSignalements[];
  inscriptions: MoisInscriptions[];
  entonnoir: Entonnoir;
  delais: TrancheDelai[];
  maladies: MaladieSignalee[];
  moteur: PrecisionMoteur;
}

/** Séries temporelles de l'écran Statistiques : GET /api/admin/statistiques/series. */
@Injectable({ providedIn: 'root' })
export class StatistiquesApi {
  private readonly http = inject(HttpClient);

  series(): Observable<SeriesStatistiques> {
    return this.http.get<SeriesStatistiques>(`${environment.apiUrl}/api/admin/statistiques/series`);
  }
}
